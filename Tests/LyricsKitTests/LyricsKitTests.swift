import XCTest
@testable import LyricsService

final class LyricsKitTests: XCTestCase {
    
    func testBasic() {
        let url = Bundle.module.url(forResource: "銀の龍の背に乗って", withExtension: "lrcx", subdirectory: "Resources")!
        let str = try! String(contentsOf: url)
        let lrc = Lyrics(str)!
        XCTAssertEqual(lrc.count, 61)
        XCTAssertEqual(lrc.idTags.count, 4)
        XCTAssertEqual(lrc.metadata.attachmentTags, [.timetag, .furigana, .translation(languageCode: "zh-Hans")])
        XCTAssertEqual(lrc.lineIndex(at: 0), nil)
        XCTAssertEqual(lrc.lineIndex(at: 50), 8)
        XCTAssertEqual(lrc.lineIndex(at: 320), 60)
        lrc.timeDelay = 50
        XCTAssertEqual(lrc.offset, 50000)
        XCTAssertEqual(lrc.lineIndex(at: 0), 8)
    }
    
    func testSearching() async {
        let source = LyricsProviders.Group()
        let searchReq = LyricsSearchRequest(searchTerm: .info(title: "Uprising", artist: "Muse"), duration: 305)
        for await _ in source.lyrics(request: searchReq) {}
    }
    
    func testNetEase() async {
        let provider = LyricsProviders.NetEase()
        let lyrics = provider.lyrics(request: .init(searchTerm: .info(title: "One Last You", artist: "光田康典"), duration: 0))
        for await _ in lyrics {}
    }
}
