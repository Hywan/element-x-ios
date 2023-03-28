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

struct RoomProxyMockConfiguration {
    var id = UUID().uuidString
    let name: String? = nil
    let displayName: String?
    var topic: String?
    var avatarURL: URL?
    var isDirect = Bool.random()
    var isSpace = Bool.random()
    var isPublic = Bool.random()
    var isEncrypted = Bool.random()
    var isTombstoned = Bool.random()
    var canonicalAlias: String?
    var alternativeAliases: [String] = []
    var hasUnreadNotifications = Bool.random()
    var members: [RoomMemberProxyProtocol]?
}

extension RoomProxyMock {
    convenience init(with configuration: RoomProxyMockConfiguration) {
        self.init()

        id = configuration.id
        name = configuration.name
        displayName = configuration.displayName
        topic = configuration.topic
        avatarURL = configuration.avatarURL
        isDirect = configuration.isDirect
        isSpace = configuration.isSpace
        isPublic = configuration.isPublic
        isEncrypted = configuration.isEncrypted
        isTombstoned = configuration.isTombstoned
        canonicalAlias = configuration.canonicalAlias
        alternativeAliases = configuration.alternativeAliases
        hasUnreadNotifications = configuration.hasUnreadNotifications

        membersClosure = {
            if let members = configuration.members {
                return .success(members)
            }
            return .failure(.failedRetrievingMembers)
        }
    }
}