/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

// KituraSample shows examples for creating custom routes.

import Foundation

import KituraSys
import KituraNet
import Kitura
import KituraStencil

import LoggerAPI
import HeliumLogger

#if os(Linux)
    import Glibc
#endif

// All Web apps need a router to define routes
let router = Router()

// Using an implementation for a Logger
Log.logger = HeliumLogger()

/**
 * RouterMiddleware can be used for intercepting requests and handling custom behavior
 * such as authentication and other routing
 */
class BasicAuthMiddleware: RouterMiddleware {
    func handle(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        let authString = request.headers["Authorization"]
        Log.info("Authorization: \(authString)")
        // Check authorization string in database to approve the request if fail
        // response.error = NSError(domain: "AuthFailure", code: 1, userInfo: [:])
        next()
    }
}

// Variable to post/put data to (just for sample purposes)
var name: String?

// This route executes the echo middleware
router.all(middleware: BasicAuthMiddleware())

router.all("/static", middleware: StaticFileServer())

router.get("/hello") { _, response, next in
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    do {
        let fName = name ?? "World"
        try response.status(.OK).send("Hello \(fName), from Kitura!").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
}

// This route accepts POST requests
router.post("/hello") {request, response, next in
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    do {
        name = try request.readString()
        try response.status(.OK).send("Got a POST request").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
}

// This route accepts PUT requests
router.put("/hello") {request, response, next in
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    do {
        name = try request.readString()
        try response.status(.OK).send("Got a PUT request").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
}

// This route accepts DELETE requests
router.delete("/hello") {request, response, next in
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    do {
        name = nil
        try response.status(.OK).send("Got a DELETE request").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
}

// Error handling example
router.get("/error") { _, response, next in
    Log.error("Example of error being set")
    response.status(.internalServerError)
    response.error = NSError(domain: "RouterTestDomain", code: 1, userInfo: [:])
    next()
}

// Redirection example
router.get("/redir") { _, response, next in
    do {
        try response.redirect("http://www.ibm.com")
    } catch {
        Log.error("Failed to redirect \(error)")
    }
    next()
}

// Reading parameters
// Accepts user as a parameter
router.get("/users/:user") { request, response, next in
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    let p1 = request.params["user"] ?? "(nil)"
    do {
        try response.status(.OK).send(
            "<!DOCTYPE html><html><body>" +
                "<b>User:</b> \(p1)" +
            "</body></html>\n\n").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
}

// Uses multiple handler blocks
router.get("/multi", handler: { request, response, next in
    response.status(.OK).send("I'm here!\n")
    next()
    }, { request, response, next in
        response.send("Me too!\n")
        next()
})

router.get("/multi") { request, response, next in
    response.status(.OK).send("I come afterward..\n")
    next()
}

// Handles any errors that get set
router.error { request, response, next in
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    do {
        let errorDescription: String
        if let error = response.error {
            errorDescription = "\(error)"
        } else {
            errorDescription = "Unknown error"
        }
        try response.send("Caught the error: \(errorDescription)").end()
    }
    catch {
        Log.error("Failed to send response \(error)")
    }
}

router.setDefaultTemplateEngine(templateEngine: StencilTemplateEngine())
router.get("/document") { _, response, next in
    defer {
        next()
    }
    do {
        // the example from https://github.com/kylef/Stencil
        var context: [String: Any] = [
            "articles": [
                [ "title": "Migrating from OCUnit to XCTest", "author": "Kyle Fuller" ],
                [ "title": "Memory Management with ARC", "author": "Kyle Fuller" ],
            ]
        ]

        try response.render("document", context: context).end()
    } catch {
        Log.error("Failed to render template \(error)")
    }
}

// A custom Not found handler
router.all { request, response, next in
    if  response.statusCode == .notFound  {
        // Remove this wrapping if statement, if you want to handle requests to / as well
        if  request.originalUrl != "/"  &&  request.originalUrl != ""  {
            do {
                try response.send("Route not found in Sample application!").end()
            }
            catch {
                Log.error("Failed to send response \(error)")
            }
        }
    }
    next()
}

// Listen on port 8090
let server = HTTPServer.listen(port: 8090, delegate: router)
Server.run()
