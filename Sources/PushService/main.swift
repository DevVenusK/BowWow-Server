import Vapor

var env = Environment(name: "production", arguments: ["PushService"])
try LoggingSystem.bootstrap(from: &env)

let app = Application(env, .shared(MultiThreadedEventLoopGroup.singleton))
defer { app.shutdown() }

try configure(app)
try routes(app)

let port = Environment.get("PUSH_SERVICE_PORT").flatMap(Int.init) ?? 8004
app.http.server.configuration.port = port
app.http.server.configuration.hostname = "0.0.0.0"

app.logger.info("🔔 Push Service starting on port \(port)")

try app.start()
try app.running?.onStop.wait()