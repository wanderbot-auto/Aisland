import SwiftUI

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
                            TemporaryChatBubble(message: message)
                                .id(message.id)
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

            Text(message.content)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(isUser ? 0.92 : 0.82))
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
