import AppKit
import CoreGraphics
import Foundation
import AislandCore

enum QuestionCardPresentation {
    static func promptTitle(
        for prompt: QuestionPrompt?,
        fallback: String
    ) -> String {
        prompt?.title.trimmedForNotificationCard ?? fallback
    }

    static func showsPromptTitle(for prompt: QuestionPrompt?, fallback: String) -> Bool {
        let title = promptTitle(for: prompt, fallback: fallback)
        guard !title.isEmpty else {
            return false
        }

        let questions = prompt?.questions ?? []
        guard questions.count == 1 else {
            return true
        }

        guard let questionText = questions.first?.question.trimmedForNotificationCard,
              !questionText.isEmpty else {
            return true
        }

        // A single-question prompt reads better when the card shows only the
        // specific question text, even if the prompt title is slightly different.
        return false
    }
}

enum QuestionCardLayoutMetrics {
    static let minimumCardHeight: CGFloat = 150
    static let maximumCardHeight: CGFloat = 520

    static func estimatedHeight(
        for prompt: QuestionPrompt?,
        optionLayout: QuestionOptionLayout,
        availableWidth: CGFloat
    ) -> CGFloat {
        guard let prompt, !prompt.questions.isEmpty else {
            return minimumCardHeight
        }

        let contentWidth = max(220, availableWidth)
        let titleHeight: CGFloat = QuestionCardPresentation.showsPromptTitle(
            for: prompt,
            fallback: ""
        ) ? 28 : 0

        var questionContentHeight: CGFloat = 0
        for (index, question) in prompt.questions.enumerated() {
            if index > 0 {
                questionContentHeight += 10
            }
            if prompt.questions.count > 1 {
                questionContentHeight += 16
            }
            questionContentHeight += measuredTextHeight(
                question.question,
                width: contentWidth,
                font: .systemFont(ofSize: 12, weight: .medium),
                minimum: 17
            )
            questionContentHeight += 6
            questionContentHeight += optionsHeight(
                for: question.options,
                layout: optionLayout,
                availableWidth: contentWidth
            )
        }

        // Outer padding (20) + title spacing + question/submit spacing (10)
        // + submit button (~32) + card border rounding allowance (6).
        let chromeHeight: CGFloat = 68 + titleHeight
        let estimatedHeight = chromeHeight + questionContentHeight
        return min(maximumCardHeight, max(minimumCardHeight, ceil(estimatedHeight)))
    }

    static func optionsHeight(
        for options: [QuestionOption],
        layout: QuestionOptionLayout,
        availableWidth: CGFloat
    ) -> CGFloat {
        guard !options.isEmpty else { return 0 }

        let usesVerticalRows = layout == .vertical || options.contains(where: isRichOption)
        if usesVerticalRows {
            let rows = options.map { option in
                isRichOption(option) ? CGFloat(44) : CGFloat(30)
            }
            return rows.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * 4
        }

        let minimumChipWidth: CGFloat = 78
        let spacing: CGFloat = 6
        let columnCount = max(1, Int((availableWidth + spacing) / (minimumChipWidth + spacing)))
        let rowCount = Int(ceil(Double(options.count) / Double(columnCount)))
        return CGFloat(rowCount) * 30 + CGFloat(max(0, rowCount - 1)) * spacing
    }

    private static func isRichOption(_ option: QuestionOption) -> Bool {
        option.allowsFreeform || !option.description.trimmedForNotificationCard.isEmpty
    }

    private static func measuredTextHeight(
        _ text: String,
        width: CGFloat,
        font: NSFont,
        minimum: CGFloat
    ) -> CGFloat {
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return max(minimum, ceil(rect.height))
    }
}
