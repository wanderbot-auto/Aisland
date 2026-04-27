import SwiftUI
import AislandCore

struct IslandQuestionCardView: View {
    let prompt: QuestionPrompt?
    var optionLayout: QuestionOptionLayout = .horizontal
    var lang: LanguageManager = .shared
    let onAnswer: (QuestionPromptResponse) -> Void

    @State private var selections: [String: Set<String>] = [:]
    @State private var freeformTexts: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsPromptTitle {
                Text(promptTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.yellow.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(structuredQuestions.enumerated()), id: \.offset) { _, question in
                    questionRow(question)
                }

                Button(lang.t("question.submit")) {
                    onAnswer(QuestionPromptResponse(answers: answerMap))
                }
                .buttonStyle(IslandWideButtonStyle(kind: .primary))
                .disabled(!hasCompleteSelection)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.06))
        )
    }

    // MARK: - Per-question row

    /// Renders a single question with its header, text, and configured option layout.
    @ViewBuilder
    private func questionRow(_ question: QuestionPromptItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if structuredQuestions.count > 1 {
                Text(question.header)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(question.question)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            optionsView(for: question)
        }
    }

    // MARK: - Options

    @ViewBuilder
    private func optionsView(for question: QuestionPromptItem) -> some View {
        if optionLayout == .horizontal {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: horizontalOptionMinimumWidth(for: question), maximum: 180),
                        spacing: 6,
                        alignment: .leading
                    ),
                ],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(question.options) { option in
                    if usesRichPresentation(option) {
                        optionTile(option, question: question)
                    } else {
                        optionChip(option, question: question)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(question.options) { option in
                    optionRow(option, question: question)
                }
            }
        }
    }

    @ViewBuilder
    private func optionChip(_ option: QuestionOption, question: QuestionPromptItem) -> some View {
        let isSelected = selectedLabels(for: question).contains(option.label)
        Button {
            toggle(option: option.label, for: question)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isSelected ? .yellow : .white.opacity(0.35))

                Text(option.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
            .padding(.horizontal, 9)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.yellow.opacity(0.10) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? .yellow.opacity(0.25) : .clear)
        )
    }

    @ViewBuilder
    private func optionTile(_ option: QuestionOption, question: QuestionPromptItem) -> some View {
        let isSelected = selectedLabels(for: question).contains(option.label)
        let showsFreeform = option.allowsFreeform && isSelected
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggle(option: option.label, for: question)
            } label: {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(isSelected ? .yellow : .white.opacity(0.35))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        if !option.description.isEmpty {
                            Text(option.description)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.white.opacity(0.42))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 7)
                .padding(.horizontal, 9)
            }
            .buttonStyle(.plain)

            if showsFreeform {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                freeformField(for: option, question: question)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.yellow.opacity(0.10) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? .yellow.opacity(0.25) : .clear)
        )
    }

    @ViewBuilder
    private func optionRow(_ option: QuestionOption, question: QuestionPromptItem) -> some View {
        let isSelected = selectedLabels(for: question).contains(option.label)
        let showsFreeform = option.allowsFreeform && isSelected
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggle(option: option.label, for: question)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .yellow : .white.opacity(0.35))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(option.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.78))

                        if !option.description.isEmpty {
                            Text(option.description)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)

            if showsFreeform {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                freeformField(for: option, question: question)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.yellow.opacity(0.10) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? .yellow.opacity(0.25) : .clear)
        )
    }

    @ViewBuilder
    private func freeformField(for option: QuestionOption, question: QuestionPromptItem) -> some View {
        let key = freeformKey(for: question, option: option)
        IslandReplyTextField(
            placeholder: lang.t("question.otherPlaceholder"),
            text: Binding(
                get: { freeformTexts[key] ?? "" },
                set: { freeformTexts[key] = $0 }
            ),
            onSubmit: {
                if hasCompleteSelection {
                    onAnswer(QuestionPromptResponse(answers: answerMap))
                }
            }
        )
        .frame(height: 22)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    // MARK: - Helpers

    private var structuredQuestions: [QuestionPromptItem] {
        prompt?.questions ?? []
    }

    private var promptTitle: String {
        QuestionCardPresentation.promptTitle(
            for: prompt,
            fallback: lang.t("question.answerNeeded")
        )
    }

    private var showsPromptTitle: Bool {
        QuestionCardPresentation.showsPromptTitle(
            for: prompt,
            fallback: lang.t("question.answerNeeded")
        )
    }

    private var answerMap: [String: String] {
        Dictionary(uniqueKeysWithValues: structuredQuestions.compactMap { question in
            let values = resolvedAnswers(for: question)
            guard !values.isEmpty else {
                return nil
            }
            return (answerKey(for: question), values.joined(separator: ", "))
        })
    }

    private var hasCompleteSelection: Bool {
        structuredQuestions.allSatisfy { question in
            let selected = selectedLabels(for: question)
            guard !selected.isEmpty else {
                return false
            }
            // When a freeform option is selected, require non-empty text.
            for option in question.options where option.allowsFreeform && selected.contains(option.label) {
                if trimmedFreeform(for: question, option: option).isEmpty {
                    return false
                }
            }
            return true
        }
    }

    private func selectedLabels(for question: QuestionPromptItem) -> Set<String> {
        selections[question.question] ?? []
    }

    private func answerKey(for question: QuestionPromptItem) -> String {
        guard let id = question.id?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty else {
            return question.question
        }
        return id
    }

    private func resolvedAnswers(for question: QuestionPromptItem) -> [String] {
        let selected = selectedLabels(for: question)
        guard !selected.isEmpty else { return [] }

        let optionOrder = question.options
        var answers: [String] = []
        for option in optionOrder where selected.contains(option.label) {
            if option.allowsFreeform {
                let text = trimmedFreeform(for: question, option: option)
                answers.append(text.isEmpty ? option.label : text)
            } else {
                answers.append(option.label)
            }
        }
        return answers
    }

    private func freeformKey(for question: QuestionPromptItem, option: QuestionOption) -> String {
        "\(question.question)|\(option.label)"
    }

    private func trimmedFreeform(for question: QuestionPromptItem, option: QuestionOption) -> String {
        (freeformTexts[freeformKey(for: question, option: option)] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func usesRichOptionRows(for question: QuestionPromptItem) -> Bool {
        question.options.contains { option in
            usesRichPresentation(option)
        }
    }

    private func usesRichPresentation(_ option: QuestionOption) -> Bool {
        option.allowsFreeform || !option.description.trimmedForNotificationCard.isEmpty
    }

    private func horizontalOptionMinimumWidth(for question: QuestionPromptItem) -> CGFloat {
        usesRichOptionRows(for: question) ? 142 : 78
    }

    private func toggle(option: String, for question: QuestionPromptItem) {
        var selected = selections[question.question] ?? []

        if question.multiSelect {
            if selected.contains(option) {
                selected.remove(option)
            } else {
                selected.insert(option)
            }
        } else {
            if selected.contains(option) {
                selected.removeAll()
            } else {
                selected = [option]
            }
        }

        selections[question.question] = selected
    }
}
