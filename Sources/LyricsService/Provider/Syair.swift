//
//  Syair.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore

#if canImport(Darwin)

private let syairSearchBaseURLString = "https://syair.info/search"
private let syairLyricsBaseURL = URL(string: "https://syair.info")!

extension LyricsProviders {
    public final class Syair {
        public init() {}
    }
}

extension LyricsProviders.Syair: _LyricsProvider {
    public typealias LyricsToken = String

    public static let service: LyricsProviders.Service? = .syair

    public func searchLyrics(request: LyricsSearchRequest) async throws -> [LyricsToken] {
        var parameter: [String: Any] = ["page": 1]
        switch request.searchTerm {
        case let .info(title: title, artist: artist):
            parameter["artist"] = artist
            parameter["title"] = title
        case let .keyword(keyword):
            parameter["q"] = keyword
        }
        let url = URL(string: syairSearchBaseURLString + "?" + parameter.stringFromHttpParameters)!
        let (data, _) = try await sharedURLSession.data(for: URLRequest(url: url))
        guard let result = String(data: data, encoding: .utf8) else {
            return []
        }
        return syairSearchResultRegex.matches(in: result).compactMap { $0[1]?.string }
    }

    public func fetchLyrics(token: LyricsToken) async throws -> Lyrics? {
        guard let url = URL(string: token, relativeTo: syairLyricsBaseURL) else {
            return nil
        }
        var req = URLRequest(url: url)
        req.addValue("https://syair.info/", forHTTPHeaderField: "Referer")
        let (data, _) = try await sharedURLSession.data(for: req)
        guard let str = String(data: data, encoding: .utf8),
            let lrcData = syairLyricsContentRegex.firstMatch(in: str)?.captures[1]?.string.data(using: .utf8),
            let lrcStr = try? NSAttributedString(data: lrcData, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil).string,
            let lrc = Lyrics(lrcStr) 
        else {
            return nil
        }
        lrc.metadata.serviceToken = token
        return lrc
    }
}

#endif
