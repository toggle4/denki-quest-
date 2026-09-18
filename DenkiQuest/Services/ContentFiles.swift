import Foundation

/// Bundle にフォルダ参照で入っている content/ の場所と、JSON の新旧判別。
enum ContentFiles {
    static func contentDirectory(bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forResource: "content", withExtension: nil) {
            return url
        }
        guard let resources = bundle.resourceURL else { return nil }
        let fallback = resources.appendingPathComponent("content", isDirectory: true)
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    static func unitsDirectory(bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forResource: "units", withExtension: nil, subdirectory: "content") {
            return url
        }
        // 旧構成（content/units を直接フォルダ参照していた頃）との互換
        if let url = bundle.url(forResource: "units", withExtension: nil) {
            return url
        }
        return contentDirectory(bundle: bundle)?.appendingPathComponent("units", isDirectory: true)
    }

    static func lessonsDirectory(bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forResource: "lessons", withExtension: nil, subdirectory: "content") {
            return url
        }
        guard let dir = contentDirectory(bundle: bundle)?.appendingPathComponent("lessons", isDirectory: true),
              FileManager.default.fileExists(atPath: dir.path) else { return nil }
        return dir
    }

    static func unitFileURLs(bundle: Bundle = .main) -> [URL] {
        guard let dir = unitsDirectory(bundle: bundle),
              let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// `schemaVersion` キーがなければ旧形式（1）とみなす。
    static func schemaVersion(of url: URL) -> Int {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["schemaVersion"] as? Int else {
            return 1
        }
        return version
    }
}
