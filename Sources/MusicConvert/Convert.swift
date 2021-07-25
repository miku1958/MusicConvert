//
//  File.swift
//  File
//
//  Created by TaoZhuang on 2021/7/25.
//

import Foundation
import AVFoundation

extension Array where Element == AVMutableMetadataItem {
    mutating func addMetadata(identifier: AVMetadataIdentifier, value: NSCopying & NSObjectProtocol, dataType: CFString) {
	   let item = AVMutableMetadataItem()
	   item.identifier = identifier
	   item.value = value
	   item.dataType = dataType as String
	   append(item)
    }
}

func convert(path: URL) {
    let inputPath = path.path
	let outoutPath = path.deletingPathExtension().appendingPathExtension("m4a").path
    
    
    let convertProcess = Process()
    convertProcess.launchPath = "/usr/bin/afconvert"
    convertProcess.arguments = "-f m4af -d aac -s 1 -b 320000 -q 127".split(separator: " ").map { String($0) }
    
    convertProcess.arguments?.append("\(inputPath)")
    convertProcess.arguments?.append(contentsOf: ["-o", "\(outoutPath)"])
    
    print("\(convertProcess.launchPath!) \(convertProcess.arguments!.joined(separator: " "))")
    convertProcess.launch()
    convertProcess.waitUntilExit()
    var status = convertProcess.terminationStatus
    guard status == 0 else {
	   exit(status)
    }
    
    // MARK: - AVAssetWriter
    
    guard let writer = AVAssetExportSession(asset: AVURLAsset(url: URL(fileURLWithPath: outoutPath)), presetName: AVAssetExportPresetPassthrough) else { exit(-1) }
    writer.outputURL = URL(fileURLWithPath: "\(outoutPath).temp")
    writer.outputFileType = .m4a
    
    
    // MARK: - Get Info
    var fileID: AudioFileID? = nil
    status = AudioFileOpenURL(URL(fileURLWithPath: inputPath) as CFURL, .readPermission, kAudioFileFLACType, &fileID)
    
    guard status == noErr else { exit(status) }
    
    var dict: CFDictionary? = nil
    var dataSize = UInt32(MemoryLayout<CFDictionary?>.size(ofValue: dict))
    
    guard let audioFile = fileID else { exit(-1) }
    
    status = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &dataSize, &dict)
    
    guard status == noErr else { exit(status) }
    
    var artwork: CFData?
    dataSize = UInt32(MemoryLayout<CFData?>.size(ofValue: artwork))
    
    status = AudioFileGetProperty(audioFile, kAudioFilePropertyAlbumArtwork, &dataSize, &artwork)
    
    AudioFileClose(audioFile)
    
    // MARK: - write
    var metadatas = [AVMutableMetadataItem]()
    if let artwork = artwork {
	   metadatas.addMetadata(identifier: .commonIdentifierArtwork, value: artwork as NSData, dataType: kCMMetadataBaseDataType_RawData)
    }
    for (key, value) in dict as! [String: String] {
	   switch key {
	   case "title":
		  metadatas.addMetadata(identifier: .commonIdentifierTitle, value: value as NSString, dataType: kCMMetadataBaseDataType_UTF8)
	   case "artist":
		  metadatas.addMetadata(identifier: .commonIdentifierArtist, value: value as NSString, dataType: kCMMetadataBaseDataType_UTF8)
	   case "album":
		  metadatas.addMetadata(identifier: .commonIdentifierAlbumName, value: value as NSString, dataType: kCMMetadataBaseDataType_UTF8)
	   case "composer":
		  metadatas.addMetadata(identifier: .id3MetadataComposer, value: value as NSString, dataType: kCMMetadataBaseDataType_UTF8)
	   case "track number":
		  metadatas.addMetadata(identifier: .id3MetadataTrackNumber, value: value as NSString, dataType: kCMMetadataBaseDataType_UTF8)
	   default: break
	   }
    }
    
    writer.metadata = metadatas
    let semaphore = DispatchSemaphore(value: 0)
    writer.exportAsynchronously { [weak writer] in
	   if let error = writer?.error {
		  print(error)
	   }
	   semaphore.signal()
    }
    semaphore.wait()
    
    try? FileManager.default.removeItem(atPath: outoutPath)
    try? FileManager.default.moveItem(atPath: "\(outoutPath).temp", toPath: outoutPath)
    
}
