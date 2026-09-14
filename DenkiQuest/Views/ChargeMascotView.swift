import SwiftUI

/// 長押しで充電し、6 秒でショートするマスコット。
struct ChargeMascotView: View {
    let size: CGFloat
    /// ショートした瞬間に呼ばれる（画面全体のフラッシュなどに使う）
    var onShortCircuit: () -> Void = {}

    @State private var controller = ChargeController()
    @State private var isPressing = false
    @State private var releasePulse: CGFloat = 1.0

    var body: some View {
        TimelineView(.animation(paused: controller.phase == .idle)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let charge = controller.charge
            let phase = controller.phase

            ZStack {
                glow(charge: charge, phase: phase)
                arcs(charge: charge, phase: phase, time: t)
                chargeRing(charge: charge, phase: phase)
                mascot(charge: charge, phase: phase, time: t)
                sparks(phase: phase, now: context.date)
                caption(charge: charge, phase: phase)
            }
        }
        .frame(width: size * 1.9, height: size * 1.9)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 60, maximumDistance: 40) {
            // minimumDuration を長くしているので perform は使わない
        } onPressingChanged: { pressing in
            if pressing {
                guard !isPressing else { return }
                isPressing = true
                controller.pressBegan()
            } else {
                guard isPressing else { return }
                isPressing = false
                let released = controller.charge
                controller.pressEnded()
                if released >= 0.06 {
                    releasePulse = 1.0 + 0.25 * released
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
                        releasePulse = 1.0
                    }
                } else {
                    releasePulse = 0.92
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        releasePulse = 1.0
                    }
                }
            }
        }
        .onChange(of: controller.phase) { _, phase in
            if phase == .shorted {
                onShortCircuit()
            }
        }
        .accessibilityLabel("マスコット。長押しで充電、6 秒でショート")
    }

    // MARK: - パーツ

    private func mascotScale(charge: Double, phase: ChargeController.Phase) -> CGFloat {
        switch phase {
        case .charging: return 1.0 + 0.6 * charge
        case .shorted: return 1.35
        case .cooldown: return 0.9
        case .idle: return releasePulse
        }
    }

    private func jitter(charge: Double, phase: ChargeController.Phase, time: Double) -> CGSize {
        let amount: Double
        switch phase {
        case .charging: amount = charge * charge * 7
        case .shorted: amount = 10
        default: amount = 0
        }
        guard amount > 0 else { return .zero }
        return CGSize(width: sin(time * 71) * amount, height: cos(time * 53) * amount)
    }

    private func glow(charge: Double, phase: ChargeController.Phase) -> some View {
        let heat = phase == .shorted ? 1.0 : charge
        return Circle()
            .fill(
                RadialGradient(
                    colors: [glowColor(heat: heat).opacity(0.25 + 0.55 * heat), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * (0.55 + 0.5 * heat)
                )
            )
            .scaleEffect(1.0 + 0.4 * heat)
    }

    private func glowColor(heat: Double) -> Color {
        heat > 0.8 ? .white : (heat > 0.5 ? Color(red: 1.0, green: 0.95, blue: 0.6) : Theme.volt)
    }

    private func chargeRing(charge: Double, phase: ChargeController.Phase) -> some View {
        let visible = phase == .charging
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: charge)
                .stroke(
                    AngularGradient(
                        colors: [Theme.volt, Color(red: 1.0, green: 0.6, blue: 0.2), Theme.wrong],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: visible)
    }

    private func mascot(charge: Double, phase: ChargeController.Phase, time: Double) -> some View {
        let dead = phase == .shorted || phase == .cooldown
        let heat = phase == .shorted ? 1.0 : charge
        return Image("Mascot")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(dead ? 0.15 : 1.0)
            .brightness(dead ? -0.35 : 0.25 * heat)
            .rotationEffect(.degrees(phase == .cooldown ? -12 : 0))
            .scaleEffect(mascotScale(charge: charge, phase: phase))
            .offset(jitter(charge: charge, phase: phase, time: time))
            .shadow(color: glowColor(heat: heat).opacity(0.4 + 0.6 * heat), radius: 12 + 28 * heat)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: phase)
            .overlay(alignment: .top) {
                if phase == .cooldown {
                    Image(systemName: "smoke.fill")
                        .font(.system(size: size * 0.32))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .offset(x: size * 0.15, y: -size * 0.15 - CGFloat(sin(time * 2) * 6))
                        .transition(.opacity)
                }
            }
    }

    /// 充電中に周囲に走る稲妻。時間で種を変えてチラつかせる。
    private func arcs(charge: Double, phase: ChargeController.Phase, time: Double) -> some View {
        Canvas { context, canvasSize in
            let count: Int
            switch phase {
            case .charging: count = Int(charge * 7)
            case .shorted: count = 12
            default: count = 0
            }
            guard count > 0 else { return }

            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            var rng = SeededGenerator(seed: UInt64(max(0, time) * 18))
            let heat = phase == .shorted ? 1.0 : charge
            let s = Double(size)
            let baseRadius = s * 0.5 * (1.0 + 0.6 * heat)

            for _ in 0..<count {
                let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
                let length = Double.random(in: (s * 0.25)...(s * 0.7), using: &rng) * (0.5 + heat)
                var path = Path()
                var point = CGPoint(
                    x: center.x + cos(angle) * baseRadius,
                    y: center.y + sin(angle) * baseRadius
                )
                path.move(to: point)
                let segments = 5
                for i in 1...segments {
                    let progress = Double(i) / Double(segments)
                    let wobble = Double.random(in: -12...12, using: &rng)
                    point = CGPoint(
                        x: center.x + cos(angle) * (baseRadius + length * progress) + cos(angle + .pi / 2) * wobble,
                        y: center.y + sin(angle) * (baseRadius + length * progress) + sin(angle + .pi / 2) * wobble
                    )
                    path.addLine(to: point)
                }
                let color: Color = heat > 0.75 ? .white : Theme.volt
                context.stroke(path, with: .color(color.opacity(0.85)), lineWidth: 2)
                context.stroke(path, with: .color(color.opacity(0.35)), lineWidth: 6)
            }
        }
        .allowsHitTesting(false)
    }

    /// ショート時に飛び散る火花。
    private func sparks(phase: ChargeController.Phase, now: Date) -> some View {
        Canvas { context, canvasSize in
            guard phase == .shorted, let shortedAt = controller.shortedAt else { return }
            let age = now.timeIntervalSince(shortedAt)
            guard age < 0.9 else { return }
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            var rng = SeededGenerator(seed: 12345)
            for i in 0..<28 {
                let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
                let speed = Double.random(in: 120...340, using: &rng)
                let delay = Double(i % 4) * 0.03
                let life = max(0, age - delay)
                let distance = speed * life - 180 * life * life
                let position = CGPoint(
                    x: center.x + cos(angle) * distance,
                    y: center.y + sin(angle) * distance + 220 * life * life
                )
                let alpha = max(0, 1 - life / 0.8)
                let radius = 2.0 + Double.random(in: 0...2.5, using: &rng)
                let rect = CGRect(x: position.x - radius, y: position.y - radius, width: radius * 2, height: radius * 2)
                let color: Color = i % 3 == 0 ? .white : (i % 3 == 1 ? Theme.volt : Color(red: 1.0, green: 0.55, blue: 0.2))
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }

    private func caption(charge: Double, phase: ChargeController.Phase) -> some View {
        VStack {
            Spacer()
            Group {
                switch phase {
                case .charging:
                    Text(charge > 0.85 ? "危険！" : (charge > 0.5 ? "まだいける？" : "充電中…"))
                        .foregroundStyle(charge > 0.85 ? Theme.wrong : Theme.volt)
                case .shorted:
                    Text("ショート！")
                        .foregroundStyle(.white)
                        .font(.title.weight(.black))
                        .shadow(color: Theme.wrong, radius: 8)
                case .cooldown:
                    Text("ちょっと休ませて…")
                        .foregroundStyle(Theme.textSecondary)
                case .idle:
                    EmptyView()
                }
            }
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.35), in: Capsule())
            .opacity(phase == .idle ? 0 : 1)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: phase)
        .allowsHitTesting(false)
    }
}

/// 時間で種を変えて「チラつき」を作るための、簡単な乱数生成器。
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
