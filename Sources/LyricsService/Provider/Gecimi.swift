//
//  Gecimi.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let gecimiLyricsBaseURL = URL(string: "http://gecimi.com/api/lyric")!
private let gecimiCoverBaseURL = URL(string: "http://gecimi.com/api/cover")!

extension LyricsProviders {
    public final class Gecimi {
        public init() {}
    }
}

extension LyricsProviders.Gecimi: _LyricsProvider {

    public struct LyricsToken {
        let value: GecimiResponseSearchResult.Result
    }

    public static let service: LyricsProviders.Service? = .gecimi

    public func searchLyrics(request: LyricsSearchRequest) async throws -> [LyricsToken] {
        guard case let .info(title, artist) = request.searchTerm else {
            // cannot search by keyword
            return []
        }
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .uriComponentAllowed)!
        let encodedArtist = artist.addingPercentEncoding(
            withAllowedCharacters: .uriComponentAllowed)!

        let url = gecimiLyricsBaseURL.appendingPathComponent("\(encodedTitle)/\(encodedArtist)")
        let req = URLRequest(url: url)

        let (data, _) = try await sharedURLSession.data(for: req)
        let result = try JSONDecoder().decode(GecimiResponseSearchResult.self, from: data)
        return result.result.map(LyricsToken.init)
    }

    public func fetchLyrics(token: LyricsToken) async throws -> Lyrics? {
        let token = token.value
        let req = URLRequest(url: token.lrc)
        let (data, _) = try await sharedURLSession.data(for: req)
        guard let lrcContent = String(data: data, encoding: .utf8),
            let lrc = Lyrics(lrcContent)
        else {
            return nil
        }
        lrc.metadata.remoteURL = token.lrc
        lrc.metadata.serviceToken = "\(token.aid),\(token.lrc)"
        return lrc
    }
}
