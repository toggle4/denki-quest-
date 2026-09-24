import SwiftUI

/// 長押しで充電し、6.6kV（6 秒）でショートするマスコット。
///
/// 押すとマスコットが指の上へ浮き上がり、指先から稲妻でつながる（指で絵が隠れない）。
/// 指がマスコットの外へずれても充電は続き、指を離したときだけ放電する。
/// ショート寸前で離すほど「ギリギリ記録」になる。
struct ChargeMascotView: View {
    let size: CGFloat
    /// ショートした瞬間に呼ばれる（画面全体のフラッシュなどに使う）
    var onShortCircuit: () -> Void = {}
    /// こげている間だけ true になる（ホーム画面の見た目を変えるのに使う）
    var onBurntChanged: (Bool) -> Void = { _ in }
    /// 充電中だけ true（画面のふちを光らせる・スクロールを止める）
    var onChargingChanged: (Bool) -> Void = { _ in }
    /// 危険域（75 % 以上）に入ると true（画面全体が震える）
    var onDangerChanged: (Bool) -> Void = { _ in }

    @State private var controller = ChargeController()
    @State private var isPressing = false
    @State private var releasePulse: CGFloat = 1.0
    /// 押している指の位置（このビューの座標）
    @State private var finger: CGPoint?
    @State private var popup: ChargeController.Discharge?
    @State private var popupVisible = false

    private var box: CGFloat { size * 1.9 }
    /// 指からの稲妻を枠の外まで描くための余白
    private var margin: CGFloat { size * 1.4 }

    var body: some View {
        TimelineView(.animation(paused: controller.phase == .idle)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let charge = controller.charge
            let phase = controller.phase
            let lift = liftAmount(charge: charge, phase: phase)

            ZStack {
                // 浮き上がる本体（光・稲妻・マスコット・煙・火花・電圧計）
                ZStack {
                    glow(charge: charge, phase: phase)
                    arcs(charge: charge, phase: phase, time: t)
                    mascot(charge: charge, phase: phase, time: t)
                    smoke(phase: phase, time: t)
                    sparks(phase: phase, now: context.date)
                }
                .overlay {
                    voltmeter(charge: charge, phase: phase, time: t)
                        .offset(x: size * 0.5 * mascotScale(charge: charge, phase: phase) + 62)
                }
                .offset(y: lift)
                .animation(.spring(response: 0.42, dampingFraction: phase == .cooldown ? 0.42 : 0.72), value: phase)

                caption(charge: charge, phase: phase)
            }
            .frame(width: box, height: box)
            .overlay {
                tether(charge: charge, phase: phase, time: t, lift: lift)
                    .frame(width: box + margin * 2, height: box + margin * 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: box, height: box)
        .overlay { dischargePopup }
        .contentShape(Rectangle())
        .gesture(
            // 距離で打ち切らない。指がどこへずれても、離すまで充電を続ける
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    finger = value.location
                    if !isPressing {
                        isPressing = true
                        controller.pressBegan()
                    }
                }
                .onEnded { _ in
                    finger = nil
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
        )
        .onChange(of: controller.phase) { old, phase in
            if phase == .shorted {
                onShortCircuit()
            }
            onBurntChanged(phase == .shorted || phase == .cooldown)
            if (old == .charging) != (phase == .charging) {
                onChargingChanged(phase == .charging)
            }
        }
        .onChange(of: controller.isDanger) { _, danger in
            onDangerChanged(danger)
        }
        .onChange(of: controller.lastDischarge) { _, result in
            guard let result else { return }
            popup = result
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { popupVisible = true }
            if result.isRecord || result.isClose {
                Haptics.heavy()
                SoundPlayer.shared.play(result.isRecord ? .perfect : .combo)
            }
            let id = result.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                guard popup?.id == id else { return }
                withAnimation(.easeOut(duration: 0.4)) { popupVisible = false }
            }
        }
        .accessibilityLabel("マスコット。長押しで充電。6.6キロボルトでショート。ショート寸前で離すと記録")
    }

    // MARK: - 浮き上がり・指からの稲妻・電圧計・結果

    /// 充電中は指より上へ浮かせる。ショートの瞬間も上のまま、休憩で落ちてくる。
    private func liftAmount(charge: Double, phase: ChargeController.Phase) -> CGFloat {
        switch phase {
        case .charging: return -size * (0.58 + 0.12 * CGFloat(charge))
        case .shorted: return -size * 0.7
        default: return 0
        }
    }

    /// 指先からマスコットへ走る稲妻。充電が進むほど太く、枝分かれが増える。
    private func tether(charge: Double, phase: ChargeController.Phase, time: Double, lift: CGFloat) -> some View {
        Canvas { context, canvasSize in
            guard phase == .charging, let finger else { return }
            let fade: Double = min(1.0, charge * 10)
            guard fade > 0.02 else { return }
            let m = Double(margin)
            let start = CGPoint(x: Double(finger.x) + m, y: Double(finger.y) + m)
            let cx = Double(canvasSize.width) / 2
            let cy = Double(canvasSize.height) / 2 + Double(lift) + Double(size) * 0.3
            let end = CGPoint(x: cx, y: cy)
            var rng = SeededGenerator(seed: UInt64(max(0, time) * 24))
            let strands = 1 + Int(charge * 3)
            let color: Color = charge > 0.85 ? .white : Theme.volt
            for k in 0..<strands {
                let path = Self.boltPath(from: start, to: end, jag: 0.18 + 0.05 * Double(k), rng: &rng)
                let width: Double = (k == 0 ? 2.0 : 1.2) + 2.5 * charge
                context.stroke(path, with: .color(color.opacity(0.9 * fade)), lineWidth: width)
                context.stroke(path, with: .color(color.opacity(0.28 * fade)), lineWidth: width * 4)
            }
            // 指先の光
            let r: Double = 9 + 12 * charge
            let rect = CGRect(x: Double(start.x) - r, y: Double(start.y) - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.35 * fade)))
            let core = CGRect(x: Double(start.x) - r * 0.4, y: Double(start.y) - r * 0.4, width: r * 0.8, height: r * 0.8)
            context.fill(Path(ellipseIn: core), with: .color(Color.white.opacity(0.9 * fade)))
        }
    }

    private static func boltPath(from a: CGPoint, to b: CGPoint, jag: Double, rng: inout SeededGenerator) -> Path {
        let ax = Double(a.x), ay = Double(a.y), bx = Double(b.x), by = Double(b.y)
        let dx = bx - ax, dy = by - ay
        let length = max(1.0, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / length, ny = dx / length
        var path = Path()
        path.move(to: a)
        let segments = 8
        for i in 1..<segments {
            let p = Double(i) / Double(segments)
            let wobble = Double.random(in: -1...1, using: &rng) * length * jag * sin(p * Double.pi)
            path.addLine(to: CGPoint(x: ax + dx * p + nx * wobble, y: ay + dy * p + ny * wobble))
        }
        path.addLine(to: b)
        return path
    }

    /// 回るゲージの代わりの電圧計。0 から 6.60kV まで数字が上がっていく。
    private func voltmeter(charge: Double, phase: ChargeController.Phase, time: Double) -> some View {
        let shorted = phase == .shorted
        let volts: Double = shorted ? ChargeController.shortVoltage : charge * ChargeController.shortVoltage
        let danger = shorted || charge >= ChargeController.dangerLevel
        let color: Color = shorted ? .white
            : (charge >= ChargeController.closeLevel ? Theme.wrong
               : (danger ? Color(red: 1.0, green: 0.55, blue: 0.2) : Theme.volt))
        let blink = danger && Int(time * 8) % 2 == 0
        let visible = phase == .charging || shorted
        return VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.2f", volts / 1000))
                    .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                Text("kV")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(color)
            Text(shorted ? "SHORT!" : (danger ? "DANGER" : "CHARGING"))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(danger ? Theme.wrong : Theme.textSecondary)
                .opacity(blink ? 0.35 : 1)
        }
        .shadow(color: color.opacity(0.7), radius: 8)
        .fixedSize()
        .frame(width: 120, alignment: .leading)
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: visible)
        .allowsHitTesting(false)
    }

    /// 途中で離したときの結果。ショート寸前ほど褒める。
    @ViewBuilder
    private var dischargePopup: some View {
        if let popup {
            VStack(spacing: 2) {
                if popup.isRecord {
                    Text("NEW RECORD!")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.backgroundBottom)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.volt, in: Capsule())
                } else if popup.isClose {
                    Text("ギリギリ！")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.wrong)
                }
                Text(String(format: "%.2fkV", popup.voltage / 1000))
                    .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(popup.isClose ? Theme.wrong : Theme.volt)
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
            .scaleEffect(popupVisible ? 1 : 0.5)
            .opacity(popupVisible ? 1 : 0)
            .offset(y: -size * 0.78 - (popupVisible ? 8 : 0))
            .allowsHitTesting(false)
        }
    }

    // MARK: - パーツ

    private func mascotScale(charge: Double, phase: ChargeController.Phase) -> CGFloat {
        switch phase {
        case .charging: return 1.05 + 0.3 * charge
        case .shorted: return 1.3
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

    private func showsCaption(_ phase: ChargeController.Phase) -> Bool {
        switch phase {
        case .cooldown: return true
        case .idle: return controller.bestVoltage > 0 && !popupVisible
        case .charging, .shorted: return false
        }
    }

    private func caption(charge: Double, phase: ChargeController.Phase) -> some View {
        VStack {
            Spacer()
            Group {
                switch phase {
                case .cooldown:
                    Text("こげた… ちょっと休ませて")
                        .foregroundStyle(Theme.textSecondary)
                case .idle:
                    if controller.bestVoltage > 0 {
                        Label(String(format: "ギリギリ記録 %.2fkV", controller.bestVoltage / 1000), systemImage: "bolt.fill")
                            .foregroundStyle(Theme.volt.opacity(0.85))
                    }
                case .charging, .shorted:
                    EmptyView()
                }
            }
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.35), in: Capsule())
            .opacity(showsCaption(phase) ? 1 : 0)
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
