import XCTest
@testable import AislandApp
import AislandCore

final class TerminalTextSenderTests: XCTestCase {
    func testGhosttySendScriptFocusesTargetThenUsesSystemEvents() {
        let script = TerminalTextSender.ghosttySendScript(
            text: "1",
            target: JumpTarget(
                terminalApp: "Ghostty",
                workspaceName: "Aisland",
                paneTitle: "codex Aisland",
                workingDirectory: "/Users/wander/Documents/code/apps/Aisland",
                terminalSessionID: "session-123"
            )
        )

        XCTAssertTrue(script.contains("set targetSessionID to \"session-123\""))
        XCTAssertTrue(script.contains("set targetWorkingDirectory to \"/Users/wander/Documents/code/apps/Aisland\""))
        XCTAssertTrue(script.contains("set targetPaneTitle to \"codex Aisland\""))
        XCTAssertTrue(script.contains("set replyText to \"1\""))
        XCTAssertTrue(script.contains("activate window targetWindow"))
        XCTAssertTrue(script.contains("select tab targetTab"))
        XCTAssertTrue(script.contains("focus targetTerminal"))
        XCTAssertTrue(script.contains("tell application \"System Events\""))
        XCTAssertTrue(script.contains("keystroke replyText"))
        XCTAssertTrue(script.contains("key code 36"))
    }

    func testGhosttySendScriptAvoidsUnsupportedInputTextSyntax() {
        let script = TerminalTextSender.ghosttySendScript(
            text: "2",
            target: JumpTarget(
                terminalApp: "Ghostty",
                workspaceName: "Aisland",
                paneTitle: "codex Aisland",
                workingDirectory: "/tmp/Aisland"
            )
        )

        XCTAssertFalse(script.contains("input text"))
        XCTAssertFalse(script.contains("send key \"enter\""))
    }

    func testGhosttySendScriptEscapesReplyTextAsAppleScriptExpression() {
        let script = TerminalTextSender.ghosttySendScript(
            text: "one \"two\"\\three\nfour\tfive",
            target: JumpTarget(
                terminalApp: "Ghostty",
                workspaceName: "Aisland",
                paneTitle: "codex Aisland",
                workingDirectory: "/tmp/Aisland"
            )
        )

        XCTAssertTrue(script.contains("set replyText to \"one \\\"two\\\"\\\\three\" & linefeed & \"four\" & tab & \"five\""))
        XCTAssertFalse(script.contains("one \"two\"\\three\nfour\tfive"))
    }
}
