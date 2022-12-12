import Foundation
import AppKit

NSApplication.shared.setActivationPolicy(.accessory)
let dialog = NSOpenPanel()
dialog.allowedFileTypes = allowedExtension
dialog.allowsMultipleSelection = true
dialog.canChooseDirectories = true
dialog.message = "Select a folder or wav or flac files"

guard dialog.runModal() == .OK else { exit(0) }
let inputURLs = dialog.urls
let inputURLPrefix: String = {
	guard inputURLs.count > 1 else {
		return inputURLs.first?.path ?? ""
	}
	let paths = inputURLs.map { Array($0.path) }
	var result = ""
	for index in 0..<(paths.map(\.count).max() ?? 0){
		let set = Set(paths.map({
			$0[index]
		}))
		if set.count == 1 {
			result.append(set.first!)
		} else {
			break
		}
	}
	return result
}()

dialog.directoryURL = URL(fileURLWithPath: inputURLPrefix)
dialog.canChooseFiles = false
dialog.allowsMultipleSelection = false
dialog.canChooseDirectories = true
dialog.canCreateDirectories = true
dialog.message = "Select a folder to output files"

guard dialog.runModal() == .OK else { exit(0) }
let outputURL = dialog.urls[0]
dialog.directoryURL = URL(fileURLWithPath: inputURLPrefix)

let operationQueue = OperationQueue()
operationQueue.maxConcurrentOperationCount = 16

func runURLs(urls: [URL]) throws {
	for url in urls where url != outputURL {
		var isDirectory: ObjCBool = false
		if FileManager.default.fileExists(atPath: url.standardizedFileURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
			try runURLs(urls: try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil))
		} else {
			let outputPath = outputURL.appendingPathComponent(url.standardizedFileURL.path.replacingOccurrences(of: inputURLPrefix, with: "")).deletingPathExtension().appendingPathExtension("m4a")
			operationQueue.addOperation {
				convert(path: url, to: outputPath)
			}
		}
	}
}

try runURLs(urls: inputURLs)
operationQueue.waitUntilAllOperationsAreFinished()
