import Vapor
import Logging
import Shared

// Railway 명령줄 파싱 에러 완전 회피: 사전 정의된 Environment 사용
// 명령줄 인자 감지/파싱을 전혀 수행하지 않음
// CommandLine.arguments[0]은 실행 파일 경로. 나머지 인자는 제거하여 Railway 에러 방지
var env = Environment(name: "production", arguments: ["Gateway"])
try LoggingSystem.bootstrap(from: &env)

// 명시적으로 shared EventLoopGroup으로 Application 생성
let app = Application(env, .shared(MultiThreadedEventLoopGroup.singleton))
defer { app.shutdown() }

// MARK: - Configuration
try configure(app)

// MARK: - Database Migrations
try app.autoMigrate().wait()
app.logger.info("✅ Database migrations completed")

// MARK: - Routes
try routes(app)

// MARK: - Start Server
// Railway의 PORT 환경변수를 우선 사용, 없으면 GATEWAY_PORT, 그것도 없으면 8000
let port = Environment.get("PORT").flatMap(Int.init) ?? 
           Environment.get("GATEWAY_PORT").flatMap(Int.init) ?? 8000
app.http.server.configuration.port = port
app.http.server.configuration.hostname = "0.0.0.0"

app.logger.info("🚀 Gateway Service starting on port \(port)")

// Railway 환경에서 명령줄 파싱 에러를 완전히 우회하기 위해 서버를 직접 시작
try app.start()
try app.running?.onStop.wait()