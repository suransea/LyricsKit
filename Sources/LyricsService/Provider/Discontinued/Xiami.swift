//
//  LyricsXiami.swift
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

private let xiamiSearchBaseURLString = "http://api.xiami.com/web?"

extension LyricsProviders {
    public final class Xiami {
        public init() {}
    }
}

extension LyricsProviders.Xiami: _LyricsProvider {

    public struct LyricsToken {
        let value: XiamiResponseSearchResult.Data.Song
    }

    public static let service: LyricsProviders.Service? = nil

    public func searchLyrics(request: LyricsSearchRequest) async throws -> [LyricsToken] {
        let parameter: [String: Any] = [
            "key": request.searchTerm.description,
            "limit": 10,
            "r": "search/songs",
            "v": "2.0",
            "app_key": 1,
        ]
        let url = URL(string: xiamiSearchBaseURLString + parameter.stringFromHttpParameters)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("http://h.xiami.com/", forHTTPHeaderField: "Referer")
        let (data, _) = try await sharedURLSession.data(for: req)
        let result = try JSONDecoder().decode(XiamiResponseSearchResult.self, from: data)
        return result.data.songs.map(LyricsToken.init)
    }

    public func fetchLyrics(token: LyricsToken) async throws -> Lyrics? {
        guard let lrcURLStr = token.value.lyric,
            let lrcURL = URL(string: lrcURLStr)
        else {
            return nil
        }
        let (data, _) = try await sharedURLSession.data(from: lrcURL)
        guard let lrcStr = String(data: data, encoding: .utf8),
            let lrc = Lyrics(ttpodXtrcContent: lrcStr)
        else {
            return nil
        }
        lrc.idTags[.title] = token.value.song_name
        lrc.idTags[.artist] = token.value.artist_name

        lrc.metadata.remoteURL = lrcURL
        lrc.metadata.artworkURL = token.value.album_logo
        lrc.metadata.serviceToken = token.value.lyric
        return lrc
    }
}
