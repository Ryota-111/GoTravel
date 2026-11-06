import Testing
import Foundation
@testable import GoTravel

/// MetricKit の診断を、送る文にまとめる（3.4）。JSON は Apple の jsonRepresentation() の形をまねたもの
struct DiagnosticsSummaryTests {

    private func json(_ object: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    @Test("落ちたときの版・理由・落ちたスレッドの処理の段をまとめる")
    func crash() throws {
        let frame3: [String: Any] = ["binaryName": "UIKitCore", "offsetIntoBinaryTextSegment": 4096, "binaryUUID": "AAAABBBB-1111"]
        let frame2: [String: Any] = ["binaryName": "GoTravel", "offsetIntoBinaryTextSegment": 123_456, "binaryUUID": "CCCCDDDD-2222",
                                     "subFrames": [frame3]]
        let other: [String: Any] = ["threadAttributed": false,
                                    "callStackRootFrames": [["binaryName": "libsystem", "offsetIntoBinaryTextSegment": 1]]]
        let crashed: [String: Any] = ["threadAttributed": true, "callStackRootFrames": [frame2]]
        let payload: [String: Any] = ["crashDiagnostics": [[
            "callStackTree": ["callStacks": [other, crashed]],
            "diagnosticMetaData": ["appVersion": "3.4", "appBuildVersion": "30", "osVersion": "iPhone OS 26.1",
                                   "deviceType": "iPhone17,3", "exceptionType": 1, "exceptionCode": 0, "signal": 11,
                                   "terminationReason": "Namespace SIGNAL, Code 11"]
        ]]]
        let text = try #require(DiagnosticsSummary.diagnostics(fromJSON: json(payload)))
        #expect(text.contains("■ 落ちた"))
        #expect(text.contains("3.4（30）"))
        #expect(text.contains("シグナル: 11"))
        #expect(text.contains("GoTravel +0x1e240 [CCCCDDDD]"))
        #expect(text.contains("UIKitCore +0x1000"))
        #expect(!text.contains("libsystem"), "落ちたスレッドではない段は入れない")
    }

    @Test("固まった時間を入れる")
    func hang() throws {
        let payload: [String: Any] = ["hangDiagnostics": [[
            "callStackTree": ["callStacks": [["threadAttributed": true,
                                              "callStackRootFrames": [["binaryName": "GoTravel", "offsetIntoBinaryTextSegment": 16]]]]],
            "diagnosticMetaData": ["appVersion": "3.4", "hangDuration": "3.2 sec"]
        ]]]
        let text = try #require(DiagnosticsSummary.diagnostics(fromJSON: json(payload)))
        #expect(text.contains("■ 固まった"))
        #expect(text.contains("3.2 sec"))
    }

    @Test("落ちても固まってもいなければ送らない")
    func nothing() {
        #expect(DiagnosticsSummary.diagnostics(fromJSON: json(["timeStampBegin": "x"])) == nil)
        #expect(DiagnosticsSummary.diagnostics(fromJSON: Data("壊れた".utf8)) == nil)
    }

    @Test("メモリ不足などで止められた回数をまとめる。ふつうの終わり方は入れない")
    func exits() throws {
        let payload: [String: Any] = [
            "metaData": ["appVersion": "3.3.1", "appBuildVersion": "29", "osVersion": "iPhone OS 18.6", "deviceType": "iPhone14,2"],
            "applicationExitMetrics": [
                "foregroundExitData": ["cumulativeNormalAppExitCount": 12,
                                       "cumulativeMemoryResourceLimitExitCount": 2,
                                       "cumulativeAppWatchdogExitCount": 1],
                "backgroundExitData": ["cumulativeNormalAppExitCount": 3, "cumulativeMemoryPressureExitCount": 0]
            ]
        ]
        let text = try #require(DiagnosticsSummary.exits(fromJSON: json(payload)))
        #expect(text.contains("画面に出ているとき"))
        #expect(text.contains("メモリの上限で止められた 2回"))
        #expect(text.contains("固まって止められた 1回"))
        #expect(!text.contains("裏にいるとき"), "回数が0なら出さない")
        #expect(!text.contains("12"))
    }

    @Test("ふつうの終わり方しか無ければ送らない")
    func onlyNormalExits() {
        let payload: [String: Any] = ["applicationExitMetrics": [
            "foregroundExitData": ["cumulativeNormalAppExitCount": 5]
        ]]
        #expect(DiagnosticsSummary.exits(fromJSON: json(payload)) == nil)
    }
}
