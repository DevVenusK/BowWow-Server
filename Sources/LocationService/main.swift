import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { app.shutdown() }

try configure(app)
try routes(app)

let port = Environment.get("LOCATION_SERVICE_PORT").flatMap(Int.init) ?? 8002
app.http.server.configuration.port = port
app.http.server.configuration.hostname = "0.0.0.0"

app.logger.info("📍 Location Service starting on port \(port)")

try app.start()
try app.running?.onStop.wait()