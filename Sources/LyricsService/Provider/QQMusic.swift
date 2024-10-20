//
//  QQMusic.swift
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

private let qqSearchBaseURLString = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp"
private let qqLyricsBaseURLString = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg"

extension LyricsProviders {
    public final class QQMusic {
        public init() {}
    }
}

extension LyricsProviders.QQMusic: _LyricsProvider {

    public struct LyricsToken {
        let value: QQResponseSearchResult.Data.Song.Item
    }

    public static let service: LyricsProviders.Service? = .qq

    public func searchLyrics(request: LyricsSearchRequest) async throws -> [LyricsToken] {
        let parameter = ["w": request.searchTerm.description]
        let url = URL(string: qqSearchBaseURLString + "?" + parameter.stringFromHttpParameters)!
        var (data, _) = try await sharedURLSession.data(from: url)
        data = data.dropFirst(9).dropLast(1)
        let result = try JSONDecoder().decode(QQResponseSearchResult.self, from: data)
        return result.data.song.list.map(LyricsToken.init)
    }

    public func fetchLyrics(token: LyricsToken) async throws -> Lyrics? {
        let token = token.value
        let parameter: [String: Any] = [
            "songmid": token.songmid,
            "g_tk": 5381,
        ]
        let url = URL(string: qqLyricsBaseURLString + "?" + parameter.stringFromHttpParameters)!
        var req = URLRequest(url: url)
        req.setValue("y.qq.com/portal/player.html", forHTTPHeaderField: "Referer")
        var (data, _) = try await sharedURLSession.data(for: req)
        data = data.dropFirst(18).dropLast()
        guard
            let model = try? JSONDecoder().decode(QQResponseSingleLyrics.self, from: data),
            let lrcContent = model.lyricString,
            let lrc = Lyrics(lrcContent)
        else {
            return nil
        }
        if let transLrcContent = model.transString,
            let transLrc = Lyrics(transLrcContent)
        {
            lrc.merge(translation: transLrc)
        }

        lrc.idTags[.title] = token.songname
        lrc.idTags[.artist] = token.singer.first?.name
        lrc.idTags[.album] = token.albumname

        lrc.length = Double(token.interval)
        lrc.metadata.serviceToken = "\(token.songmid)"
        if let id = Int(token.songmid) {
            lrc.metadata.artworkURL = URL(
                string: "http://imgcache.qq.com/music/photo/album/\(id % 100)/\(id).jpg")
        }

        // remove their kana tag. we don't need it.
        lrc.idTags.removeValue(forKey: .qqMusicKana)

        return lrc
    }
}
