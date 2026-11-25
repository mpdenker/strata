import SwiftUI
import LessonKit

/// Inline quiz check (1–2 questions). Doesn't block scrolling. Saving answers into review arrives in Step 2.
struct CheckView: View {
    let check: Check
    let lessonID: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Quick check", systemImage: "checkmark.circle")
                .font(.caption2Strong)
                .textCase(.uppercase)
                .foregroundStyle(theme.topicInk)
            ForEach(check.questions) { q in
                QuestionCard(question: q, seed: lessonID + "." + q.id)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Color.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).strokeBorder(theme.topic, lineWidth: 1.5))
    }
}

/// One multiple-choice or true/false question. Pick an answer → see right/wrong + the explanation.
/// Reused by the final quiz and review sessions.
struct QuestionCard: View {
    let question: Question
    /// Stable shuffle seed (the question's global ID), so options don't move around between redraws.
    let seed: String
    var onAnswer: ((_ correct: Bool) -> Void)? = nil

    @State private var picked: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var options: [String] {
        question.kind == .trueFalse ? question.displayChoices : question.displayChoices.stableShuffled(seed: seed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            md(question.prompt)
                .font(.headline)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(options, id: \.self) { option in
                ChoiceButton(text: option, state: state(for: option)) {
                    guard picked == nil else { return }
                    withAnimation(reduceMotion ? nil : .snappy) { picked = option }
                    onAnswer?(question.isCorrect(choiceText: option))
                }
            }
            if let picked {
                Feedback(correct: question.isCorrect(choiceText: picked), explanation: question.explanation)
                    .transition(.opacity)
            }
        }
    }

    private func state(for option: String) -> ChoiceButton.State {
        guard let picked else { return .idle }
        let isRight = question.isCorrect(choiceText: option)
        if option == picked { return isRight ? .pickedCorrect : .pickedWrong }
        return isRight ? .revealedCorrect : .dimmed
    }
}

struct ChoiceButton: View {
    enum State { case idle, pickedCorrect, pickedWrong, revealedCorrect, dimmed }

    let text: String
    let state: State
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                md(text)
                    .font(.body)
                    .foregroundStyle(state == .dimmed ? Color.inkMuted : Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let icon {
                    Image(systemName: icon.name).foregroundStyle(icon.color).font(.title3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(border, lineWidth: state == .idle ? 1 : 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .accessibilityLabel(Text(plain(text)))
        .accessibilityValue(accessibilityValue)
    }

    private var icon: (name: String, color: Color)? {
        switch state {
        case .pickedCorrect, .revealedCorrect: ("checkmark.circle.fill", .correct)
        case .pickedWrong: ("xmark.circle.fill", .wrong)
        default: nil
        }
    }

    private var fill: Color {
        switch state {
        case .pickedCorrect, .revealedCorrect: Color.correct.opacity(0.12)
        case .pickedWrong: Color.wrong.opacity(0.10)
        default: Color.paper
        }
    }

    private var border: Color {
        switch state {
        case .idle: .rule
        case .pickedCorrect, .revealedCorrect: .correct
        case .pickedWrong: .wrong
        case .dimmed: .rule
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .idle: ""
        case .pickedCorrect: "Your answer. Correct."
        case .pickedWrong: "Your answer. Incorrect."
        case .revealedCorrect: "Correct answer."
        case .dimmed: ""
        }
    }
}

/// Always icon + words + color, never color alone.
struct Feedback: View {
    let correct: Bool
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(correct ? "Correct" : "Not quite", systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(correct ? Color.correct : Color.wrong)
            md(explanation)
                .font(.callout)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill((correct ? Color.correct : Color.wrong).opacity(0.08)))
        .accessibilityElement(children: .combine)
    }
}
