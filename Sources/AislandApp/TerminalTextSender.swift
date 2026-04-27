import Foundation
import AislandCore

/// Sends reply text to a terminal where an agent session is running.
///
/// Currently supported:
/// - **tmux**: `tmux send-keys -l "text" Enter`
/// - **Ghostty**: AppleScript focus + System Events keystrokes
///
/// The static ``canReply(to:)`` method gates the UI — the reply input field
/// is only shown when the session's terminal supports text injection.
struct TerminalTextSender {

    // MARK: - Capability check

    static func canReply(to session: AgentSession, enabled: Bool) -> Bool {
        guard enabled else { return false }
        guard session.phase == .completed else { return false }
        guard let target = session.jumpTarget else { return false }

        // tmux sessions: any terminal can receive send-keys.
        if target.tmuxTarget != nil { return true }

        // Ghostty: focus the matching terminal, then type through System Events.
        let app = target.terminalApp.lowercased()
        if app == "ghostty" { return true }

        return false
    }

    // MARK: - Send

    /// Send `text` followed by Enter to the terminal that owns `session`.
    /// Returns `true` on success.
    @discardableResult
    static func send(_ text: String, to session: AgentSession) -> Bool {
        guard let target = session.jumpTarget else { return false }

        // Prefer tmux when available — it targets a specific pane without
        // needing to activate/focus the terminal window.
        if let tmuxTarget = target.tmuxTarget {
            return sendViaTmux(text, tmuxTarget: tmuxTarget, socketPath: target.tmuxSocketPath)
        }

        let app = target.terminalApp.lowercased()
        if app == "ghostty" {
            return sendViaGhostty(text, target: target)
        }

        return false
    }

    // MARK: - tmux

    private static func sendViaTmux(_ text: String, tmuxTarget: String, socketPath: String?) -> Bool {
        guard let tmuxPath = resolveTmuxPath() else { return false }

        var baseArgs: [String] = []
        if let socketPath, !socketPath.isEmpty {
            baseArgs = ["-S", socketPath]
        }

        // Send the literal text (no Enter yet).
        let textResult = runProcess(tmuxPath, arguments: baseArgs + ["send-keys", "-t", tmuxTarget, "-l", text])
        guard textResult else { return false }

        // Send Enter as a separate command.
        return runProcess(tmuxPath, arguments: baseArgs + ["send-keys", "-t", tmuxTarget, "Enter"])
    }

    // MARK: - Ghostty

    private static func sendViaGhostty(_ text: String, target: JumpTarget) -> Bool {
        // Build an AppleScript that:
        //   1. Activates Ghostty
        //   2. Sends the reply text + newline via System Events
        //
        // Do not use Ghostty-specific scripting terms here: Ghostty 1.2.x
        // advertises partial terminology that fails to compile for commands
        // such as `working directory of terminal`.
        let script = ghosttySendScript(text: text, target: target)
        return runAppleScript(script)
    }

    static func ghosttySendScript(text: String, target _: JumpTarget) -> String {
        let replyText = appleScriptStringExpression(text)

        return """
        set replyText to \(replyText)

        tell application "Ghostty" to activate
        delay 0.08

        tell application "System Events"
            tell process "Ghostty"
                set frontmost to true
            end tell
            keystroke replyText
            key code 36
        end tell

        return "ok"
        """
    }

    // MARK: - Helpers

    private static func appleScriptStringExpression(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "\"\"" }

        var expressions: [String] = []
        var literal = ""

        func flushLiteral() {
            guard !literal.isEmpty else { return }
            expressions.append("\"\(literal)\"")
            literal = ""
        }

        for character in value {
            switch character {
            case "\n":
                flushLiteral()
                expressions.append("linefeed")
            case "\r":
                flushLiteral()
                expressions.append("return")
            case "\t":
                flushLiteral()
                expressions.append("tab")
            case "\"":
                literal += "\\\""
            case "\\":
                literal += "\\\\"
            default:
                literal.append(character)
            }
        }

        flushLiteral()
        return expressions.isEmpty ? "\"\"" : expressions.joined(separator: " & ")
    }

    private static func runAppleScript(_ script: String) -> Bool {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            NSLog("[Aisland] TerminalTextSender: AppleScript compilation failed")
            return false
        }
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            NSLog("[Aisland] TerminalTextSender AppleScript error: %@", String(describing: error))
            return false
        }
        return result.stringValue == "ok"
    }

    private static func resolveTmuxPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/tmux",
            "/usr/local/bin/tmux",
            "/usr/bin/tmux",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: `which tmux`
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["tmux"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let output, FileManager.default.isExecutableFile(atPath: output) {
                return output
            }
        } catch {}
        return nil
    }

    @discardableResult
    private static func runProcess(_ path: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
