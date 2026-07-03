import SwiftUI

/// One-shot particle bursts drawn with Canvas. Every particle is a pure function of
/// elapsed time (position/opacity computed from launch parameters), so a burst costs
/// one Canvas redraw per frame and stops rendering entirely when it finishes.
/// Respects Reduced Motion by rendering nothing.
struct ParticleBurst: View {
    enum Kind { case smoke, confetti, stars }

    let kind: Kind
    var colors: [Color] = [.white]
    /// Emission origin in unit coordinates of the burst's frame.
    var origin: UnitPoint = .center
    var count: Int = 0            // 0 → kind default
    var seed: UInt64 = 9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date = .distantFuture
    @State private var finished = false

    var body: some View {
        Group {
            if !reduceMotion && !finished {
                TimelineView(.animation) { ctx in
                    Canvas { context, size in
                        let t = ctx.date.timeIntervalSince(start)
                        guard t >= 0 else { return }
                        draw(in: &context, size: size, t: t)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            start = .now
            DispatchQueue.main.asyncAfter(deadline: .now() + lifespan) { finished = true }
        }
    }

    // MARK: Parameters per kind

    private var lifespan: Double {
        switch kind {
        case .smoke:    return 2.2
        case .confetti: return 3.0
        case .stars:    return 0.9
        }
    }

    private var particles: [Particle] {
        var rng = SplitMix64(seed: seed)
        let n = count > 0 ? count : (kind == .confetti ? 90 : (kind == .smoke ? 24 : 12))
        return (0..<n).map { _ in Particle(kind: kind, using: &rng, paletteCount: max(colors.count, 1)) }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, t: Double) {
        let o = CGPoint(x: origin.x * size.width, y: origin.y * size.height)
        for p in particles {
            let age = t - p.delay
            guard age > 0, age < p.life else { continue }
            let f = age / p.life                       // 0→1 through the particle's life
            let color = colors[p.hue % max(colors.count, 1)]

            switch kind {
            case .smoke:
                // Slow radial drift with a rising bias; grows and softly fades.
                let dist = p.speed * age
                let x = o.x + cos(p.angle) * dist + sin(age * p.wobbleFreq + p.phase) * 6
                let y = o.y + sin(p.angle) * dist - 26 * age
                let r = p.size + p.growth * age
                let alpha = 0.5 * (1 - f) * (1 - f)
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Circle().path(in: rect),
                             with: .radialGradient(Gradient(colors: [color.opacity(alpha), color.opacity(0)]),
                                                   center: CGPoint(x: x, y: y),
                                                   startRadius: 0, endRadius: r))
            case .confetti:
                // Launch up and out, gravity pulls down, pieces spin and sway.
                let vx = cos(p.angle) * p.speed
                let vy = sin(p.angle) * p.speed
                let x = o.x + vx * age + sin(age * p.wobbleFreq + p.phase) * 14
                let y = o.y + vy * age + 320 * age * age
                let alpha = f > 0.75 ? (1 - f) / 0.25 : 1.0
                var piece = context
                piece.translateBy(x: x, y: y)
                piece.rotate(by: .radians(p.spin * age + p.phase))
                let rect = CGRect(x: -p.size / 2, y: -p.size / 3.4, width: p.size, height: p.size / 1.7)
                piece.fill(RoundedRectangle(cornerRadius: p.size * 0.18).path(in: rect),
                           with: .color(color.opacity(alpha)))
            case .stars:
                // Quick sparkle: diamonds shoot out and shrink.
                let dist = p.speed * age * (2 - f)     // decelerating
                let x = o.x + cos(p.angle) * dist
                let y = o.y + sin(p.angle) * dist
                let s = p.size * (1 - f)
                var piece = context
                piece.translateBy(x: x, y: y)
                piece.rotate(by: .radians(p.spin * age + .pi / 4))
                let rect = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
                piece.fill(RoundedRectangle(cornerRadius: s * 0.2).path(in: rect),
                           with: .color(color.opacity(1 - f * f)))
            }
        }
    }
}

/// Launch parameters rolled once per particle; motion derives from these + time.
private struct Particle {
    let angle: Double
    let speed: Double
    let size: Double
    let growth: Double
    let spin: Double
    let wobbleFreq: Double
    let phase: Double
    let delay: Double
    let life: Double
    let hue: Int

    init(kind: ParticleBurst.Kind, using rng: inout SplitMix64, paletteCount: Int) {
        func rand(_ r: ClosedRange<Double>) -> Double { Double.random(in: r, using: &rng) }
        switch kind {
        case .smoke:
            angle = rand(0...(2 * .pi))
            speed = rand(16...58)
            size = rand(20...46)
            growth = rand(18...42)
            spin = 0
            life = rand(1.1...2.0)
            delay = rand(0...0.25)
        case .confetti:
            angle = rand((-Double.pi * 0.85)...(-Double.pi * 0.15))   // upward fan
            speed = rand(190...430)
            size = rand(8...15)
            growth = 0
            spin = rand(-9...9)
            life = rand(1.9...2.8)
            delay = rand(0...0.15)
        case .stars:
            angle = rand(0...(2 * .pi))
            speed = rand(90...200)
            size = rand(5...10)
            growth = 0
            spin = rand(-6...6)
            life = rand(0.45...0.8)
            delay = rand(0...0.08)
        }
        wobbleFreq = rand(1.5...4.0)
        phase = rand(0...(2 * .pi))
        hue = Int(rng.next() % UInt64(max(paletteCount, 1)))
    }
}

/// Slow, huge, soft mist wisps that drift across the map so it feels alive.
/// Two blurred ellipses on very long linear loops; skipped under Reduced Motion.
struct DriftingMist: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        if !reduceMotion {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack {
                    wisp(width: w * 0.62, height: 130, opacity: 0.10)
                        .offset(x: drift ? w * 0.75 : -w * 0.65, y: geo.size.height * 0.28)
                        .animation(.linear(duration: 85).repeatForever(autoreverses: false), value: drift)
                    wisp(width: w * 0.5, height: 100, opacity: 0.08)
                        .offset(x: drift ? -w * 0.7 : w * 0.8, y: geo.size.height * 0.62)
                        .animation(.linear(duration: 110).repeatForever(autoreverses: false), value: drift)
                }
            }
            .allowsHitTesting(false)
            .onAppear { drift = true }
        }
    }

    private func wisp(width: CGFloat, height: CGFloat, opacity: Double) -> some View {
        Ellipse()
            .fill(Color.white.opacity(opacity))
            .frame(width: width, height: height)
            .blur(radius: 38)
    }
}
