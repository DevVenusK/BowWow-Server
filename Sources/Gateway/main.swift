import Vapor
import Logging
import Shared

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { app.shutdown() }

// MARK: - Configuration
try configure(app)

// MARK: - Routes
try routes(app)

// MARK: - Start Server
// Railway의 PORT 환경변수를 우선 사용, 없으면 GATEWAY_PORT, 그것도 없으면 8000
let port = Environment.get("PORT").flatMap(Int.init) ?? 
           Environment.get("GATEWAY_PORT").flatMap(Int.init) ?? 8000
app.http.server.configuration.port = port

app.logger.info("🚀 Gateway Service starting on port \(port)")
try app.run()