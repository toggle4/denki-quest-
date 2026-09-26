import Foundation

/// 四則演算・比較・sqrt/pow などを評価する小さな式評価器。
/// template 問題の answerFormula / constraints / distractors に使う。
struct ExpressionEvaluator {
    enum EvalError: Error {
        case syntax(String)
        case unknownIdentifier(String)
    }

    let variables: [String: Double]

    func evaluate(_ text: String) throws -> Double {
        var parser = Parser(text: text, variables: variables)
        let value = try parser.parseComparison()
        try parser.expectEnd()
        return value
    }

    // MARK: - 再帰下降パーサ

    private struct Parser {
        private let chars: [Character]
        private var pos = 0
        private let variables: [String: Double]

        init(text: String, variables: [String: Double]) {
            chars = Array(text)
            self.variables = variables
        }

        private mutating func skipSpaces() {
            while pos < chars.count, chars[pos] == " " || chars[pos] == "\t" {
                pos += 1
            }
        }

        private mutating func match(_ token: String) -> Bool {
            skipSpaces()
            let t = Array(token)
            guard pos + t.count <= chars.count else { return false }
            for (i, c) in t.enumerated() where chars[pos + i] != c {
                return false
            }
            pos += t.count
            return true
        }

        mutating func expectEnd() throws {
            skipSpaces()
            if pos < chars.count {
                throw EvalError.syntax("余分な文字: \(String(chars[pos...]))")
            }
        }

        mutating func parseComparison() throws -> Double {
            let left = try parseAdditive()
            for op in ["==", "!=", "<=", ">=", "<", ">"] {
                if match(op) {
                    let right = try parseAdditive()
                    return Self.compare(op, left, right) ? 1 : 0
                }
            }
            return left
        }

        private static func compare(_ op: String, _ a: Double, _ b: Double) -> Bool {
            let eps = 1e-9
            switch op {
            case "==": return abs(a - b) < eps
            case "!=": return abs(a - b) >= eps
            case "<=": return a <= b + eps
            case ">=": return a >= b - eps
            case "<": return a < b - eps
            default: return a > b + eps
            }
        }

        private mutating func parseAdditive() throws -> Double {
            var value = try parseTerm()
            while true {
                if match("+") {
                    let rhs = try parseTerm()
                    value += rhs
                } else if match("-") {
                    let rhs = try parseTerm()
                    value -= rhs
                } else {
                    return value
                }
            }
        }

        private mutating func parseTerm() throws -> Double {
            var value = try parseUnary()
            while true {
                if match("*") {
                    let rhs = try parseUnary()
                    value *= rhs
                } else if match("/") {
                    let rhs = try parseUnary()
                    value /= rhs
                } else if match("%") {
                    let rhs = try parseUnary()
                    value = fmod(value, rhs)
                } else {
                    return value
                }
            }
        }

        private mutating func parseUnary() throws -> Double {
            if match("-") {
                let value = try parseUnary()
                return -value
            }
            if match("+") {
                return try parseUnary()
            }
            return try parsePrimary()
        }

        private mutating func parsePrimary() throws -> Double {
            if match("(") {
                let value = try parseComparison()
                guard match(")") else { throw EvalError.syntax(") がない") }
                return value
            }
            skipSpaces()
            guard pos < chars.count else { throw EvalError.syntax("式が途中で終わっている") }
            let c = chars[pos]
            if c.isNumber || c == "." {
                return try parseNumber()
            }
            if c.isLetter || c == "_" {
                return try parseIdentifier()
            }
            throw EvalError.syntax("読めない文字: \(c)")
        }

        private mutating func parseNumber() throws -> Double {
            var text = ""
            while pos < chars.count, chars[pos].isNumber || chars[pos] == "." {
                text.append(chars[pos])
                pos += 1
            }
            guard let value = Double(text) else { throw EvalError.syntax("数値でない: \(text)") }
            return value
        }

        private mutating func parseIdentifier() throws -> Double {
            var name = ""
            while pos < chars.count, chars[pos].isLetter || chars[pos].isNumber || chars[pos] == "_" {
                name.append(chars[pos])
                pos += 1
            }
            if match("(") {
                var args: [Double] = []
                if !match(")") {
                    repeat {
                        let value = try parseComparison()
                        args.append(value)
                    } while match(",")
                    guard match(")") else { throw EvalError.syntax(") がない") }
                }
                return try Self.call(name, args)
            }
            switch name {
            case "SQRT2": return 2.0.squareRoot()
            case "SQRT3": return 3.0.squareRoot()
            case "PI": return Double.pi
            default: break
            }
            guard let value = variables[name] else { throw EvalError.unknownIdentifier(name) }
            return value
        }

        private static func call(_ name: String, _ args: [Double]) throws -> Double {
            switch (name, args.count) {
            case ("sqrt", 1): return args[0].squareRoot()
            case ("pow", 2): return pow(args[0], args[1])
            case ("abs", 1): return abs(args[0])
            case ("round", 1): return args[0].rounded()
            case ("floor", 1): return args[0].rounded(.down)
            case ("ceil", 1): return args[0].rounded(.up)
            case ("min", 2): return Swift.min(args[0], args[1])
            case ("max", 2): return Swift.max(args[0], args[1])
            default: throw EvalError.unknownIdentifier("\(name)(\(args.count) 引数)")
            }
        }
    }
}

/// template 問題の数値生成と文字列の埋め込み。
enum TemplateEngine {
    struct Instance {
        let values: [String: Double]
        let answer: Double
    }

    /// 変数をランダムに決め、constraints を満たす組を answerFormula で評価する。
    static func generate(_ question: QuestionV2) -> Instance? {
        guard let variables = question.variables, let formula = question.answerFormula else { return nil }
        let constraints = question.constraints ?? []

        for _ in 0..<300 {
            var values: [String: Double] = [:]
            for (name, spec) in variables {
                values[name] = randomValue(spec)
            }
            // 途中の値を順に計算する（問題文・解説で途中の数字を見せるため）
            var derivedOK = true
            for spec in question.derived ?? [] {
                guard var value = try? ExpressionEvaluator(variables: values).evaluate(spec.formula), value.isFinite else {
                    derivedOK = false
                    break
                }
                if let digits = spec.roundTo {
                    let scale = pow(10.0, Double(digits))
                    value = (value * scale).rounded() / scale
                }
                values[spec.name] = value
            }
            guard derivedOK else { continue }
            let evaluator = ExpressionEvaluator(variables: values)
            let satisfied = constraints.allSatisfy { constraint in
                let result = (try? evaluator.evaluate(constraint)) ?? 0
                return result != 0
            }
            guard satisfied,
                  let answer = try? evaluator.evaluate(formula),
                  answer.isFinite else { continue }
            return Instance(values: values, answer: answer)
        }
        return nil
    }

    static func randomValue(_ spec: VariableSpec) -> Double {
        let step = (spec.step ?? 1) > 0 ? (spec.step ?? 1) : 1
        let count = Swift.max(0, Int(((spec.max - spec.min) / step).rounded(.down)))
        let k = Int.random(in: 0...count)
        let raw = spec.min + Double(k) * step
        return (raw * 1_000_000).rounded() / 1_000_000
    }

    /// 表示用の数値文字列。roundTo があればその桁数で丸め、末尾の 0 は落とす。
    static func format(_ value: Double, roundTo: Int?) -> String {
        if let roundTo, roundTo <= 0 {
            return String(Int(value.rounded()))
        }
        let digits = roundTo ?? 4
        let text = String(format: "%.\(digits)f", value)
        return trimZeros(text)
    }

    static func trimZeros(_ text: String) -> String {
        guard text.contains(".") else { return text }
        var t = text
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        if t == "-0" { return "0" }
        return t
    }

    /// `{V}` `{answer}` を埋め込む。
    static func substitute(_ text: String, values: [String: Double], answer: String) -> String {
        var result = text
        for (name, value) in values {
            result = result.replacingOccurrences(of: "{\(name)}", with: format(value, roundTo: nil))
        }
        return result.replacingOccurrences(of: "{answer}", with: answer)
    }
}
