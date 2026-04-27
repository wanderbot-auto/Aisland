import Foundation
import Testing
@testable import AislandApp
import AislandCore

struct QuestionCardLayoutTests {
    @Test
    func singleQuestionDoesNotShowDuplicatePromptTitle() {
        let matchingPrompt = QuestionPrompt(
            title: "Which environment?",
            questions: [
                QuestionPromptItem(
                    question: "Which environment?",
                    header: "Environment",
                    options: [
                        QuestionOption(label: "1"),
                        QuestionOption(label: "2"),
                    ]
                ),
            ]
        )
        let differentTitlePrompt = QuestionPrompt(
            title: "Codex needs input",
            questions: [
                QuestionPromptItem(
                    question: "Which environment should Codex use?",
                    header: "Environment",
                    options: [
                        QuestionOption(label: "1"),
                        QuestionOption(label: "2"),
                    ]
                ),
            ]
        )

        #expect(!QuestionCardPresentation.showsPromptTitle(for: matchingPrompt, fallback: "Answer needed"))
        #expect(!QuestionCardPresentation.showsPromptTitle(for: differentTitlePrompt, fallback: "Answer needed"))
    }

    @Test
    func multiQuestionStillShowsPromptTitle() {
        let prompt = QuestionPrompt(
            title: "Codex has 2 questions for you.",
            questions: [
                QuestionPromptItem(
                    question: "Which environment?",
                    header: "Environment",
                    options: [QuestionOption(label: "1")]
                ),
                QuestionPromptItem(
                    question: "Run tests?",
                    header: "Tests",
                    options: [QuestionOption(label: "Yes")]
                ),
            ]
        )

        #expect(QuestionCardPresentation.showsPromptTitle(for: prompt, fallback: "Answer needed"))
    }

    @MainActor
    @Test
    func questionOptionLayoutDefaultsToHorizontalAndPersistsVertical() {
        let defaults = UserDefaults.standard
        let key = AppModel.questionOptionLayoutDefaultsKey
        let oldValue = defaults.object(forKey: key)
        defer {
            if let oldValue {
                defaults.set(oldValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        let model = AppModel()
        #expect(model.questionOptionLayout == .horizontal)

        model.questionOptionLayout = .vertical
        #expect(defaults.string(forKey: key) == QuestionOptionLayout.vertical.rawValue)

        let reloadedModel = AppModel()
        #expect(reloadedModel.questionOptionLayout == .vertical)
    }

    @Test
    func horizontalHeightEstimateFitsThreeShortOptions() {
        let prompt = QuestionPrompt(
            title: "Choose one",
            questions: [
                QuestionPromptItem(
                    question: "Choose one",
                    header: "Choice",
                    options: [
                        QuestionOption(label: "1"),
                        QuestionOption(label: "2"),
                        QuestionOption(label: "3"),
                    ]
                ),
            ]
        )

        let horizontalHeight = QuestionCardLayoutMetrics.estimatedHeight(
            for: prompt,
            optionLayout: .horizontal,
            availableWidth: 508
        )
        let verticalHeight = QuestionCardLayoutMetrics.estimatedHeight(
            for: prompt,
            optionLayout: .vertical,
            availableWidth: 508
        )

        #expect(horizontalHeight >= QuestionCardLayoutMetrics.minimumCardHeight)
        #expect(horizontalHeight < verticalHeight)
    }
}
