import SwiftUI

/// Quiz-based verification where the child must answer math questions correctly.
/// Difficulty increases at higher escalation levels.
struct QuizVerificationView: View {
    @Environment(ChildViewModel.self) private var vm
    @State private var userAnswer = ""
    @State private var feedback: String?
    @State private var feedbackColor: Color = .clear
    @State private var questionStartTime: Date = .now
    @State private var timeRemaining: Int = 45
    @State private var questionTimer: Timer?
    @State private var totalAnswerTime: Double = 0
    @State private var attemptsOnCurrentQuestion: Int = 0
    /// Reads from guardian overrides if set, otherwise defaults to 3.
    private var maxAttemptsPerQuestion: Int {
        vm.effectiveConfig?.maxAttempts ?? 3
    }
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
            // Timer + attempts
            HStack(spacing: 24) {
                Label("\(timeRemaining)s", systemImage: "timer")
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(timeRemaining <= 10 ? .red : .secondary)
                Label("Attempt \(attemptsOnCurrentQuestion + 1)/\(maxAttemptsPerQuestion)", systemImage: "number")
                    .font(.subheadline)
                    .foregroundStyle(attemptsOnCurrentQuestion >= maxAttemptsPerQuestion - 1 ? .red : .secondary)
            }
            .onAppear {
                attemptsOnCurrentQuestion = 0
                startQuestionTimer()
            }

            Text(question.text)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .padding()
                .frame(maxWidth: .infinity)
                .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Math problem: \(question.text)")

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
                    .sensoryFeedback(feedbackColor == .green ? .success : .error, trigger: feedback)
            }

            HStack(spacing: 16) {
                Button {
                    Task { await vm.sendMessageToParent("I'm working on it!") }
                } label: {
                    Label("I'm trying!", systemImage: "hand.wave")
                        .frame(minHeight: 48)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("Send message to guardian: I'm trying")

                Button("Submit") {
                    checkAnswer(question)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 48)
                .disabled(userAnswer.isEmpty)
                .accessibilityLabel("Submit answer")
            }
        }
    }

    private func startQuestionTimer() {
        questionStartTime = .now
        let limit = vm.effectiveConfig?.timerSeconds ?? vm.effectiveVerificationTier.quizTimeLimitSeconds
        timeRemaining = limit
        questionTimer?.invalidate()
        questionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let elapsed = Int(Date.now.timeIntervalSince(questionStartTime))
            timeRemaining = max(0, limit - elapsed)
            if timeRemaining == 0 {
                // Time expired — mark as wrong and advance
                questionTimer?.invalidate()
                let q = vm.quizQuestions[safe: vm.quizCurrentIndex]
                feedback = "Time's up! Answer was \(q?.correctAnswer ?? 0)"
                feedbackColor = .orange
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    totalAnswerTime += Double(limit)
                    vm.quizCurrentIndex += 1
                    userAnswer = ""
                    feedback = nil
                    if vm.quizCurrentIndex < vm.quizQuestions.count {
                        startQuestionTimer()
                    }
                }
            }
        }
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            let passed = vm.quizCorrectCount >= vm.quizQuestions.count

            Image(systemName: passed ? "checkmark.circle.fill" : "arrow.counterclockwise")
                .font(.system(size: 64))
                .foregroundStyle(passed ? .green : .orange)

            Text(passed ? "All Correct!" : "Not quite!")
                .font(.title.bold())

            Text("\(vm.quizCorrectCount)/\(vm.quizQuestions.count) correct")
                .font(.title3)
                .foregroundStyle(.secondary)

            if !passed {
                Text("You need all correct to verify. Let's try new questions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("New Questions") {
                    Task { await vm.beginVerification() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            questionTimer?.invalidate()
            let passed = vm.quizCorrectCount >= vm.quizQuestions.count
            if passed {
                let avgSeconds = vm.quizQuestions.isEmpty ? 0 : totalAnswerTime / Double(vm.quizQuestions.count)
                let result = VerificationResult(
                    method: .quiz,
                    completedAt: Date(),
                    tier: vm.effectiveConfig?.tier ?? vm.effectiveVerificationTier,
                    passed: true,
                    quizCorrect: vm.quizCorrectCount,
                    quizTotal: vm.quizQuestions.count,
                    quizAverageSeconds: avgSeconds,
                    deviceTimestamp: Date()
                )
                Task { await vm.completeVerification(method: .quiz, result: result) }
            }
        }
    }

    private func checkAnswer(_ question: VerificationService.QuizQuestion) {
        guard let answer = Int(userAnswer) else {
            feedback = "Enter a number"
            feedbackColor = .red
            return
        }

        let elapsed = Date.now.timeIntervalSince(questionStartTime)
        questionTimer?.invalidate()

        if question.isCorrect(answer) {
            feedback = "Correct!"
            feedbackColor = .green
            vm.quizCorrectCount += 1
            totalAnswerTime += elapsed

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                vm.quizCurrentIndex += 1
                userAnswer = ""
                feedback = nil
                if vm.quizCurrentIndex < vm.quizQuestions.count {
                    startQuestionTimer()
                }
                // Completion is handled by completionView.onAppear
            }
        } else {
            attemptsOnCurrentQuestion += 1
            if attemptsOnCurrentQuestion >= maxAttemptsPerQuestion {
                feedback = "Out of attempts — the answer was \(question.correctAnswer)"
                feedbackColor = .orange
                questionTimer?.invalidate()
                totalAnswerTime += elapsed
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    vm.quizCurrentIndex += 1
                    userAnswer = ""
                    feedback = nil
                    attemptsOnCurrentQuestion = 0
                    if vm.quizCurrentIndex < vm.quizQuestions.count {
                        startQuestionTimer()
                    }
                }
            } else {
                feedback = "Incorrect — \(maxAttemptsPerQuestion - attemptsOnCurrentQuestion) attempts left"
                feedbackColor = .red
                userAnswer = ""
            }
        }
    }
}
