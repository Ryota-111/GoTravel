import UIKit

extension FileManager {
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    static func saveImageDataToDocuments(data: Data, named fileName: String) throws {
        let url = documentsDirectory().appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)

        // 書き込めてから預ける。Pro を持っていなければ何もしない
        PhotoSyncService.shared.store(data: data, fileName: fileName, folder: .documents)
    }

    static func documentsImage(named fileName: String) -> UIImage? {
        let url = documentsDirectory().appendingPathComponent(fileName)

        // ファイルが無いときだけ、預けてあるものから書き戻す。
        // 機種変更の直後にしか通らない
        guard FileManager.default.fileExists(atPath: url.path)
                || PhotoSyncService.shared.restoreIfMissing(fileName: fileName, folder: .documents)
        else { return nil }

        return UIImage(contentsOfFile: url.path)
    }

    static func removeDocumentFile(named fileName: String) throws {
        let url = documentsDirectory().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        // ローカルに無くても預け先には在りうるので、必ず消しに行く
        PhotoSyncService.shared.remove(fileName: fileName, folder: .documents)
    }
}
