import SwiftUI

/// 数値をなめらかにカウントアップするテキスト。
struct AnimatedNumberText: View, Animatable {
    var value: Double
    var fractionDigits = 1

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(String(format: "%.\(fractionDigits)f", value))
            .monospacedDigit()
    }
}

/// 200 時間ゲージ。ホーム画面の主役。
struct StudyGaugeView: View {
    let stats: StudyStats

    @State private var appeared = false
    @State private var hue: Double = 0
    @State private var shimmer: CGFloat = 0
    @State private var pulse = false

    private var hours: Double { stats.totalHours }
    private var ratio: Double { hours / StudyGoal.targetHours }
    private var isOverGoal: Bool { hours >= StudyGoal.targetHours }
    private var isOverSafe: Bool { hours >= StudyGoal.safeHours }

    private var phaseColors: [Color] {
        if isOverGoal { return [Theme.volt, Color(red: 1.0, green: 0.95, blue: 0.6), Theme.volt] }
        if isOverSafe { return [Theme.volt, Theme.correct] }
        return [Color(red: 0.35, green: 0.65, blue: 1.0), Theme.volt]
    }

    private var statusText: String {
        if isOverGoal {
            return "目標達成！ここからは伝説の領域"
        }
        if isOverSafe {
            let remain = StudyGoal.targetHours - hours
            return "安心ライン突破！目標まで あと \(String(format: "%.1f", remain)) 時間"
        }
        let remain = StudyGoal.safeHours - hours
        return "安心ラインまで あと \(String(format: "%.1f", remain)) 時間"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            titleRow
            numberRow
            bar
                .frame(height: 44)
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOverGoal ? Theme.volt : Theme.textSecondary)
            footerRow
        }
        .padding(18)
        .gameCard(
            tint: isOverGoal ? Theme.volt.opacity(0.08) : .clear,
            border: isOverGoal ? Theme.volt.opacity(0.6) : Theme.cardBorder
        )
        .shadow(color: isOverGoal ? Theme.volt.opacity(pulse ? 0.45 : 0.15) : .clear, radius: pulse ? 26 : 12)
        .onAppear {
            withAnimation(.spring(response: 1.4, dampingFraction: 0.85).delay(0.15)) {
                appeared = true
            }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmer = 1
            }
            if isOverGoal {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    hue = 360
                }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }

    private var titleRow: some View {
        HStack {
            Label("学習時間", systemImage: "hourglass")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if stats.streakDays > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(stats.streakDays) 日連続")
                }
                .font(.caption.bold())
                .foregroundStyle(Theme.backgroundBottom)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 1.0, green: 0.55, blue: 0.25), in: Capsule())
            }
        }
    }

    private var numberRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            AnimatedNumberText(value: appeared ? hours : 0)
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(isOverGoal ? Theme.volt : Theme.textPrimary)
                .contentTransition(.numericText())
            Text("h")
                .font(.title2.bold())
                .foregroundStyle(Theme.textSecondary)
            Text("/ \(Int(StudyGoal.targetHours)) h")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let trackWidth = fullWidth * 0.84
            let barHeight: CGFloat = 20
            let fillWidth = (appeared ? min(ratio, 1) : 0) * trackWidth
            let overflowRaw = max(0, ratio - 1) * trackWidth * 0.5
            let overflowWidth = ratio > 1 ? min(max(overflowRaw, 14), fullWidth - trackWidth) : 0
            let safeX = (StudyGoal.safeHours / StudyGoal.targetHours) * trackWidth

            ZStack(alignment: .leading) {
                // 土台
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: trackWidth, height: barHeight)
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            .frame(width: trackWidth, height: barHeight)
                    )

                // 通常の伸び
                Capsule()
                    .fill(LinearGradient(colors: phaseColors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(fillWidth, 0), height: barHeight)
                    .overlay(shimmerOverlay(width: max(fillWidth, 0), height: barHeight))
                    .shadow(color: phaseColors.last!.opacity(0.5), radius: 8)

                // 200 h を超えた分: 枠からはみ出す虹色バー
                if isOverGoal && appeared {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .hueRotation(.degrees(hue))
                        .frame(width: overflowWidth + barHeight, height: barHeight + 6)
                        .offset(x: trackWidth - barHeight)
                        .shadow(color: .white.opacity(0.7), radius: 10)
                        .transition(.scale(scale: 0.2, anchor: .leading).combined(with: .opacity))
                    Image(systemName: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .white, radius: 4)
                        .offset(x: trackWidth + overflowWidth + 4, y: -2)
                        .transition(.opacity)
                }

                // 150 h 安心ライン
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(isOverSafe ? Theme.correct : Color.white.opacity(0.7))
                        .frame(width: 2, height: barHeight + 8)
                    Text(isOverSafe ? "安心 ✓" : "150h 安心")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isOverSafe ? Theme.correct : Theme.textSecondary)
                        .fixedSize()
                }
                .offset(x: safeX - 1, y: 6)

                // 200 h 目標
                VStack(spacing: 2) {
                    Image(systemName: isOverGoal ? "crown.fill" : "flag.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(isOverGoal ? Theme.volt : Theme.textSecondary)
                        .frame(height: barHeight + 8)
                    Text("200h 目標")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isOverGoal ? Theme.volt : Theme.textSecondary)
                        .fixedSize()
                }
                .offset(x: trackWidth - 6, y: 6)
            }
            .animation(.spring(response: 1.4, dampingFraction: 0.85), value: appeared)
        }
    }

    private func shimmerOverlay(width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.45), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 60, height: height)
        .offset(x: -60 + shimmer * (width + 120))
        .mask(Capsule().frame(width: width, height: height))
    }

    private var footerRow: some View {
        HStack(spacing: 16) {
            footerStat(icon: "sun.max.fill", label: "今日", value: StudyFormat.duration(stats.todaySeconds))
            footerStat(icon: "bolt.fill", label: "クエスト", value: "\(stats.sessionCount) 回")
            Spacer()
            HStack(spacing: 2) {
                Text("くわしく")
                Image(systemName: "chevron.right")
            }
            .font(.caption.bold())
            .foregroundStyle(Theme.volt)
        }
    }

    private func footerStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Theme.volt)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }
}
