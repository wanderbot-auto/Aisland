import XCTest
@testable import AislandApp
import AislandCore

final class TerminalTextSenderTests: XCTestCase {
    func testGhosttySendScriptActivatesGhosttyThenUsesSystemEvents() {
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

        XCTAssertTrue(script.contains("set replyText to \"1\""))
        XCTAssertTrue(script.contains("tell application \"Ghostty\" to activate"))
        XCTAssertTrue(script.contains("tell application \"System Events\""))
        XCTAssertTrue(script.contains("tell process \"Ghostty\""))
        XCTAssertTrue(script.contains("set frontmost to true"))
        XCTAssertTrue(script.contains("repeat 10 times"))
        XCTAssertTrue(script.contains("frontmost of process \"Ghostty\""))
        XCTAssertTrue(script.contains("keystroke replyText"))
        XCTAssertTrue(script.contains("key code 36"))
    }

    func testGhosttyFocusScriptTargetsTerminalBeforeTyping() {
        let script = TerminalTextSender.ghosttyFocusScript(
            for: JumpTarget(
                terminalApp: "Ghostty",
                workspaceName: "Aisland",
                paneTitle: "codex Aisland",
                workingDirectory: "/Users/wander/Documents/code/apps/Aisland",
                terminalSessionID: "session-123"
            )
        )

        XCTAssertTrue(script.contains("(id of aTerminal as text) is \"session-123\""))
        XCTAssertTrue(script.contains("select tab targetTab"))
        XCTAssertTrue(script.contains("focus targetTerminal"))
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
        XCTAssertFalse(script.contains("working directory of"))
        XCTAssertFalse(script.contains("focused terminal"))
        XCTAssertFalse(script.contains("focus targetTerminal"))
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
