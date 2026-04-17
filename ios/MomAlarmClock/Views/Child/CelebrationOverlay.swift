import SwiftUI

/// Lightweight confetti-style celebration shown on the child's first-ever approved verification.
/// Uses animated emoji symbols — no third-party dependencies.
struct CelebrationOverlay: View {
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        let symbol: String
        let startX: CGFloat
        let endX: CGFloat
        let delay: Double
        let size: CGFloat
    }

    private static let symbols = ["🎉", "⭐️", "🌟", "✨", "🎊", "💪", "🏆"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    ParticleView(particle: p, height: geo.size.height)
                }
            }
            .onAppear {
                particles = (0..<20).map { _ in
                    Particle(
                        symbol: Self.symbols.randomElement() ?? "🎉",
                        startX: CGFloat.random(in: 0...geo.size.width),
                        endX: CGFloat.random(in: -40...40),
                        delay: Double.random(in: 0...0.6),
                        size: CGFloat.random(in: 20...36)
                    )
                }
            }
        }
        .ignoresSafeArea()

        // Banner text
        VStack {
            Spacer()
            Text("First Wake-Up Complete!")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.green.gradient, in: Capsule())
                .shadow(radius: 8)
                .padding(.bottom, 60)
        }
    }
}

private struct ParticleView: View {
    let particle: CelebrationOverlay.Particle
    let height: CGFloat
    @State private var animate = false

    var body: some View {
        Text(particle.symbol)
            .font(.system(size: particle.size))
            .offset(
                x: particle.startX + (animate ? particle.endX : 0),
                y: animate ? height + 40 : -40
            )
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(
                    .easeIn(duration: Double.random(in: 2.0...3.5))
                    .delay(particle.delay)
                ) {
                    animate = true
                }
            }
    }
}
