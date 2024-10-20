//
//  Group.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore

extension LyricsProviders {

    public final class Group: LyricsProvider {

        var providers: [any LyricsProvider]

        public init(service: [LyricsProviders.Service] = LyricsProviders.Service.allCases) {
            providers = service.map { $0.create() }
        }

        public func lyrics(request: LyricsSearchRequest) -> AsyncStream<Lyrics> {
            AsyncStream { [providers] continuation in
                let task = Task {
                    await withTaskGroup(of: Void.self) { group in
                        for provider in providers {
                            group.addTask {
                                for await lyrics in provider.lyrics(request: request) {
                                    continuation.yield(lyrics)
                                }
                            }
                        }
                        await group.waitForAll()
                        continuation.finish()
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }
}
