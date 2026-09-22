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
                smoke(phase: phase, time: t)
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
        let dx: Double = sin(time * 71) * amount
        let dy: Double = cos(time * 53) * amount
        return CGSize(width: dx, height: dy)
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
        let burnt: Bool = phase == .shorted || phase == .cooldown
        let heat: Double = phase == .shorted ? 1.0 : charge
        return ZStack {
            // 通常 → こげた姿へ、重ねて入れ替える
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .brightness(0.25 * heat)
                .opacity(burnt ? 0 : 1)
            Image("MascotBurnt")
                .resizable()
                .scaledToFit()
                .opacity(burnt ? 1 : 0)
        }
        .frame(width: size, height: size)
        .brightness(phase == .cooldown ? -0.12 : 0)
        .rotationEffect(.degrees(dazedTilt(phase: phase, time: time)))
        .scaleEffect(mascotScale(charge: charge, phase: phase))
        .offset(jitter(charge: charge, phase: phase, time: time))
        .shadow(color: burnt ? Color(red: 1.0, green: 0.42, blue: 0.2).opacity(0.5)
                              : glowColor(heat: heat).opacity(0.4 + 0.6 * heat),
                radius: burnt ? 16 : 12 + 28 * heat)
        .animation(.easeOut(duration: 0.18), value: burnt)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: phase)
    }

    /// こげたあとの、ふらふらした傾き。
    private func dazedTilt(phase: ChargeController.Phase, time: Double) -> Double {
        switch phase {
        case .cooldown: return -12.0 + sin(time * 2.6) * 5.0
        case .shorted: return sin(time * 30) * 3.0
        default: return 0
        }
    }

    /// こげているあいだ、頭から立ちのぼる煙。
    private func smoke(phase: ChargeController.Phase, time: Double) -> some View {
        let visible: Bool = phase == .shorted || phase == .cooldown
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                smokePuff(index: index, time: time)
            }
        }
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: visible)
        .allowsHitTesting(false)
    }

    private func smokePuff(index: Int, time: Double) -> some View {
        let s: Double = Double(size)
        let cycle: Double = (time * 0.55 + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        let fontSize: Double = s * (0.15 + 0.14 * cycle)
        let dx: Double = s * (Double(index) - 1.0) * 0.18 + sin(time * 1.8 + Double(index) * 2.0) * 5.0
        let dy: Double = -s * (0.30 + 0.55 * cycle)
        let alpha: Double = (1.0 - cycle) * 0.5
        return Image(systemName: "smoke.fill")
            .font(.system(size: CGFloat(fontSize)))
            .foregroundStyle(Color.white.opacity(alpha))
            .offset(x: CGFloat(dx), y: CGFloat(dy))
    }

    /// 充電中に周囲に走る稲妻。時間で種を変えてチラつかせる。
    private func arcs(charge: Double, phase: ChargeController.Phase, time: Double) -> some View {
        Canvas { context, canvasSize in
            let count = Self.arcCount(charge: charge, phase: phase)
            guard count > 0 else { return }

            let heat: Double = phase == .shorted ? 1.0 : charge
            let centerX = Double(canvasSize.width) / 2
            let centerY = Double(canvasSize.height) / 2
            let s = Double(size)
            let baseRadius = s * 0.5 * (1.0 + 0.6 * heat)
            var rng = SeededGenerator(seed: UInt64(max(0, time) * 18))
            let color: Color = heat > 0.75 ? .white : Theme.volt

            for _ in 0..<count {
                let path = Self.lightningPath(
                    centerX: centerX,
                    centerY: centerY,
                    baseRadius: baseRadius,
                    size: s,
                    heat: heat,
                    rng: &rng
                )
                context.stroke(path, with: .color(color.opacity(0.85)), lineWidth: 2)
                context.stroke(path, with: .color(color.opacity(0.35)), lineWidth: 6)
            }
        }
        .allowsHitTesting(false)
    }

    private static func arcCount(charge: Double, phase: ChargeController.Phase) -> Int {
        switch phase {
        case .charging: return Int(charge * 7)
        case .shorted: return 12
        default: return 0
        }
    }

    /// 中心から外へ向かうジグザグ線を 1 本作る。
    private static func lightningPath(
        centerX: Double,
        centerY: Double,
        baseRadius: Double,
        size s: Double,
        heat: Double,
        rng: inout SeededGenerator
    ) -> Path {
        let twoPi: Double = 2 * Double.pi
        let angle: Double = Double.random(in: 0..<twoPi, using: &rng)
        let minLength: Double = s * 0.25
        let maxLength: Double = s * 0.7
        let length: Double = Double.random(in: minLength...maxLength, using: &rng) * (0.5 + heat)
        let dirX: Double = cos(angle)
        let dirY: Double = sin(angle)
        let sideX: Double = cos(angle + Double.pi / 2)
        let sideY: Double = sin(angle + Double.pi / 2)

        var path = Path()
        let startX: Double = centerX + dirX * baseRadius
        let startY: Double = centerY + dirY * baseRadius
        path.move(to: CGPoint(x: startX, y: startY))

        let segments = 5
        for i in 1...segments {
            let progress: Double = Double(i) / Double(segments)
            let wobble: Double = Double.random(in: -12...12, using: &rng)
            let radial: Double = baseRadius + length * progress
            let x: Double = centerX + dirX * radial + sideX * wobble
            let y: Double = centerY + dirY * radial + sideY * wobble
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }

    /// ショート時に飛び散る火花と、そのあと舞い落ちるすす。
    private func sparks(phase: ChargeController.Phase, now: Date) -> some View {
        Canvas { context, canvasSize in
            guard phase == .shorted || phase == .cooldown,
                  let shortedAt = controller.shortedAt else { return }
            let age: Double = now.timeIntervalSince(shortedAt)
            guard age < 2.2 else { return }

            let centerX = Double(canvasSize.width) / 2
            let centerY = Double(canvasSize.height) / 2

            // すす: ゆっくり舞い落ちる黒い粒
            var sootRng = SeededGenerator(seed: 777)
            for i in 0..<16 {
                let delay: Double = Double(i) * 0.04
                let life: Double = age - delay
                guard life > 0, life < 2.0 else { continue }
                let angle: Double = Double.random(in: 0..<(2 * Double.pi), using: &sootRng)
                let spread: Double = Double.random(in: 20...90, using: &sootRng)
                let drift: Double = sin(life * 3.0 + Double(i)) * 10
                let x: Double = centerX + cos(angle) * spread * min(1.0, life * 2.0) + drift
                let y: Double = centerY + sin(angle) * spread * 0.4 + 70 * life * life
                let radius: Double = 1.6 + Double.random(in: 0...2.0, using: &sootRng)
                let alpha: Double = max(0, 1 - life / 1.8) * 0.75
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(alpha)))
            }

            guard age < 0.9 else { return }
            var rng = SeededGenerator(seed: 12345)
            let twoPi: Double = 2 * Double.pi

            for i in 0..<28 {
                let angle: Double = Double.random(in: 0..<twoPi, using: &rng)
                let speed: Double = Double.random(in: 120...340, using: &rng)
                let radius: Double = 2.0 + Double.random(in: 0...2.5, using: &rng)
                let delay: Double = Double(i % 4) * 0.03
                let life: Double = max(0, age - delay)
                let distance: Double = speed * life - 180 * life * life
                let gravity: Double = 220 * life * life
                let x: Double = centerX + cos(angle) * distance
                let y: Double = centerY + sin(angle) * distance + gravity
                let alpha: Double = max(0, 1 - life / 0.8)
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                let color = Self.sparkColor(index: i)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }

    private static func sparkColor(index: Int) -> Color {
        switch index % 3 {
        case 0: return .white
        case 1: return Theme.volt
        default: return Color(red: 1.0, green: 0.55, blue: 0.2)
        }
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
                    Text("こげた… ちょっと休ませて")
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
