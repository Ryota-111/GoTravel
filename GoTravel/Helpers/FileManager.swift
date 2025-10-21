import UIKit

extension FileManager {
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    static func saveImageDataToDocuments(data: Data, named fileName: String) throws {
        let url = documentsDirectory().appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
    }
    
    static func documentsImage(named fileName: String) -> UIImage? {
        let url = documentsDirectory().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    
    static func removeDocumentFile(named fileName: String) throws {
        let url = documentsDirectory().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
