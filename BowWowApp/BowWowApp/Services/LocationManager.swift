import CoreLocation
import SwiftUI
import Observation

/// 위치 서비스 관리 - 강타입 위치 데이터 처리
@MainActor
@Observable
final class LocationManager: NSObject {
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationError: LocationError?
    var isUpdatingLocation: Bool = false
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    /// 위치 업데이트 콜백
    var onLocationUpdate: ((CLLocation) -> Void)?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0 // 10미터 이상 이동 시 업데이트
        
        // 백그라운드 위치 업데이트 허용 (필요 시)
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
    }
    
    /// 위치 권한 요청
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = .permissionDenied
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            locationError = .unknown("알 수 없는 권한 상태")
        }
    }
    
    /// 현재 위치 한 번 요청
    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = .permissionDenied
            return
        }
        
        isUpdatingLocation = true
        locationManager.requestLocation()
    }
    
    /// 지속적인 위치 업데이트 시작
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = .permissionDenied
            return
        }
        
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    /// 위치 업데이트 중지
    func stopLocationUpdates() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }
    
    /// 현재 위치를 강타입으로 변환
    func getCurrentStrongLocation() throws -> StrongLocation? {
        guard let location = currentLocation else { return nil }
        
        return try StrongLocation.create(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude
        )
    }
    
    /// 두 지점 간의 거리 계산 (강타입)
    func calculateDistance(from: StrongLocation, to: StrongLocation) -> ValidatedDistance? {
        let fromLocation = CLLocation(
            latitude: from.latitude.value,
            longitude: from.longitude.value
        )
        let toLocation = CLLocation(
            latitude: to.latitude.value,
            longitude: to.longitude.value
        )
        
        let distanceInMeters = fromLocation.distance(from: toLocation)
        let distanceInKilometers = distanceInMeters / 1000.0
        
        return ValidatedDistance.create(distanceInKilometers)
    }
    
    /// 방향 계산
    func calculateDirection(from: StrongLocation, to: StrongLocation) -> String {
        let fromLat = from.latitude.value * .pi / 180.0
        let fromLng = from.longitude.value * .pi / 180.0
        let toLat = to.latitude.value * .pi / 180.0
        let toLng = to.longitude.value * .pi / 180.0
        
        let dLng = toLng - fromLng
        
        let y = sin(dLng) * cos(toLat)
        let x = cos(fromLat) * sin(toLat) - sin(fromLat) * cos(toLat) * cos(dLng)
        
        let bearing = atan2(y, x) * 180.0 / .pi
        let normalizedBearing = (bearing + 360.0).truncatingRemainder(dividingBy: 360.0)
        
        return bearingToDirection(normalizedBearing)
    }
    
    private func bearingToDirection(_ bearing: Double) -> String {
        let directions = [
            "북쪽", "북동쪽", "동쪽", "남동쪽",
            "남쪽", "남서쪽", "서쪽", "북서쪽"
        ]
        
        let index = Int((bearing + 22.5) / 45.0) % 8
        return directions[index]
    }
    
    /// 주소 검색 (Geocoding)
    func geocodeAddress(_ address: String) async throws -> [CLLocation] {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: LocationError.geocodingFailed(error.localizedDescription))
                } else if let placemarks = placemarks {
                    let locations = placemarks.compactMap { $0.location }
                    continuation.resume(returning: locations)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /// 역지오코딩 (주소 가져오기)
    func reverseGeocode(location: StrongLocation) async throws -> String {
        let clLocation = CLLocation(
            latitude: location.latitude.value,
            longitude: location.longitude.value
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: LocationError.geocodingFailed(error.localizedDescription))
                } else if let placemark = placemarks?.first {
                    let address = [
                        placemark.locality,
                        placemark.subLocality,
                        placemark.thoroughfare
                    ].compactMap { $0 }.joined(separator: " ")
                    
                    continuation.resume(returning: address.isEmpty ? "주소를 찾을 수 없음" : address)
                } else {
                    continuation.resume(returning: "주소를 찾을 수 없음")
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        self.currentLocation = location
        self.locationError = nil
        self.isUpdatingLocation = false
        
        // 위치 업데이트 콜백 호출
        self.onLocationUpdate?(location)
        
        print("📍 위치 업데이트: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.isUpdatingLocation = false
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                self.locationError = .permissionDenied
            case .locationUnknown:
                self.locationError = .locationUnavailable
            case .network:
                self.locationError = .networkError
            default:
                self.locationError = .unknown(clError.localizedDescription)
            }
        } else {
            self.locationError = .unknown(error.localizedDescription)
        }
        
        print("❌ 위치 업데이트 실패: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        
        switch status {
        case .notDetermined:
            break
        case .denied, .restricted:
            self.locationError = .permissionDenied
            self.stopLocationUpdates()
        case .authorizedWhenInUse, .authorizedAlways:
            self.locationError = nil
            self.startLocationUpdates()
        @unknown default:
            self.locationError = .unknown("알 수 없는 권한 상태")
        }
        
        print("📍 위치 권한 변경: \(status.rawValue)")
    }
}

// MARK: - LocationError

enum LocationError: LocalizedError, Equatable {
    case permissionDenied
    case locationUnavailable
    case networkError
    case geocodingFailed(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "위치 접근 권한이 거부되었습니다. 설정에서 위치 서비스를 허용해주세요."
        case .locationUnavailable:
            return "현재 위치를 확인할 수 없습니다. 잠시 후 다시 시도해주세요."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        case .geocodingFailed(let message):
            return "주소 검색에 실패했습니다: \(message)"
        case .unknown(let message):
            return "알 수 없는 오류: \(message)"
        }
    }
}