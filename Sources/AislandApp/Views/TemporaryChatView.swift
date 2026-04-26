import AppKit
import SwiftUI
@preconcurrency import MarkdownUI

struct TemporaryChatView: View {
    var model: AppModel

    @State private var draft = ""
    @State private var showsClearConfirmation = false
    @FocusState private var isInputFocused: Bool

    private var lang: LanguageManager { model.lang }

    var body: some View {
        VStack(spacing: 10) {
            header
            messages
            composer
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            isInputFocused = true
        }
        .confirmationDialog(lang.t("chat.clearConfirm.title"), isPresented: $showsClearConfirmation) {
            Button(lang.t("chat.clear"), role: .destructive) {
                model.clearTemporaryChat()
            }
            Button(lang.t("chat.clearConfirm.cancel"), role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("chat.title"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text("\(model.temporaryChatProvider.displayName) · \(model.temporaryChatModel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
                tokenUsageView
            }

            Spacer(minLength: 0)

            if model.temporaryChatIsSending {
                Button(lang.t("chat.stop")) {
                    model.cancelTemporaryChatResponse()
                }
                .buttonStyle(ChatSecondaryButtonStyle())
            } else if model.temporaryChatMessages.contains(where: { $0.role == .user }) {
                Button(lang.t("chat.retry")) {
                    model.retryLastTemporaryChatMessage()
                }
                .buttonStyle(ChatSecondaryButtonStyle())
            }

            Button(lang.t("chat.clear")) {
                showsClearConfirmation = true
            }
            .buttonStyle(ChatSecondaryButtonStyle())
            .disabled(model.temporaryChatMessages.isEmpty || model.temporaryChatIsSending)
        }
    }

    private var tokenUsageView: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tokenUsageSummary)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(model.temporaryChatTokenStats.contextRatio > 0.8 ? Color.orange.opacity(0.76) : Color.cyan.opacity(0.66))
                        .frame(width: max(3, proxy.size.width * model.temporaryChatTokenStats.contextRatio))
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: 230, alignment: .leading)
    }

    private var tokenUsageSummary: String {
        let stats = model.temporaryChatTokenStats
        let source = stats.source == .provider ? lang.t("chat.token.provider") : lang.t("chat.token.estimated")
        return lang.t(
            "chat.token.summary",
            Self.formatTokenCount(stats.inputTokens),
            "\(stats.contextPercentage)%",
            source
        )
    }

    private static func formatTokenCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return value.formatted()
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    if model.temporaryChatMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.temporaryChatMessages) { message in
                            if message.isRenderable {
                                TemporaryChatBubble(message: message, lang: lang)
                                    .id(message.id)
                            }
                        }
                    }

                    if model.temporaryChatIsSending {
                        HStack(spacing: 6) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.55)
                                .tint(.white.opacity(0.58))
                            Text(lang.t("chat.waiting"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.44))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }

                    if let error = model.temporaryChatLastError {
                        Text(error)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .frame(minHeight: 220)
            .onChange(of: model.temporaryChatMessages) { _, newValue in
                guard let last = newValue.last else { return }
                withAnimation(.smooth(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.sparkles.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.cyan.opacity(0.82))
            Text(lang.t("chat.empty.title"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
            Text(lang.t("chat.empty.subtitle"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.temporaryChatPendingParts.isEmpty {
                pendingAttachmentTray
            }

            HStack(spacing: 8) {
                capabilityButtons

                TextField(lang.t("chat.placeholder"), text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .focused($isInputFocused)
                    .onSubmit(send)

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(canSend ? 0.9 : 0.35))
                        .frame(width: 26, height: 26)
                        .background(canSend ? Color.cyan : Color.white.opacity(0.22), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var capabilityButtons: some View {
        HStack(spacing: 5) {
            capabilityButton(
                systemName: "globe",
                isSupported: model.temporaryChatCanUseWebSearch,
                isSelected: model.temporaryChatWebSearchEnabled,
                help: model.temporaryChatCanUseWebSearch ? lang.t("chat.capability.web") : lang.t("chat.capability.unsupported"),
                action: model.toggleTemporaryChatWebSearch
            )
            capabilityButton(
                systemName: "photo",
                isSupported: model.temporaryChatCanAttachImages,
                isSelected: false,
                help: model.temporaryChatCanAttachImages ? lang.t("chat.capability.image") : lang.t("chat.capability.unsupported"),
                action: model.importTemporaryChatImageAttachments
            )
            capabilityButton(
                systemName: "paperclip",
                isSupported: model.temporaryChatCanAttachFiles,
                isSelected: false,
                help: model.temporaryChatCanAttachFiles ? lang.t("chat.capability.file") : lang.t("chat.capability.unsupported"),
                action: model.importTemporaryChatFileAttachments
            )
        }
    }

    private func capabilityButton(
        systemName: String,
        isSupported: Bool,
        isSelected: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black.opacity(0.86) : Color.white.opacity(isSupported ? 0.64 : 0.24))
                .frame(width: 24, height: 24)
                .background(isSelected ? Color.cyan : Color.white.opacity(isSupported ? 0.10 : 0.04), in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSupported ? 0.05 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isSupported || model.temporaryChatIsSending)
        .help(help)
    }

    private var pendingAttachmentTray: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(model.temporaryChatPendingParts) { part in
                    TemporaryChatPartChip(part: part, removable: true, lang: lang) {
                        model.removeTemporaryChatPendingPart(id: part.id)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var canSend: Bool {
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.temporaryChatPendingParts.isEmpty)
            && !model.temporaryChatIsSending
    }

    private func send() {
        guard canSend else { return }
        let prompt = draft
        draft = ""
        model.sendTemporaryChatMessage(prompt)
    }
}

private struct TemporaryChatBubble: View {
    let message: TemporaryChatMessage
    let lang: LanguageManager

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 44) }

            bubbleContent
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isUser ? Color.cyan.opacity(0.24) : Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isUser ? Color.cyan.opacity(0.26) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

            if !isUser { Spacer(minLength: 44) }
        }
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            if isUser {
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
            } else {
                if !message.content.isEmpty {
                    Markdown(message.content)
                        .markdownTheme(.temporaryChat)
                        .markdownImageProvider(.default)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

            ForEach(message.parts) { part in
                switch part {
                case .text:
                    EmptyView()
                case let .image(attachment):
                    TemporaryChatImageAttachmentView(attachment: attachment, lang: lang)
                case .file, .webCitation, .toolResult:
                    TemporaryChatPartChip(part: part, removable: false, lang: lang)
                }
            }
        }
        .contextMenu {
            Button(isUser ? lang.t("chat.copy.prompt") : lang.t("chat.copy.reply")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
            }
        }
    }
}

private struct TemporaryChatImageAttachmentView: View {
    let attachment: TemporaryChatAttachmentPart
    let lang: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let image = NSImage(data: attachment.data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 220, maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            TemporaryChatPartChip(part: .image(attachment), removable: false, lang: lang)
        }
    }
}

private struct TemporaryChatPartChip: View {
    let part: TemporaryChatMessagePart
    var removable: Bool
    let lang: LanguageManager
    var removeAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .lineLimit(1)
            if removable {
                Button {
                    removeAction?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white.opacity(0.76))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.10), in: Capsule())
    }

    private var iconName: String {
        switch part {
        case .text:
            "text.alignleft"
        case .image:
            "photo"
        case .file:
            "doc"
        case .webCitation:
            "link"
        case .toolResult:
            "wrench.and.screwdriver"
        }
    }

    private var title: String {
        switch part {
        case let .text(text):
            text.text
        case let .image(attachment):
            "\(attachment.filename) · \(Self.formatBytes(attachment.byteCount))"
        case let .file(attachment):
            "\(attachment.filename) · \(Self.formatBytes(attachment.byteCount))"
        case let .webCitation(citation):
            citation.title
        case let .toolResult(result):
            "\(result.toolName): \(result.summary)"
        }
    }

    private static func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private extension MarkdownUI.Theme {
    @MainActor static let temporaryChat = Theme()
        .text {
            ForegroundColor(.white.opacity(0.84))
            FontSize(12.5)
            FontWeight(.medium)
        }
        .link {
            ForegroundColor(.cyan)
        }
        .strong {
            FontWeight(.bold)
            ForegroundColor(.white.opacity(0.9))
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(12)
            ForegroundColor(.white.opacity(0.9))
            BackgroundColor(.white.opacity(0.09))
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(12)
                    ForegroundColor(.white.opacity(0.86))
                }
                .padding(10)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .markdownMargin(top: 6, bottom: 6)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(15)
                    FontWeight(.bold)
                    ForegroundColor(.white.opacity(0.9))
                }
                .markdownMargin(top: 6, bottom: 3)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(14)
                    FontWeight(.bold)
                    ForegroundColor(.white.opacity(0.9))
                }
                .markdownMargin(top: 6, bottom: 3)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(13)
                    FontWeight(.semibold)
                    ForegroundColor(.white.opacity(0.9))
                }
                .markdownMargin(top: 5, bottom: 2)
        }
        .blockquote { configuration in
            configuration.label
                .markdownTextStyle {
                    ForegroundColor(.white.opacity(0.62))
                    FontSize(12.5)
                }
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.cyan.opacity(0.35))
                        .frame(width: 3)
                }
        }
        .image { configuration in
            configuration.label
                .frame(maxWidth: .infinity, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
                .markdownMargin(top: 6, bottom: 6)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(.allBorders, color: .white.opacity(0.14), strokeStyle: .init(lineWidth: 1)))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.white.opacity(0.03), Color.white.opacity(0.07))
                )
                .markdownMargin(top: 4, bottom: 8)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .relativeLineSpacing(.em(0.2))
        }
}

private struct ChatSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.45 : 0.62))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(configuration.isPressed ? 0.13 : 0.08), in: Capsule())
    }
}
