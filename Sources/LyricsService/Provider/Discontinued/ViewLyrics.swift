//
//  ViewLyrics.swift
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

#if canImport(FoundationXML)
import FoundationXML
#endif

private let viewLyricsSearchURL = URL(string: "http://search.crintsoft.com/searchlyrics.htm")!
private let viewLyricsItemBaseURL = URL(string: "http://viewlyrics.com/")!

extension LyricsProviders {
    public final class ViewLyrics {
        public init() {}
    }
}

extension LyricsProviders.ViewLyrics: _LyricsProvider {

    public struct LyricsToken {
        var value: ViewLyricsResponseSearchResult
    }

    public static let service: LyricsProviders.Service? = nil

    func assembleQuery(artist: String, title: String, page: Int = 0) -> Data {
        let watermark = "Mlv1clt4.0"
        let queryForm =
            "<?xml version='1.0' encoding='utf-8'?><searchV1 artist='\(artist)' title='\(title)' OnlyMatched='1' client='MiniLyrics' RequestPage='\(page)'/>"
        let queryhash = md5(queryForm + watermark)
        let header = Data([2, 0, 4, 0, 0, 0])
        return header + queryhash + queryForm.data(using: .utf8)!
    }

    public func searchLyrics(request: LyricsSearchRequest) async throws -> [LyricsToken] {
        guard case let .info(title, artist) = request.searchTerm else {
            // cannot search by keyword
            return []
        }
        var req = URLRequest(url: viewLyricsSearchURL)
        req.httpMethod = "POST"
        req.addValue("MiniLyrics", forHTTPHeaderField: "User-Agent")
        req.httpBody = assembleQuery(artist: artist, title: title)
        let (data, _) = try await sharedURLSession.data(for: req)
        let decrypted = Data(data[22...].map { $0 ^ data[1] })
        let parser = ViewLyricsResponseXMLParser()
        try parser.parseResponse(data: decrypted)
        return parser.result.map(LyricsToken.init)
    }

    public func fetchLyrics(token: LyricsToken) async throws -> Lyrics? {
        let token = token.value
        guard let url = URL(string: token.link, relativeTo: viewLyricsItemBaseURL) else {
            return nil
        }
        let (data, _) = try await sharedURLSession.data(from: url)
        guard let lrcContent = String(data: data, encoding: .utf8),
            let lrc = Lyrics(lrcContent)
        else {
            return nil
        }
        lrc.metadata.remoteURL = url
        lrc.metadata.serviceToken = token.link
        if let length = token.timelength, lrc.length == nil {
            lrc.length = TimeInterval(length)
        }
        return lrc
    }
}

private class ViewLyricsResponseXMLParser: NSObject, XMLParserDelegate {

    var result: [ViewLyricsResponseSearchResult] = []

    func parseResponse(data: Data) throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError!
        }
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String]
    ) {
        guard elementName == "fileinfo" else {
            return
        }
        guard let link = attributeDict["link"],
            let artist = attributeDict["artist"],
            let title = attributeDict["title"],
            let album = attributeDict["album"]
        else {
            return
        }
        let uploader = attributeDict["uploader"]
        var timelength: Int?
        if let lenStr = attributeDict["timelength"], let len = Int(lenStr), len != 65535 {
            timelength = len
        }
        let rate = attributeDict["rate"].flatMap(Double.init)
        let ratecount = attributeDict["ratecount"].flatMap(Int.init)
        let downloads = attributeDict["downloads"].flatMap(Int.init)
        let item = ViewLyricsResponseSearchResult(
            link: link, artist: artist, title: title, album: album, uploader: uploader,
            timelength: timelength, rate: rate, ratecount: ratecount, downloads: downloads)
        result.append(item)
    }
}
