//
//  NetEase.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore
internal import Regex

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let netEaseSearchBaseURLString = "http://music.163.com/api/search/pc?"
private let netEaseLyricsBaseURLString = "http://music.163.com/api/song/lyric?"

extension LyricsProviders {
    public final class NetEase {
        public init() {}
    }
}

extension LyricsProviders.NetEase: _LyricsProvider {

    public struct LyricsToken {
        let value: NetEaseResponseSearchResult.Result.Song
    }

    public static let service: LyricsProviders.Service? = .netease

    public func searchLyrics(request: LyricsSearchRequest) async throws -> [LyricsToken] {
        let parameter: [String: Any] = [
            "s": request.searchTerm.description,
            "offset": 0,
            "limit": 10,
            "type": 1,
        ]
        let url = URL(string: netEaseSearchBaseURLString + parameter.stringFromHttpParameters)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("http://music.163.com/", forHTTPHeaderField: "Referer")
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent")

        var (data, response) = try await sharedURLSession.data(for: req)
        if let httpResp = response as? HTTPURLResponse,
            let setCookie = httpResp.allHeaderFields["Set-Cookie"] as? String,
            let cookieIdx = setCookie.firstIndex(of: ";")
        {
            req.setValue(String(setCookie[..<cookieIdx]), forHTTPHeaderField: "Cookie")
            (data, _) = try await sharedURLSession.data(for: req)
        }
        let result = try JSONDecoder().decode(NetEaseResponseSearchResult.self, from: data)
        return result.songs.map(LyricsToken.init)
    }

    public func fetchLyrics(token: LyricsToken) async throws -> Lyrics? {
        let parameter: [String: Any] = [
            "id": token.value.id,
            "lv": 1,
            "kv": 1,
            "tv": -1,
        ]
        let url = URL(string: netEaseLyricsBaseURLString + parameter.stringFromHttpParameters)!
        let (data, _) = try await sharedURLSession.data(from: url)
        let result = try JSONDecoder().decode(NetEaseResponseSingleLyrics.self, from: data)
        let lyrics: Lyrics
        let transLrc = result.tlyric?.fixedLyric.flatMap(Lyrics.init(_:))
        if let kLrc = result.klyric?.fixedLyric.flatMap(Lyrics.init(netEaseKLyricContent:)) {
            transLrc.map(kLrc.forceMerge)
            lyrics = kLrc
        } else if let lrc = result.lrc?.fixedLyric.flatMap(Lyrics.init(_:)) {
            transLrc.map(lrc.merge)
            lyrics = lrc
        } else {
            return nil
        }

        // FIXME: merge inline time tags back to lyrics
        // if let taggedLrc = (model.klyric?.lyric).flatMap(Lyrics.init(netEaseKLyricContent:))

        lyrics.idTags[.title] = token.value.name
        lyrics.idTags[.artist] = token.value.artists.first?.name
        lyrics.idTags[.album] = token.value.album.name
        lyrics.idTags[.lrcBy] = result.lyricUser?.nickname

        lyrics.length = Double(token.value.duration) / 1000
        lyrics.metadata.artworkURL = token.value.album.picUrl
        lyrics.metadata.serviceToken = "\(token.value.id)"

        return lyrics
    }
}

private let netEaseTimeTagFixer = Regex(#"(\[\d+:\d+):(\d+\])"#)

extension NetEaseResponseSingleLyrics.Lyric {
    fileprivate var fixedLyric: String? {
        return lyric?.replacingMatches(of: netEaseTimeTagFixer, with: "$1.$2")
    }
}
