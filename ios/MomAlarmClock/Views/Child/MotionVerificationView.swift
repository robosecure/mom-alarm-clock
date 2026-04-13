import SwiftUI

/// Motion / step counter verification view.
/// The child must walk a minimum number of steps to dismiss the alarm.
struct MotionVerificationView: View {
    @Environment(ChildViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "figure.walk")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .repeating)

            Text("Get Moving!")
                .font(.title.bold())

            if let progress = vm.motionProgress {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(.gray.opacity(0.2), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: min(progress.percentage, 1.0))
                        .stroke(.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress.currentSteps)

                    VStack {
                        Text("\(progress.currentSteps)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("of \(progress.requiredSteps) steps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 200, height: 200)

                if progress.isComplete {
                    Label("Verification Complete!", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            } else {
                ProgressView("Starting pedometer...")
                    .padding()

                Text("Walk at least 50 steps to verify you're awake.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }
}
