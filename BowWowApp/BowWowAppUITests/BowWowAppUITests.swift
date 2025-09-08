import XCTest

final class BowWowAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Clean up after each test
    }

    func testAppLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 앱이 정상적으로 시작되는지 확인
        XCTAssertTrue(app.staticTexts["BowWow"].exists)
    }

    func testSignalTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 신호 탭 확인
        let signalTab = app.tabBars["Tab Bar"].buttons["신호"]
        XCTAssertTrue(signalTab.exists)
        signalTab.tap()
        
        // 신호 보내기 버튼 확인
        XCTAssertTrue(app.buttons["신호 보내기"].exists)
    }

    func testSettingsTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 설정 탭 확인
        let settingsTab = app.tabBars["Tab Bar"].buttons["설정"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        
        // 설정 화면 요소들 확인
        XCTAssertTrue(app.staticTexts["사용자 정보"].exists)
        XCTAssertTrue(app.staticTexts["앱 설정"].exists)
    }

    func testSegmentedControlInSignalTab() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 신호 탭으로 이동
        app.tabBars["Tab Bar"].buttons["신호"].tap()
        
        // 세그먼트 컨트롤 확인
        let segmentedControl = app.segmentedControls.firstMatch
        XCTAssertTrue(segmentedControl.exists)
        
        // 각 세그먼트 버튼 확인
        XCTAssertTrue(segmentedControl.buttons["보내기"].exists)
        XCTAssertTrue(segmentedControl.buttons["받은 신호"].exists)
        XCTAssertTrue(segmentedControl.buttons["주변"].exists)
    }

    func testSignalDistanceSlider() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 신호 탭으로 이동
        app.tabBars["Tab Bar"].buttons["신호"].tap()
        
        // 보내기 세그먼트가 기본 선택되어 있는지 확인
        let segmentedControl = app.segmentedControls.firstMatch
        segmentedControl.buttons["보내기"].tap()
        
        // 거리 슬라이더 확인
        XCTAssertTrue(app.sliders["신호 범위"].exists)
        XCTAssertTrue(app.staticTexts["신호 범위"].exists)
    }

    func testPermissionStatusDisplay() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 설정 탭으로 이동
        app.tabBars["Tab Bar"].buttons["설정"].tap()
        
        // 권한 설정 섹션 확인
        XCTAssertTrue(app.staticTexts["권한 설정"].exists)
        XCTAssertTrue(app.staticTexts["위치 서비스"].exists)
        XCTAssertTrue(app.staticTexts["푸시 알림"].exists)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}