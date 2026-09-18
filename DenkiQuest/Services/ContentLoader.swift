import Foundation

enum ContentLoaderError: LocalizedError {
    case unitsFolderMissing

    var errorDescription: String? {
        switch self {
        case .unitsFolderMissing:
            return "教材フォルダ（content/units）がアプリに含まれていません。"
        }
    }
}

/// 旧形式（schemaVersion なし）の単元 JSON を読み込む。新形式は QuestionBank が読む。
enum ContentLoader {
    static func loadUnits(bundle: Bundle = .main) throws -> [LearningUnit] {
        guard ContentFiles.unitsDirectory(bundle: bundle) != nil else {
            throw ContentLoaderError.unitsFolderMissing
        }

        let decoder = JSONDecoder()
        var units: [LearningUnit] = []
        for url in ContentFiles.unitFileURLs(bundle: bundle) where ContentFiles.schemaVersion(of: url) == 1 {
            do {
                let data = try Data(contentsOf: url)
                units.append(try decoder.decode(LearningUnit.self, from: data))
            } catch {
                // 1 ファイルの不備で全体を止めない
                print("ContentLoader: \(url.lastPathComponent) を読めません: \(error)")
            }
        }
        return units.sorted { $0.order < $1.order }
    }
}
