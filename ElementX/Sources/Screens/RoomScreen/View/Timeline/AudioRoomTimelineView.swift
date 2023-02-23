//
// Copyright 2023 New Vector Ltd
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

import Foundation
import SwiftUI

struct AudioRoomTimelineView: View {
    let timelineItem: AudioRoomTimelineItem

    var body: some View {
        TimelineStyler(timelineItem: timelineItem) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.element.primaryContent)
                FormattedBodyText(text: timelineItem.body)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
        }
    }
}

struct AudioRoomTimelineView_Previews: PreviewProvider {
    static let viewModel = RoomScreenViewModel.mock

    static var previews: some View {
        body.environmentObject(viewModel.context)
        body.timelineStyle(.plain).environmentObject(viewModel.context)
    }

    static var body: some View {
        AudioRoomTimelineView(timelineItem: AudioRoomTimelineItem(id: UUID().uuidString,
                                                                  body: "audio.ogg",
                                                                  timestamp: "Now",
                                                                  groupState: .single,
                                                                  isOutgoing: false,
                                                                  isEditable: false,
                                                                  sender: .init(id: "Bob"),
                                                                  duration: 300,
                                                                  source: nil))
    }
}