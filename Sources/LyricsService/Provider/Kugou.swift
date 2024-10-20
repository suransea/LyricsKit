//
//  Kugou.swift
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

private let kugouSearchBaseURLString = "http://lyrics.kugou.com/search"
private let kugouLyricsBaseURLString = "http://lyrics.kugou.com/download"

extension LyricsProviders {
    public final class Kugou {
        public init() {}
    }
}

extension LyricsProviders.Kugou: _LyricsProvider {

    public struct LyricsToken {
        let value: KugouResponseSearchResult.Item
    }

    public static let service: LyricsProviders.Service? = .kugou

    public func searchLyrics(request: LyricsSearchRequest) async throws -> [LyricsToken] {
        let parameter: [String: Any] = [
            "keyword": request.searchTerm.description,
            "duration": Int(request.duration * 1000),
            "client": "pc",
            "ver": 1,
            "man": "yes",
        ]
        let url = URL(string: kugouSearchBaseURLString + "?" + parameter.stringFromHttpParameters)!
        let (data, _) = try await sharedURLSession.data(from: url)
        let result = try JSONDecoder().decode(KugouResponseSearchResult.self, from: data)
        return result.candidates.map(LyricsToken.init)
    }

    public func fetchLyrics(token: LyricsToken) async throws -> Lyrics? {
        let token = token.value
        let parameter: [String: Any] = [
            "id": token.id,
            "accesskey": token.accesskey,
            "fmt": "krc",
            "charset": "utf8",
            "client": "pc",
            "ver": 1,
        ]
        let url = URL(string: kugouLyricsBaseURLString + "?" + parameter.stringFromHttpParameters)!
        let (data, _) = try await sharedURLSession.data(from: url)
        let result = try JSONDecoder().decode(KugouResponseSingleLyrics.self, from: data)
        guard let lrcContent = decryptKugouKrc(result.content),
            let lrc = Lyrics(kugouKrcContent: lrcContent)
        else {
            return nil
        }
        lrc.idTags[.title] = token.song
        lrc.idTags[.artist] = token.singer
        lrc.idTags[.lrcBy] = "Kugou"

        lrc.length = Double(token.duration) / 1000
        lrc.metadata.serviceToken = "\(token.id),\(token.accesskey)"
        return lrc
    }
}
