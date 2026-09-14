import Foundation

enum ContentLoaderError: LocalizedError {
    case unitsFolderMissing

    var errorDescription: String? {
        switch self {
        case .unitsFolderMissing:
            return "教材フォルダ（units）がアプリに含まれていません。"
        }
    }
}

/// アプリにバンドルされた `units/` フォルダから単元 JSON を読み込む。
enum ContentLoader {
    static func loadUnits(bundle: Bundle = .main) throws -> [LearningUnit] {
        guard let folderURL = bundle.url(forResource: "units", withExtension: nil) else {
            throw ContentLoaderError.unitsFolderMissing
        }

        let fileURLs = try FileManager.default
            .contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "json" }

        let decoder = JSONDecoder()
        let units = try fileURLs.map { url -> LearningUnit in
            let data = try Data(contentsOf: url)
            return try decoder.decode(LearningUnit.self, from: data)
        }
        return units.sorted { $0.order < $1.order }
    }
}
