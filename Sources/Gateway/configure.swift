import Vapor
import Fluent
import FluentPostgresDriver
import Shared

public func configure(_ app: Application) throws {
    
    // MARK: - Middleware Configuration
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )))
    
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // MARK: - Database Configuration
    if let databaseURL = Environment.get("DATABASE_URL") {
        try app.databases.use(.postgres(url: databaseURL), as: .psql)
    } else {
        app.databases.use(.postgres(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432,
            username: Environment.get("DATABASE_USERNAME") ?? "postgres",
            password: Environment.get("DATABASE_PASSWORD") ?? "password",
            database: Environment.get("DATABASE_NAME") ?? "bowwow"
        ), as: .psql)
    }
    
    // MARK: - Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserLocation())
    app.migrations.add(CreateSignal())
    app.migrations.add(CreateSignalReceipt())
    
    // MARK: - HTTP Client Configuration
    app.http.client.configuration.timeout = HTTPClient.Configuration.Timeout(
        connect: .seconds(5),
        read: .seconds(30)
    )
    
    // MARK: - Service URLs Configuration
    app.storage[ServiceURLsKey.self] = ServiceURLs(
        userService: Environment.get("USER_SERVICE_URL") ?? "http://localhost:8001",
        locationService: Environment.get("LOCATION_SERVICE_URL") ?? "http://localhost:8002",
        signalService: Environment.get("SIGNAL_SERVICE_URL") ?? "http://localhost:8003",
        pushService: Environment.get("PUSH_SERVICE_URL") ?? "http://localhost:8004",
        analyticsService: Environment.get("ANALYTICS_SERVICE_URL") ?? "http://localhost:8005"
    )
    
    app.logger.info("✅ Gateway configuration completed")
}

// MARK: - Service URLs Storage

struct ServiceURLsKey: StorageKey {
    typealias Value = ServiceURLs
}

public struct ServiceURLs {
    let userService: String
    let locationService: String
    let signalService: String
    let pushService: String
    let analyticsService: String
}