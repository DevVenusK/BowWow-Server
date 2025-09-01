import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { app.shutdown() }

try configure(app)
try routes(app)

let port = Environment.get("USER_SERVICE_PORT").flatMap(Int.init) ?? 8001
app.http.server.configuration.port = port

app.logger.info("🔐 User Service starting on port \(port)")
try app.run()