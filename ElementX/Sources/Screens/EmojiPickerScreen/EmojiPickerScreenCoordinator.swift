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

import SwiftUI

struct EmojiPickerScreenCoordinatorParameters {
    let emojiProvider: EmojiProviderProtocol
    let itemID: TimelineItemIdentifier
    let selectedEmojis: Set<String>
}

enum EmojiPickerScreenCoordinatorAction {
    case emojiSelected(emoji: String, itemID: TimelineItemIdentifier)
    case dismiss
}

final class EmojiPickerScreenCoordinator: CoordinatorProtocol {
    private let parameters: EmojiPickerScreenCoordinatorParameters
    private var viewModel: EmojiPickerScreenViewModelProtocol
    
    var callback: ((EmojiPickerScreenCoordinatorAction) -> Void)?
    
    init(parameters: EmojiPickerScreenCoordinatorParameters) {
        self.parameters = parameters
        
        viewModel = EmojiPickerScreenViewModel(emojiProvider: parameters.emojiProvider)
    }
    
    func start() {
        viewModel.callback = { [weak self] action in
            guard let self else { return }
            
            switch action {
            case let .emojiSelected(emoji: emoji):
                self.callback?(.emojiSelected(emoji: emoji, itemID: self.parameters.itemID))
            case .dismiss:
                self.callback?(.dismiss)
            }
        }
    }
    
    func toPresentable() -> AnyView {
        AnyView(EmojiPickerScreen(context: viewModel.context, selectedEmojis: parameters.selectedEmojis))
    }
}
