import Foundation

/// Bundle 内のフォルダ参照 `content/lessons` から教材テキストを読む。
enum LessonLibrary {
    enum LoadError: LocalizedError {
        case directoryNotFound
        case fileNotFound(String)

        var errorDescription: String? {
            switch self {
            case .directoryNotFound:
                return "content/lessons がアプリに含まれていません。"
            case .fileNotFound(let unitId):
                return "\(unitId).md が見つかりません。"
            }
        }
    }

    /// content/lessons にある単元ファイルを単元ID順に返す。README は除く。
    static func lessonFiles() throws -> [URL] {
        guard let directory = ContentFiles.lessonsDirectory() else { throw LoadError.directoryNotFound }
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .filter { $0.deletingPathExtension().lastPathComponent.uppercased() != "README" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func loadAll() throws -> [Lesson] {
        try lessonFiles().map { try load(at: $0) }
    }

    static func load(unitId: String) throws -> Lesson {
        guard let url = try lessonFiles().first(
            where: { $0.deletingPathExtension().lastPathComponent == unitId }
        ) else {
            throw LoadError.fileNotFound(unitId)
        }
        return try load(at: url)
    }

    static func load(at url: URL) throws -> Lesson {
        let markdown = try String(contentsOf: url, encoding: .utf8)
        return LessonParser.parse(markdown, fallbackUnitId: url.deletingPathExtension().lastPathComponent)
    }
}
