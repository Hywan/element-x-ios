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

import UIKit

enum UserSessionFlowCoordinatorAction {
    case signOut
}

class UserSessionFlowCoordinator: Coordinator {
    private let stateMachine: UserSessionFlowCoordinatorStateMachine
    
    private let userSession: UserSessionProtocol
    private let navigationRouter: NavigationRouterType
    private let bugReportService: BugReportServiceProtocol
    
    var childCoordinators: [Coordinator] = []
    
    var callback: ((UserSessionFlowCoordinatorAction) -> Void)?
    
    init(userSession: UserSessionProtocol, navigationRouter: NavigationRouterType, bugReportService: BugReportServiceProtocol) {
        stateMachine = UserSessionFlowCoordinatorStateMachine()
        self.userSession = userSession
        self.navigationRouter = navigationRouter
        self.bugReportService = bugReportService
        
        setupStateMachine()
    }
    
    func start() {
        stateMachine.processEvent(.start)
    }
    
    func stop() { }
        
    // MARK: - Private
    
    private func setupStateMachine() {
        stateMachine.addTransitionHandler { [weak self] context in
            guard let self = self else { return }
            
            switch (context.fromState, context.event, context.toState) {
            case (.initial, .start, .homeScreen):
                self.presentHomeScreen()
                
            case(_, _, .roomScreen(let roomId)):
                self.presentRoomWithIdentifier(roomId)
            case(.roomScreen(let roomId), .dismissedRoomScreen, .homeScreen):
                self.tearDownDismissedRoomScreen(roomId)
                
            case (.homeScreen, .showSessionVerificationScreen, .sessionVerificationScreen):
                self.presentSessionVerification()
            case (.sessionVerificationScreen, .dismissedSessionVerificationScreen, .homeScreen):
                self.tearDownDismissedSessionVerificationScreen()
                
            case (.homeScreen, .showSettingsScreen, .settingsScreen):
                self.presentSettingsScreen()
            case (.settingsScreen, .dismissedSettingsScreen, .homeScreen):
                self.dismissSettingsScreen()
                
            default:
                fatalError("Unknown transition: \(context)")
            }
        }
        
        stateMachine.addErrorHandler { context in
            fatalError("Failed transition with context: \(context)")
        }
    }
    
    private func presentHomeScreen() {
        userSession.clientProxy.startSync()
        
        let parameters = HomeScreenCoordinatorParameters(userSession: userSession,
                                                         attributedStringBuilder: AttributedStringBuilder())
        let coordinator = HomeScreenCoordinator(parameters: parameters)
        
        coordinator.callback = { [weak self] action in
            guard let self = self else { return }
            
            switch action {
            case .presentRoom(let roomIdentifier):
                self.stateMachine.processEvent(.showRoomScreen(roomId: roomIdentifier))
            case .presentSettings:
                self.presentSettingsScreen()
            case .presentBugReport:
                self.presentBugReportScreen()
            case .verifySession:
                self.stateMachine.processEvent(.showSessionVerificationScreen)
            case .signOut:
                self.callback?(.signOut)
            }
        }
        
        add(childCoordinator: coordinator)
        navigationRouter.setRootModule(coordinator)

        if bugReportService.crashedLastRun {
            showCrashPopup()
        }
    }
    
    // MARK: Rooms

    private func presentRoomWithIdentifier(_ roomIdentifier: String) {
        guard let roomProxy = userSession.clientProxy.roomForIdentifier(roomIdentifier) else {
            MXLog.error("Invalid room identifier: \(roomIdentifier)")
            return
        }
        let userId = userSession.clientProxy.userIdentifier
        
        let timelineItemFactory = RoomTimelineItemFactory(userID: userId,
                                                          mediaProvider: userSession.mediaProvider,
                                                          roomProxy: roomProxy,
                                                          attributedStringBuilder: AttributedStringBuilder())

        let timelineController = RoomTimelineController(userId: userId,
                                                        roomId: roomIdentifier,
                                                        timelineProvider: roomProxy.timelineProvider,
                                                        timelineItemFactory: timelineItemFactory,
                                                        mediaProvider: userSession.mediaProvider,
                                                        roomProxy: roomProxy)

        let parameters = RoomScreenCoordinatorParameters(timelineController: timelineController,
                                                         mediaProvider: userSession.mediaProvider,
                                                         roomName: roomProxy.displayName ?? roomProxy.name,
                                                         roomAvatarUrl: roomProxy.avatarURL)
        let coordinator = RoomScreenCoordinator(parameters: parameters)

        add(childCoordinator: coordinator)
        navigationRouter.push(coordinator) { [weak self] in
            guard let self = self else { return }
            self.stateMachine.processEvent(.dismissedRoomScreen)
        }
    }
    
    private func tearDownDismissedRoomScreen(_ roomId: String) {
        guard let coordinator = childCoordinators.last as? RoomScreenCoordinator else {
            fatalError("Invalid coordinator hierarchy: \(childCoordinators)")
        }
        
        remove(childCoordinator: coordinator)
    }
    
    // MARK: Settings
    
    private func presentSettingsScreen() {
        let navController = ElementNavigationController()
        let newNavigationRouter = NavigationRouter(navigationController: navController)

        let parameters = SettingsCoordinatorParameters(navigationRouter: newNavigationRouter,
                                                       userSession: userSession,
                                                       bugReportService: bugReportService)
        let coordinator = SettingsCoordinator(parameters: parameters)
        coordinator.callback = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .dismiss:
                self.dismissSettingsScreen()
            case .logout:
                self.dismissSettingsScreen()
                self.callback?(.signOut)
            }
        }

        add(childCoordinator: coordinator)
        coordinator.start()
        navController.viewControllers = [coordinator.toPresentable()]
        navigationRouter.present(navController, animated: true)
    }

    @objc
    private func dismissSettingsScreen() {
        MXLog.debug("dismissSettingsScreen")

        guard let coordinator = childCoordinators.first(where: { $0 is SettingsCoordinator }) else {
            return
        }

        navigationRouter.dismissModule()
        remove(childCoordinator: coordinator)
    }
    
    // MARK: Session verification
        
    private func presentSessionVerification() {
        Task {
            guard let sessionVerificationController = userSession.sessionVerificationController else {
                fatalError("The sessionVerificationController should aways be valid at this point")
            }
            
            let parameters = SessionVerificationCoordinatorParameters(sessionVerificationControllerProxy: sessionVerificationController)
            
            let coordinator = SessionVerificationCoordinator(parameters: parameters)
            
            coordinator.callback = { [weak self] in
                self?.navigationRouter.dismissModule()
                self?.stateMachine.processEvent(.dismissedSessionVerificationScreen)
            }
            
            add(childCoordinator: coordinator)
            navigationRouter.present(coordinator)

            coordinator.start()
        }
    }
    
    private func tearDownDismissedSessionVerificationScreen() {
        guard let coordinator = childCoordinators.last as? SessionVerificationCoordinator else {
            fatalError("Invalid coordinator hierarchy: \(childCoordinators)")
        }

        remove(childCoordinator: coordinator)
    }
    
    // MARK: Bug reporting
    
    private func showCrashPopup() {
        let alert = UIAlertController(title: nil,
                                      message: ElementL10n.sendBugReportAppCrashed,
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: ElementL10n.no, style: .cancel))
        alert.addAction(UIAlertAction(title: ElementL10n.yes, style: .default) { [weak self] _ in
            self?.presentBugReportScreen()
        })

        navigationRouter.present(alert, animated: true)
    }

    private func presentBugReportScreen(for image: UIImage? = nil) {
        let parameters = BugReportCoordinatorParameters(bugReportService: bugReportService,
                                                        screenshot: image)
        let coordinator = BugReportCoordinator(parameters: parameters)
        coordinator.completion = { [weak self, weak coordinator] in
            guard let self = self, let coordinator = coordinator else { return }
            self.navigationRouter.dismissModule(animated: true)
            self.remove(childCoordinator: coordinator)
        }

        add(childCoordinator: coordinator)
        coordinator.start()
        let navController = ElementNavigationController(rootViewController: coordinator.toPresentable())
        navController.navigationBar.topItem?.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                                                 target: self,
                                                                                 action: #selector(dismissBugReportScreen))
        navController.isModalInPresentation = true
        navigationRouter.present(navController, animated: true)
    }
    
    @objc
    private func dismissBugReportScreen() {
        MXLog.debug("dismissBugReportScreen")

        guard let bugReportCoordinator = childCoordinators.first(where: { $0 is BugReportCoordinator }) else {
            return
        }

        navigationRouter.dismissModule()
        remove(childCoordinator: bugReportCoordinator)
    }
}