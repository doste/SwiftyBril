import Foundation

public func openFile(filePath fileURL: URL) -> Data? {
    if #available(macOS 13.0, *) {
        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)

            if let data = try fileHandle.readToEnd() {
                return data
            }
            fileHandle.closeFile()
        } catch {
            print(error)
        }
    }
    return nil
}
