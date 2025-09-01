import Foundation
import Vapor

// MARK: - Functional Programming Utilities

/// 함수 합성 연산자
public func compose<A, B, C>(_ f: @escaping (A) -> B, _ g: @escaping (B) -> C) -> (A) -> C {
    return { a in g(f(a)) }
}

/// 비동기 함수 합성
public func composeAsync<A, B, C>(_ f: @escaping Pipeline<A, B>, 
                                  _ g: @escaping Pipeline<B, C>) -> Pipeline<A, C> {
    return { a in
        f(a).flatMap { b in
            g(b)
        }
    }
}

/// Result 타입 확장
public extension Result {
    /// Result를 EventLoopFuture로 변환
    func toEventLoopFuture(on eventLoop: EventLoop) -> EventLoopFuture<Success> {
        switch self {
        case .success(let value):
            return eventLoop.makeSucceededFuture(value)
        case .failure(let error):
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    /// flatMap for chaining Results
    func flatMap<NewSuccess>(_ transform: (Success) -> Result<NewSuccess, Failure>) -> Result<NewSuccess, Failure> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}

/// EventLoopFuture 확장
public extension EventLoopFuture {
    /// Result를 EventLoopFuture<Result>로 변환
    func asResult() -> EventLoopFuture<Result<Value, Error>> {
        return self.map { .success($0) }
            .recover { .failure($0) }
    }
    
    /// 조건부 실행
    func `if`(_ condition: Bool, 
              then: @escaping (Value) -> EventLoopFuture<Value>) -> EventLoopFuture<Value> {
        if condition {
            return self.flatMap(then)
        } else {
            return self
        }
    }
}

// MARK: - Validation Functions

/// 사용자 유효성 검사 - Strong Typed
public func validateUser(_ request: CreateUserRequest) -> SyncResult<CreateUserRequest> {
    // Strong type이므로 추가 검증 불필요 - 컴파일 타임에 이미 보장됨
    return .success(request)
}

/// 위치 유효성 검사 - Strong Typed
public func validateLocation(_ request: LocationUpdateRequest) -> SyncResult<LocationUpdateRequest> {
    // StrongLocation이므로 추가 검증 불필요 - 컴파일 타임에 이미 보장됨
    return .success(request)
}

/// 신호 요청 유효성 검사 - Strong Typed
public func validateSignal(_ request: SignalRequest) -> SyncResult<SignalRequest> {
    // StrongLocation과 ValidatedDistance이므로 추가 검증 불필요 - 컴파일 타임에 이미 보장됨
    return .success(request)
}

// MARK: - Transformation Functions

/// 강타입 위치를 방향으로 변환
public func calculateDirection(from source: StrongLocation, to target: StrongLocation) -> String {
    let deltaLat = target.latitude.value - source.latitude.value
    let deltaLng = target.longitude.value - source.longitude.value
    
    let angle = atan2(deltaLng, deltaLat) * 180 / .pi
    let normalizedAngle = angle < 0 ? angle + 360 : angle
    
    switch normalizedAngle {
    case 337.5...360, 0..<22.5:
        return "N"
    case 22.5..<67.5:
        return "NE"
    case 67.5..<112.5:
        return "E"
    case 112.5..<157.5:
        return "SE"
    case 157.5..<202.5:
        return "S"
    case 202.5..<247.5:
        return "SW"
    case 247.5..<292.5:
        return "W"
    case 292.5..<337.5:
        return "NW"
    default:
        return "N"
    }
}

/// Legacy 호환성을 위한 함수
@available(*, deprecated, message: "Use StrongLocation version instead")
public func calculateDirection(from source: Location, to target: Location) -> String {
    let deltaLat = target.latitude - source.latitude
    let deltaLng = target.longitude - source.longitude
    
    let angle = atan2(deltaLng, deltaLat) * 180 / .pi
    let normalizedAngle = angle < 0 ? angle + 360 : angle
    
    switch normalizedAngle {
    case 337.5...360, 0..<22.5:
        return "N"
    case 22.5..<67.5:
        return "NE"
    case 67.5..<112.5:
        return "E"
    case 112.5..<157.5:
        return "SE"
    case 157.5..<202.5:
        return "S"
    case 202.5..<247.5:
        return "SW"
    case 247.5..<292.5:
        return "W"
    case 292.5..<337.5:
        return "NW"
    default:
        return "N"
    }
}

/// 강타입 두 위치 간 거리 계산 (하버사인 공식) - 타입 안전한 결과 반환
public func calculateDistance(from source: StrongLocation, to target: StrongLocation, unit: DistanceUnit = .mile) -> ValidatedDistance {
    let earthRadius: Double = unit == .mile ? 3959.0 : 6371.0 // mile or km
    
    let lat1Rad = source.latitude.value * .pi / 180
    let lat2Rad = target.latitude.value * .pi / 180
    let deltaLatRad = (target.latitude.value - source.latitude.value) * .pi / 180
    let deltaLngRad = (target.longitude.value - source.longitude.value) * .pi / 180
    
    let a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
            cos(lat1Rad) * cos(lat2Rad) *
            sin(deltaLngRad / 2) * sin(deltaLngRad / 2)
    
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    let distance = earthRadius * c
    
    // 계산 결과가 항상 유효한 거리이므로 force unwrap 안전
    return ValidatedDistance.create(distance)!
}

/// Legacy 호환성을 위한 함수
@available(*, deprecated, message: "Use StrongLocation version instead")
public func calculateDistance(from source: Location, to target: Location, unit: DistanceUnit = .mile) -> Double {
    let earthRadius: Double = unit == .mile ? 3959.0 : 6371.0 // mile or km
    
    let lat1Rad = source.latitude * .pi / 180
    let lat2Rad = target.latitude * .pi / 180
    let deltaLatRad = (target.latitude - source.latitude) * .pi / 180
    let deltaLngRad = (target.longitude - source.longitude) * .pi / 180
    
    let a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
            cos(lat1Rad) * cos(lat2Rad) *
            sin(deltaLngRad / 2) * sin(deltaLngRad / 2)
    
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    
    return earthRadius * c
}

// MARK: - Higher-Order Functions

/// 재시도 로직이 포함된 고차 함수
public func withRetry<T>(_ action: @escaping () -> EventLoopFuture<T>,
                         attempts: Int = 3,
                         delay: TimeInterval = 1.0,
                         on eventLoop: EventLoop) -> EventLoopFuture<T> {
    
    func attempt(_ remainingAttempts: Int) -> EventLoopFuture<T> {
        return action().flatMapError { error in
            if remainingAttempts > 1 {
                let delayedFuture = eventLoop.scheduleTask(in: .seconds(Int64(delay))) {
                    ()
                }.futureResult
                
                return delayedFuture.flatMap { _ in
                    attempt(remainingAttempts - 1)
                }
            } else {
                return eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    return attempt(attempts)
}

/// 로깅이 포함된 고차 함수
public func withLogging<T>(_ action: @escaping () -> EventLoopFuture<T>,
                           operation: String,
                           logger: Logger) -> EventLoopFuture<T> {
    logger.info("Starting operation: \(operation)")
    let startTime = Date()
    
    return action().always { result in
        let duration = Date().timeIntervalSince(startTime)
        
        switch result {
        case .success:
            logger.info("Operation completed successfully: \(operation) (took \(duration)s)")
        case .failure(let error):
            logger.error("Operation failed: \(operation) - \(error) (took \(duration)s)")
        }
    }
}

/// 타임아웃이 포함된 고차 함수
public func withTimeout<T>(_ action: @escaping () -> EventLoopFuture<T>,
                           timeout: TimeInterval,
                           on eventLoop: EventLoop) -> EventLoopFuture<T> {
    
    let promise = eventLoop.makePromise(of: T.self)
    
    // 액션 실행
    action().whenComplete { result in
        switch result {
        case .success(let value):
            promise.succeed(value)
        case .failure(let error):
            promise.fail(error)
        }
    }
    
    // 타임아웃 설정
    let timeoutTask = eventLoop.scheduleTask(in: .seconds(Int64(timeout))) {
        promise.fail(BowWowError.validationError("Operation timed out after \(timeout) seconds"))
    }
    
    // 완료 시 타임아웃 취소
    promise.futureResult.whenComplete { _ in
        timeoutTask.cancel()
    }
    
    return promise.futureResult
}

// MARK: - Array Extensions for Functional Programming

public extension Array {
    /// 병렬 처리를 위한 chunked 함수
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
    
    /// 조건부 필터링
    func conditionalFilter(_ condition: Bool, _ isIncluded: (Element) throws -> Bool) rethrows -> [Element] {
        if condition {
            return try self.filter(isIncluded)
        } else {
            return self
        }
    }
}

public extension Collection {
    /// 안전한 subscript
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}