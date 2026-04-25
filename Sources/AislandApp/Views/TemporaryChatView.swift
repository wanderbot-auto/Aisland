import SwiftUI
@preconcurrency import MarkdownUI

struct TemporaryChatView: View {
    var model: AppModel

    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    private var lang: LanguageManager { model.lang }

    var body: some View {
        VStack(spacing: 10) {
            header
            messages
            composer
        }
        .onAppear {
            isInputFocused = true
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
            }

            Spacer(minLength: 0)

            Button(lang.t("chat.clear")) {
                model.clearTemporaryChat()
            }
            .buttonStyle(ChatSecondaryButtonStyle())
            .disabled(model.temporaryChatMessages.isEmpty || model.temporaryChatIsSending)
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    if model.temporaryChatMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.temporaryChatMessages) { message in
                            if !message.content.isEmpty {
                                TemporaryChatBubble(message: message)
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
        HStack(spacing: 8) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.temporaryChatIsSending
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

    @ViewBuilder
    private var bubbleContent: some View {
        if isUser {
            Text(message.content)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
        } else {
            Markdown(message.content)
                .markdownTheme(.temporaryChat)
                .markdownImageProvider(.default)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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
