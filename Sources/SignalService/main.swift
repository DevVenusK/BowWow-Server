import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { app.shutdown() }

try configure(app)
try routes(app)

let port = Environment.get("SIGNAL_SERVICE_PORT").flatMap(Int.init) ?? 8003
app.http.server.configuration.port = port

app.logger.info("📡 Signal Service starting on port \(port)")
try app.run()