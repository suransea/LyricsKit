//
//  Unsupported.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore

extension LyricsProviders {
    public final class Unsupported {
        public init() {}
    }
}

extension LyricsProviders.Unsupported: LyricsProvider {

    public func lyrics(request: LyricsSearchRequest) -> AsyncStream<Lyrics> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
