import Foundation

/// 単元の最後に現れるボス。二つ名は登場時と図鑑だけで見せ、戦闘中は名前だけを出す。
struct Boss: Identifiable, Hashable {
    enum Rank: Int, Hashable {
        /// 区間の前の単元に出る先鋒（13〜24 番）
        case scout
        /// 区間の前半を守る中ボス
        case vanguard
        /// ステージの締めに出るステージボス
        case guardian
        /// 最後に待ち構える最上位種
        case last

        var label: String {
            switch self {
            case .scout: return "先鋒"
            case .vanguard: return "中ボス"
            case .guardian: return "ステージボス"
            case .last: return "最終ボス"
            }
        }
    }

    /// 画像と記録のキー。1〜24（1〜12 が最初の 12 体、13〜24 が各区間の先鋒）。
    let number: Int
    /// 二つ名。「雷獄竜」など。登場演出と図鑑にだけ出す。
    let epithet: String
    /// 名前。「ヴォルグレイヴ」など。戦闘中はこれだけを出す。
    let name: String
    let stage: Int
    let rank: Rank
    /// このボスが最後に出てくる単元。旧ドリル単元（u01 など）も含む。
    let unitIds: [String]
    /// 登場時の一言。
    let cry: String
    /// 図鑑の解説。
    let lore: String

    var id: String { String(format: "boss%02d", number) }
    /// Assets の imageset 名（Boss01〜Boss24）。
    var imageName: String { String(format: "Boss%02d", number) }
    /// 二つ名と名前をつなげた表記。図鑑と登場演出で使う。
    var fullName: String { epithet + name }
}

/// 24 体のボスと、どの単元に出るかの対応表。
/// ステージを前半・後半に分けた 12 の区間に 2 体ずつ。区間の前の単元には先鋒（13〜24 番）、
/// 後の単元には最初の 12 体が出る。並び順がそのまま図鑑の順になる。
enum BossRoster {
    static let all: [Boss] = [
        // ステージ 0 前半
        Boss(number: 13, epithet: "火花小鬼", name: "チッパ", stage: 0, rank: .scout,
             unitIds: ["F01", "F02", "F03"],
             cry: "ビリッとするぞ。単位を間違えたらな。",
             lore: "電気を学び始めた者の前に最初に現れる、小さな雷の鬼。電流・電圧・抵抗の区別や単位の換算があいまいな者に、静電気のようないたずらを仕掛けてくる。"),
        Boss(number: 1, epithet: "黒雷狼", name: "ガルヴォス", stage: 0, rank: .vanguard,
             unitIds: ["F04", "F05", "F06", "u01_basics_review"],
             cry: "その反応の遅さでは、電気は追えん。",
             lore: "獣のような俊敏さと青白い雷を持つ狼型。電気の基礎をなぞっただけの者に、まず最初の牙をむく。速く正確に答える者だけが振り切れる。"),
        // ステージ 0 後半
        Boss(number: 14, epithet: "吸電蛭", name: "リーチェル", stage: 0, rank: .scout,
             unitIds: ["F07", "F08", "F09"],
             cry: "線が長いほど、たっぷり吸えるのさ。",
             lore: "長い電線に吸いつき、少しずつ電圧を吸い取る大蛭。往復の 2 本分を数え忘れる者の回路は、末端にたどり着く前に力尽きる。"),
        Boss(number: 2, epithet: "電核獣", name: "ネクサル", stage: 0, rank: .guardian,
             unitIds: ["F10", "F11", "F12", "u02_circuits_review"],
             cry: "この核が尽きぬかぎり、放電は終わらん。",
             lore: "胸部の巨大な電気核から無限に放電する怪物。電力と回路の基礎を身につけていないと、押し切られて終わる。"),
        // ステージ 1 前半
        Boss(number: 15, epithet: "擬記獣", name: "ミミクロス", stage: 1, rank: .scout,
             unitIds: ["S01", "S02"],
             cry: "この丸、本当に照明か？",
             lore: "図記号そっくりに姿を変えて配線図に紛れ込む獣。傍記の一文字を読み飛ばす者は、コンセントとスイッチの区別すらつかなくなる。"),
        Boss(number: 3, epithet: "磁界巨獣", name: "マグナロア", stage: 1, rank: .vanguard,
             unitIds: ["S03", "S04", "u03_symbols", "u04_materials_tools"],
             cry: "貴様の工具ごと、引き寄せてくれる。",
             lore: "強力な磁場で鉄塊や瓦礫を操る巨獣。図記号と工具・材料の名前があやふやな者は、自分の道具を奪われる。"),
        // ステージ 1 後半
        Boss(number: 16, epithet: "絶縁甲虫", name: "シースガルド", stage: 1, rank: .scout,
             unitIds: ["S05", "S06"],
             cry: "我が外装、むけるものならむいてみよ。",
             lore: "何層もの被覆とシースをまとった甲虫。電線とケーブルの違い、電線管と材料の名前を知らない者の攻撃は、すべて外装にはじかれる。"),
        Boss(number: 4, epithet: "雷蛇帝", name: "ヴァルザーン", stage: 1, rank: .guardian,
             unitIds: ["S07", "S08", "u05_devices"],
             cry: "我が身は長く、どこまでも絡みつく。",
             lore: "長大な身体から雷を放つ蛇型怪物。電線と器具の知識をつなぎ切れない者は、その胴に巻き取られる。"),
        // ステージ 2 前半
        Boss(number: 17, epithet: "迷線蜘蛛", name: "ラビリンテ", stage: 2, rank: .scout,
             unitIds: ["W01", "W02"],
             cry: "どの線がどこへ続くか、たどれるか？",
             lore: "配線図の上に糸のような電線を張りめぐらせる蜘蛛。回路の番号を追えない者を、線の迷路に閉じこめる。"),
        Boss(number: 5, epithet: "雷翼獣", name: "ゼファルト", stage: 2, rank: .vanguard,
             unitIds: ["W03"],
             cry: "空の配線は、地を這う者には読めまい。",
             lore: "翼そのものが巨大な放電器官になっている飛行怪物。配線図を上から見下ろし、読み違えた者を撃ち落とす。"),
        // ステージ 2 後半
        Boss(number: 18, epithet: "結線蛸", name: "オクトリンク", stage: 2, rank: .scout,
             unitIds: ["W04"],
             cry: "この箱の中、何本つないだか数えてみろ。",
             lore: "八本の腕で電線を束ね、ジョイントボックスの中に潜む大蛸。リングスリーブと差込形コネクタの数を数え違えた者を絡め取る。"),
        Boss(number: 6, epithet: "雷獄竜", name: "ヴォルグレイヴ", stage: 2, rank: .guardian,
             unitIds: ["W05", "W06", "u15_wiring_diagram"],
             cry: "複線図の檻から、出られると思うな。",
             lore: "黒い甲殻に赤雷を纏う巨大竜。複線図を最後まで描き切れる者だけが、その甲殻に傷をつけられる。"),
        // ステージ 3 前半
        Boss(number: 19, epithet: "漏電霊", name: "リーカー", stage: 3, rank: .scout,
             unitIds: ["K01", "K02", "K03"],
             cry: "アースのない箱は、居心地がいい。",
             lore: "絶縁の傷からしみ出した電気が形になった亡霊。接地を省いた金属の外箱にとりつき、触れた者を感電させる。"),
        Boss(number: 7, epithet: "電蝕魔", name: "ゼルク", stage: 3, rank: .vanguard,
             unitIds: ["K04", "K05", "K06", "u06_installation"],
             cry: "その施工、内側から錆びていくぞ。",
             lore: "電気で周囲の金属を腐食させる異形。施工方法の原則を守らない工事から先に崩していく。"),
        // ステージ 3 後半
        Boss(number: 20, epithet: "計器妖", name: "メグリス", stage: 3, rank: .scout,
             unitIds: ["K07"],
             cry: "その値、本当に基準を満たしているか？",
             lore: "絶縁抵抗計の針に宿る妖。測定の手順と基準値をあいまいにする者の前で、針をでたらめに振らせる。"),
        Boss(number: 8, epithet: "紅雷鬼", name: "ヴァルグ", stage: 3, rank: .guardian,
             unitIds: ["K08", "K09", "u07_inspection", "u08_laws"],
             cry: "規則を知らぬ者に、通す道はない。",
             lore: "真紅の電撃を纏った人型の怪物。検査の数値と法令の条文をごまかす者を、容赦なく打ち据える。"),
        // ステージ 4 前半
        Boss(number: 21, epithet: "波動蛇", name: "サイヌス", stage: 4, rank: .scout,
             unitIds: ["E01", "E02", "u09_ohm_circuits", "u10_power_energy"],
             cry: "山と谷、どちらが本当の姿だ？",
             lore: "正弦波の形にうねりながら進む大蛇。最大値と実効値、電流の遅れと進みを取り違えた者を、波の谷底へ落とす。"),
        Boss(number: 9, epithet: "蒼雷鯨", name: "アズール", stage: 4, rank: .vanguard,
             unitIds: ["E03", "E04", "u11_ac_basics", "u12_three_phase"],
             cry: "交流の波に、飲まれてみるか。",
             lore: "空を海のように泳ぎ、雷雲を発生させる巨大生物。電気理論の計算が遅い者は、波に飲まれて時間を失う。"),
        // ステージ 4 後半
        Boss(number: 22, epithet: "断線獣", name: "ニュートロス", stage: 4, rank: .scout,
             unitIds: ["D01", "D02", "D03", "u13_distribution"],
             cry: "真ん中の一本を切れば、どうなると思う？",
             lore: "単相 3 線式の中性線をかみ切る獣。断線したとき負荷の電圧がどう変わるかを知らない者の家電を、次々に焼いていく。"),
        Boss(number: 10, epithet: "轟天獣", name: "グランボルト", stage: 4, rank: .guardian,
             unitIds: ["D04", "D05", "D06", "u14_wiring_design"],
             cry: "この雷雲、そのまま幹線に落としてやろう。",
             lore: "雷雲を背負う四足の超大型獣。電圧降下と幹線設計を数字で押さえた者だけが、落雷の前に立てる。"),
        // ステージ 5 前半
        Boss(number: 23, epithet: "複写鬼", name: "ツインレイ", stage: 5, rank: .scout,
             unitIds: ["G01", "G02"],
             cry: "一本の線は、本当は何本だ？",
             lore: "単線図を見ると、二本、三本と線を増やして写し取る鬼。接地側と非接地側を取り違えた複線図を見抜いて笑う。"),
        Boss(number: 11, epithet: "稲妻喰らい", name: "グラドーン", stage: 5, rank: .vanguard,
             unitIds: ["G03"],
             cry: "喰らうほどに、我は大きくなる。",
             lore: "雷を吸収するほど身体が巨大化する捕食者。手が止まるたびに力を蓄えるため、手早く仕留めるしかない。"),
        // ステージ 5 後半
        Boss(number: 24, epithet: "欠陥王", name: "ディフェクタ", stage: 5, rank: .scout,
             unitIds: ["G04"],
             cry: "その圧着、刻印は合っているか？",
             lore: "被覆の傷、心線の露出、刻印の間違い。一発で不合格になる欠陥を集めて身にまとう王。ひとつでも見落とせば、その場で試験は終わる。"),
        Boss(number: 12, epithet: "終雷獣", name: "アークヴェイン", stage: 5, rank: .last,
             unitIds: ["G05", "u16_practice_problems"],
             cry: "ここまで来たか。ならば、全ての雷を束ねよう。",
             lore: "周囲の雷を束ね、一撃で都市規模の電撃を放つ最上位種。すべての単元を修めた者の前にだけ姿を現す。"),
    ]

    private static let byUnit: [String: Boss] = {
        var map: [String: Boss] = [:]
        for boss in all {
            for unitId in boss.unitIds { map[unitId] = boss }
        }
        return map
    }()

    /// この単元の最後に出てくるボス。対応表にない単元は nil。
    static func boss(forUnit unitId: String) -> Boss? {
        byUnit[unitId]
    }

    static func boss(id: String) -> Boss? {
        all.first { $0.id == id }
    }

    /// 図鑑の並び順（ステージ順＝名簿順）。
    static var ordered: [Boss] { all }
}

/// ボス図鑑の記録。撃破回数・最速タイム・最大コンボを保存する。
enum BossCollection {
    struct Record {
        var defeats = 0
        var bestTime: Double?
        var maxCombo = 0
        var maxHit = 0
        var firstDefeatedAt: Date?

        var isDefeated: Bool { defeats > 0 }
    }

    private static let defaults = UserDefaults.standard

    private static func key(_ bossId: String, _ field: String) -> String {
        "bossdex.\(bossId).\(field)"
    }

    static func record(for bossId: String) -> Record {
        var record = Record()
        record.defeats = defaults.integer(forKey: key(bossId, "defeats"))
        let time = defaults.double(forKey: key(bossId, "bestTime"))
        record.bestTime = time > 0 ? time : nil
        record.maxCombo = defaults.integer(forKey: key(bossId, "maxCombo"))
        record.maxHit = defaults.integer(forKey: key(bossId, "maxHit"))
        let first = defaults.double(forKey: key(bossId, "firstDefeatedAt"))
        record.firstDefeatedAt = first > 0 ? Date(timeIntervalSince1970: first) : nil
        return record
    }

    static func registerDefeat(bossId: String, time: Double, combo: Int, hit: Int) {
        var record = self.record(for: bossId)
        record.defeats += 1
        if let best = record.bestTime {
            if time < best { record.bestTime = time }
        } else {
            record.bestTime = time
        }
        record.maxCombo = max(record.maxCombo, combo)
        record.maxHit = max(record.maxHit, hit)
        if record.firstDefeatedAt == nil { record.firstDefeatedAt = Date() }

        defaults.set(record.defeats, forKey: key(bossId, "defeats"))
        defaults.set(record.bestTime ?? 0, forKey: key(bossId, "bestTime"))
        defaults.set(record.maxCombo, forKey: key(bossId, "maxCombo"))
        defaults.set(record.maxHit, forKey: key(bossId, "maxHit"))
        defaults.set(record.firstDefeatedAt?.timeIntervalSince1970 ?? 0, forKey: key(bossId, "firstDefeatedAt"))
    }

    /// 撃破済みの体数。
    static var defeatedCount: Int {
        BossRoster.all.filter { record(for: $0.id).isDefeated }.count
    }

    static var total: Int { BossRoster.all.count }
}
