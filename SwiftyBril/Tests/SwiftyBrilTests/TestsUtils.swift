import Foundation
import SwiftyBril


public struct BrilProgramToTest {
    let name: String
    let path: URL
    let outputToComparePath: URL
}

func removeExtension(from fileName: String) -> String {
    let components = fileName.split(separator: ".")
    return String(components.dropLast().joined(separator: "."))
}

func getFileName(from path: URL) -> String {
    let components = path.absoluteString.split(separator: "/")
    if let last = components.last {
        return removeExtension(from: String(last))
    }
    return ""
}

// Given "/path/to/input_program.json" returns "/path/to/input_program.out"
func getFilePathForOutputFileToCompare(from inputFilePath: URL) -> URL {
    return inputFilePath.deletingPathExtension().appendingPathExtension("out")
}
