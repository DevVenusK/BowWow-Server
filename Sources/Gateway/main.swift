import Vapor
import Logging
import Shared

// 명시적으로 production 환경으로 설정
var env = Environment.production
try LoggingSystem.bootstrap(from: &env)

// 명시적으로 shared EventLoopGroup으로 Application 생성
let app = Application(env, .shared(MultiThreadedEventLoopGroup.singleton))
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
app.http.server.configuration.hostname = "0.0.0.0"

app.logger.info("🚀 Gateway Service starting on port \(port)")

try app.run()