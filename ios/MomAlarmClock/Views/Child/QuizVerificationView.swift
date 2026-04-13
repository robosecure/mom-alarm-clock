import SwiftUI

/// Quiz-based verification where the child must answer math questions correctly.
/// Difficulty increases at higher escalation levels.
struct QuizVerificationView: View {
    @Environment(ChildViewModel.self) private var vm
    @State private var userAnswer = ""
    @State private var feedback: String?
    @State private var feedbackColor: Color = .clear
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            Text("Wake-Up Quiz")
                .font(.title.bold())

            progressIndicator

            if vm.quizCurrentIndex < vm.quizQuestions.count {
                questionView(vm.quizQuestions[vm.quizCurrentIndex])
            } else if !vm.quizQuestions.isEmpty {
                completionView
            } else {
                ProgressView("Generating questions...")
            }

            Spacer()
        }
        .padding()
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<vm.quizQuestions.count, id: \.self) { index in
                Circle()
                    .fill(index < vm.quizCurrentIndex ? Color.green :
                          index == vm.quizCurrentIndex ? Color.purple : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
    }

    private func questionView(_ question: VerificationService.QuizQuestion) -> some View {
        VStack(spacing: 20) {
            Text(question.text)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .padding()
                .frame(maxWidth: .infinity)
                .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            TextField("Your answer", text: $userAnswer)
                .keyboardType(.numberPad)
                .font(.title)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .focused($isInputFocused)
                .onAppear { isInputFocused = true }

            if let feedback {
                Text(feedback)
                    .font(.subheadline.bold())
                    .foregroundStyle(feedbackColor)
            }

            Button("Submit") {
                checkAnswer(question)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(userAnswer.isEmpty)
        }
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            let passed = vm.quizCorrectCount >= vm.quizQuestions.count

            Image(systemName: passed ? "checkmark.circle.fill" : "arrow.counterclockwise")
                .font(.system(size: 64))
                .foregroundStyle(passed ? .green : .orange)

            Text(passed ? "All Correct!" : "Try Again")
                .font(.title.bold())

            Text("\(vm.quizCorrectCount)/\(vm.quizQuestions.count) correct")
                .font(.title3)
                .foregroundStyle(.secondary)

            if !passed {
                Button("New Quiz") {
                    Task { await vm.beginVerification() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func checkAnswer(_ question: VerificationService.QuizQuestion) {
        guard let answer = Int(userAnswer) else {
            feedback = "Enter a number"
            feedbackColor = .red
            return
        }

        if question.isCorrect(answer) {
            feedback = "Correct!"
            feedbackColor = .green
            vm.quizCorrectCount += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                vm.quizCurrentIndex += 1
                userAnswer = ""
                feedback = nil

                if vm.quizCurrentIndex >= vm.quizQuestions.count && vm.quizCorrectCount >= vm.quizQuestions.count {
                    Task { await vm.completeVerification(method: .quiz) }
                }
            }
        } else {
            feedback = "Wrong — try again"
            feedbackColor = .red
            userAnswer = ""
        }
    }
}
