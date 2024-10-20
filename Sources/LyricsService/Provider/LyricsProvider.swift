//
//  LyricsProvider.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore

public enum LyricsProviders {}

public protocol LyricsProvider {
    func lyrics(request: LyricsSearchRequest) -> AsyncStream<Lyrics>
}

public protocol _LyricsProvider: LyricsProvider {

    associatedtype LyricsToken

    static var service: LyricsProviders.Service? { get }

    func searchLyrics(request: LyricsSearchRequest) async throws -> [LyricsToken]

    func fetchLyrics(token: LyricsToken) async throws -> Lyrics?
}

extension _LyricsProvider {

    public func lyrics(request: LyricsSearchRequest) -> AsyncStream<Lyrics> {
        AsyncStream { continuation in
            let task = Task {
                guard let tokens = try? await searchLyrics(request: request).prefix(request.limit)
                else {
                    continuation.finish()
                    return
                }
                await withTaskGroup(of: Lyrics?.self) { group in
                    for token in tokens {
                        group.addTask {
                            try? await fetchLyrics(token: token)
                        }
                    }
                    for await lyrics in group {
                        guard let lyrics else { continue }
                        lyrics.metadata.searchRequest = request
                        lyrics.metadata.service = Self.service
                        continuation.yield(lyrics)
                    }
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
