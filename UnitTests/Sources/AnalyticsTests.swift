//
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import AnalyticsEvents
@testable import ElementX
import XCTest

class AnalyticsTests: XCTestCase {
    private var applicationSettings: AppSettings!
    private var analyticsClient: AnalyticsClientMock!
    private var bugReportService: BugReportServiceMock!
    
    override func setUp() {
        AppSettings.configureWithSuiteName("io.element.elementx.unitests")
        AppSettings.reset()
        applicationSettings = AppSettings()
        ServiceLocator.shared.register(appSettings: applicationSettings)
        bugReportService = BugReportServiceMock()
        bugReportService.isRunning = false
        ServiceLocator.shared.register(bugReportService: bugReportService)
        analyticsClient = AnalyticsClientMock()
        analyticsClient.isRunning = false
        ServiceLocator.shared.register(analytics: Analytics(client: analyticsClient))
    }
    
    func testAnalyticsPromptNewUser() {
        // Given a fresh install of the app (without PostHog analytics having been set).
        // When the user is prompted for analytics.
        let showPrompt = ServiceLocator.shared.analytics.shouldShowAnalyticsPrompt
        
        // Then the prompt should be shown.
        XCTAssertTrue(showPrompt, "A prompt should be shown for a new user.")
    }
    
    func testAnalyticsPromptUserDeclinedPostHog() {
        // Given an existing install of the app where the user previously declined PostHog
        applicationSettings.enableAnalytics = false
        
        // When the user is prompted for analytics
        let showPrompt = ServiceLocator.shared.analytics.shouldShowAnalyticsPrompt
        
        // Then no prompt should be shown.
        XCTAssertFalse(showPrompt, "A prompt should not be shown any more.")
    }
    
    func testAnalyticsPromptUserAcceptedPostHog() {
        // Given an existing install of the app where the user previously accepted PostHog
        applicationSettings.enableAnalytics = true
        
        // When the user is prompted for analytics
        let showPrompt = ServiceLocator.shared.analytics.shouldShowAnalyticsPrompt
        
        // Then no prompt should be shown.
        XCTAssertFalse(showPrompt, "A prompt should not be shown any more.")
    }
    
    func testAnalyticsPromptNotDisplayed() {
        // Given a fresh install of the app both Analytics and BugReportService should be disabled
        XCTAssertFalse(ServiceLocator.shared.settings.enableAnalytics)
        XCTAssertFalse(ServiceLocator.shared.analytics.isRunning)
        XCTAssertFalse(analyticsClient.startCalled)
        XCTAssertFalse(bugReportService.startCalled)
    }

    func testAnalyticsOptOut() {
        // Given a fresh install of the app (without PostHog analytics having been set).
        // When analytics is opt-out
        ServiceLocator.shared.analytics.optOut()
        // Then analytics should be disabled
        XCTAssertFalse(applicationSettings.enableAnalytics)
        XCTAssertFalse(ServiceLocator.shared.analytics.isRunning)
        XCTAssertFalse(analyticsClient.isRunning)
        XCTAssertFalse(bugReportService.isRunning)
        // Analytics client and the bug report service should have been stopped
        XCTAssertTrue(analyticsClient.stopCalled)
        XCTAssertTrue(bugReportService.stopCalled)
    }

    func testAnalyticsOptIn() {
        // Given a fresh install of the app (without PostHog analytics having been set).
        // When analytics is opt-in
        ServiceLocator.shared.analytics.optIn()
        // The analytics should be enabled
        XCTAssertTrue(applicationSettings.enableAnalytics)
        // Analytics client and the bug report service should have been started
        XCTAssertTrue(analyticsClient.startCalled)
        XCTAssertTrue(bugReportService.startCalled)
    }

    func testAnalyticsStartIfNotEnabled() {
        // Given an existing install of the app where the user previously declined the tracking
        applicationSettings.enableAnalytics = false
        // Analytics should not start
        ServiceLocator.shared.analytics.startIfEnabled()
        XCTAssertFalse(ServiceLocator.shared.settings.enableAnalytics)
        XCTAssertFalse(analyticsClient.startCalled)
        XCTAssertFalse(bugReportService.startCalled)
    }
    
    func testAnalyticsStartIfEnabled() {
        // Given an existing install of the app where the user previously accpeted the tracking
        applicationSettings.enableAnalytics = true
        // Analytics should start
        ServiceLocator.shared.analytics.startIfEnabled()
        XCTAssertTrue(ServiceLocator.shared.settings.enableAnalytics)
        XCTAssertTrue(analyticsClient.startCalled)
        XCTAssertTrue(bugReportService.startCalled)
    }
    
    func testAddingUserProperties() {
        // Given a client with no user properties set
        let client = PostHogAnalyticsClient()
        XCTAssertNil(client.pendingUserProperties, "No user properties should have been set yet.")
        
        // When updating the user properties
        client.updateUserProperties(AnalyticsEvent.UserProperties(ftueUseCaseSelection: .PersonalMessaging,
                                                                  numFavouriteRooms: 4,
                                                                  numSpaces: 5,
                                                                  allChatsActiveFilter: nil))
        
        // Then the properties should be cached
        XCTAssertNotNil(client.pendingUserProperties, "The user properties should be cached.")
        XCTAssertEqual(client.pendingUserProperties?.ftueUseCaseSelection, .PersonalMessaging, "The use case selection should match.")
        XCTAssertEqual(client.pendingUserProperties?.numFavouriteRooms, 4, "The number of favorite rooms should match.")
        XCTAssertEqual(client.pendingUserProperties?.numSpaces, 5, "The number of spaces should match.")
    }
    
    func testMergingUserProperties() {
        // Given a client with a cached use case user properties
        let client = PostHogAnalyticsClient()
        client.updateUserProperties(AnalyticsEvent.UserProperties(ftueUseCaseSelection: .PersonalMessaging,
                                                                  numFavouriteRooms: nil,
                                                                  numSpaces: nil,
                                                                  allChatsActiveFilter: nil))
        
        XCTAssertNotNil(client.pendingUserProperties, "The user properties should be cached.")
        XCTAssertEqual(client.pendingUserProperties?.ftueUseCaseSelection, .PersonalMessaging, "The use case selection should match.")
        XCTAssertNil(client.pendingUserProperties?.numFavouriteRooms, "The number of favorite rooms should not be set.")
        XCTAssertNil(client.pendingUserProperties?.numSpaces, "The number of spaces should not be set.")
        
        // When updating the number of spaced
        client.updateUserProperties(AnalyticsEvent.UserProperties(ftueUseCaseSelection: nil,
                                                                  numFavouriteRooms: 4,
                                                                  numSpaces: 5,
                                                                  allChatsActiveFilter: nil))
        
        // Then the new properties should be updated and the existing properties should remain unchanged
        XCTAssertNotNil(client.pendingUserProperties, "The user properties should be cached.")
        XCTAssertEqual(client.pendingUserProperties?.ftueUseCaseSelection, .PersonalMessaging, "The use case selection shouldn't have changed.")
        XCTAssertEqual(client.pendingUserProperties?.numFavouriteRooms, 4, "The number of favorite rooms should have been updated.")
        XCTAssertEqual(client.pendingUserProperties?.numSpaces, 5, "The number of spaces should have been updated.")
    }
    
    func testSendingUserProperties() {
        // Given a client with user properties set
        let client = PostHogAnalyticsClient()
        client.updateUserProperties(AnalyticsEvent.UserProperties(ftueUseCaseSelection: .PersonalMessaging,
                                                                  numFavouriteRooms: nil,
                                                                  numSpaces: nil,
                                                                  allChatsActiveFilter: nil))
        client.start()
        
        XCTAssertNotNil(client.pendingUserProperties, "The user properties should be cached.")
        XCTAssertEqual(client.pendingUserProperties?.ftueUseCaseSelection, .PersonalMessaging, "The use case selection should match.")
        
        // When sending an event (tests run under Debug configuration so this is sent to the development instance)
        client.screen(AnalyticsEvent.MobileScreen(durationMs: nil, screenName: .Home))
        
        // Then the properties should be cleared
        XCTAssertNil(client.pendingUserProperties, "The user properties should be cleared.")
    }
}
