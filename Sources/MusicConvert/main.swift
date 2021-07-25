import Foundation
import AppKit

NSApplication.shared.setActivationPolicy(.accessory)
let dialog = NSOpenPanel()
dialog.allowedFileTypes = ["flac", "wav"]
dialog.allowsMultipleSelection = true
guard dialog.runModal() == .OK else { exit(0) }

for url in dialog.urls {
    convert(path: url)
}

