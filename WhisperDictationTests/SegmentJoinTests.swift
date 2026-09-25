import XCTest
@testable import VoiceKeyboard

final class SegmentJoinTests: XCTestCase {
    func testFirstSegmentHasNoSeparator() {
        let collector = TranscriptCollector()
        XCTAssertEqual(collector.joinAndAppend("First sentence."), "First sentence.")
        XCTAssertEqual(collector.text, "First sentence.")
    }

    func testLaterSegmentsGetLeadingSpaceInBothOutputs() {
        let collector = TranscriptCollector()
        _ = collector.joinAndAppend("First sentence.")
        XCTAssertEqual(collector.joinAndAppend("Second sentence."), " Second sentence.")
        XCTAssertEqual(collector.text, "First sentence. Second sentence.")
    }
}

final class LiveSessionDecisionTests: XCTestCase {
    func testResidualMinimumIsSampleCountBased() {
        XCTAssertFalse(DictationEngine.residualMeetsMinimum(sampleCount: 0))
        XCTAssertFalse(DictationEngine.residualMeetsMinimum(sampleCount: 4799))   // < 0.3 s
        XCTAssertTrue(DictationEngine.residualMeetsMinimum(sampleCount: 4800))    // = 0.3 s @16 kHz
    }

    func testTerminalSuffixRule() {
        XCTAssertNil(DictationEngine.terminalSuffix(committed: ""))
        XCTAssertNil(DictationEngine.terminalSuffix(committed: "Done."))
        XCTAssertNil(DictationEngine.terminalSuffix(committed: "Really?"))
        XCTAssertNil(DictationEngine.terminalSuffix(committed: "现在，句号："))
        XCTAssertNil(DictationEngine.terminalSuffix(committed: "现在结束。"))
        XCTAssertEqual(DictationEngine.terminalSuffix(committed: "open the file"), ".")
        XCTAssertEqual(DictationEngine.terminalSuffix(committed: "现在可以开始"), "。")
        XCTAssertEqual(DictationEngine.terminalSuffix(committed: "现在可以 start"), ".")
    }
}
