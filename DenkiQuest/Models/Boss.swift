import Foundation

/// 単元の最後に現れるボス。二つ名は登場時と図鑑だけで見せ、戦闘中は名前だけを出す。
struct Boss: Identifiable, Hashable {
    enum Rank: Int, Hashable {
        /// 区間の前半を守る中ボス
        case vanguard
        /// ステージの締めに出るステージボス
        case guardian
        /// 最後に待ち構える最上位種
        case last

        var label: String {
            switch self {
            case .vanguard: return "中ボス"
            case .guardian: return "ステージボス"
            case .last: return "最終ボス"
            }
        }
    }

    /// 画像と記録のキー。1〜12。
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
    /// Assets の imageset 名（Boss01〜Boss12）。
    var imageName: String { String(format: "Boss%02d", number) }
    /// 二つ名と名前をつなげた表記。図鑑と登場演出で使う。
    var fullName: String { epithet + name }
}

/// 12 体のボスと、どの単元に出るかの対応表。
enum BossRoster {
    static let all: [Boss] = [
        Boss(number: 1, epithet: "黒雷狼", name: "ガルヴォス", stage: 0, rank: .vanguard,
             unitIds: ["F01", "F02", "F03", "F04", "F05", "F06", "u01_basics_review"],
             cry: "その反応の遅さでは、電気は追えん。",
             lore: "獣のような俊敏さと青白い雷を持つ狼型。電気の基礎をなぞっただけの者に、まず最初の牙をむく。速く正確に答える者だけが振り切れる。"),
        Boss(number: 2, epithet: "電核獣", name: "ネクサル", stage: 0, rank: .guardian,
             unitIds: ["F07", "F08", "F09", "F10", "F11", "F12", "u02_circuits_review"],
             cry: "この核が尽きぬかぎり、放電は終わらん。",
             lore: "胸部の巨大な電気核から無限に放電する怪物。電力と回路の基礎を身につけていないと、押し切られて終わる。"),
        Boss(number: 3, epithet: "磁界巨獣", name: "マグナロア", stage: 1, rank: .vanguard,
             unitIds: ["S01", "S02", "S03", "S04", "u03_symbols", "u04_materials_tools"],
             cry: "貴様の工具ごと、引き寄せてくれる。",
             lore: "強力な磁場で鉄塊や瓦礫を操る巨獣。図記号と工具・材料の名前があやふやな者は、自分の道具を奪われる。"),
        Boss(number: 4, epithet: "雷蛇帝", name: "ヴァルザーン", stage: 1, rank: .guardian,
             unitIds: ["S05", "S06", "S07", "S08", "u05_devices"],
             cry: "我が身は長く、どこまでも絡みつく。",
             lore: "長大な身体から雷を放つ蛇型怪物。電線と器具の知識をつなぎ切れない者は、その胴に巻き取られる。"),
        Boss(number: 5, epithet: "雷翼獣", name: "ゼファルト", stage: 2, rank: .vanguard,
             unitIds: ["W01", "W02", "W03"],
             cry: "空の配線は、地を這う者には読めまい。",
             lore: "翼そのものが巨大な放電器官になっている飛行怪物。配線図を上から見下ろし、読み違えた者を撃ち落とす。"),
        Boss(number: 6, epithet: "雷獄竜", name: "ヴォルグレイヴ", stage: 2, rank: .guardian,
             unitIds: ["W04", "W05", "W06", "u15_wiring_diagram"],
             cry: "複線図の檻から、出られると思うな。",
             lore: "黒い甲殻に赤雷を纏う巨大竜。複線図を最後まで描き切れる者だけが、その甲殻に傷をつけられる。"),
        Boss(number: 7, epithet: "電蝕魔", name: "ゼルク", stage: 3, rank: .vanguard,
             unitIds: ["K01", "K02", "K03", "K04", "K05", "K06", "u06_installation"],
             cry: "その施工、内側から錆びていくぞ。",
             lore: "電気で周囲の金属を腐食させる異形。施工方法の原則を守らない工事から先に崩していく。"),
        Boss(number: 8, epithet: "紅雷鬼", name: "ヴァルグ", stage: 3, rank: .guardian,
             unitIds: ["K07", "K08", "K09", "u07_inspection", "u08_laws"],
             cry: "規則を知らぬ者に、通す道はない。",
             lore: "真紅の電撃を纏った人型の怪物。検査の数値と法令の条文をごまかす者を、容赦なく打ち据える。"),
        Boss(number: 9, epithet: "蒼雷鯨", name: "アズール", stage: 4, rank: .vanguard,
             unitIds: ["E01", "E02", "E03", "E04",
                       "u09_ohm_circuits", "u10_power_energy", "u11_ac_basics", "u12_three_phase"],
             cry: "交流の波に、飲まれてみるか。",
             lore: "空を海のように泳ぎ、雷雲を発生させる巨大生物。電気理論の計算が遅い者は、波に飲まれて時間を失う。"),
        Boss(number: 10, epithet: "轟天獣", name: "グランボルト", stage: 4, rank: .guardian,
             unitIds: ["D01", "D02", "D03", "D04", "D05", "D06",
                       "u13_distribution", "u14_wiring_design"],
             cry: "この雷雲、そのまま幹線に落としてやろう。",
             lore: "雷雲を背負う四足の超大型獣。電圧降下と幹線設計を数字で押さえた者だけが、落雷の前に立てる。"),
        Boss(number: 11, epithet: "稲妻喰らい", name: "グラドーン", stage: 5, rank: .vanguard,
             unitIds: ["G01", "G02", "G03"],
             cry: "喰らうほどに、我は大きくなる。",
             lore: "雷を吸収するほど身体が巨大化する捕食者。手が止まるたびに力を蓄えるため、手早く仕留めるしかない。"),
        Boss(number: 12, epithet: "終雷獣", name: "アークヴェイン", stage: 5, rank: .last,
             unitIds: ["G04", "G05", "u16_practice_problems"],
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
