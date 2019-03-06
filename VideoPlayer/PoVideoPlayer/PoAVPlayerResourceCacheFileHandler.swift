//
//  PoAVPlayerResourceCacheFileHandler.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/31.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import Foundation


let kCacheDomainName = "/com.avplayercaches.po"

class PoAVPlayerResourceCacheFileHandler {
    
    let indexFilePath: URL
    let dataFilePath: String
    let response: URLResponse
    var cacheInfo: CacheInfo!
    private lazy var writeHandle: FileHandle = FileHandle(forWritingAtPath: self.dataFilePath)!
    private lazy var readHandle: FileHandle = FileHandle(forReadingAtPath: self.dataFilePath)!
    
    init(resourceIdentifier: URL) {
        let sourceId = resourceIdentifier.absoluteString.md5
        
        self.indexFilePath = PoAVPlayerResourceCacheFileHandler.indexFilePath(for: sourceId)
        self.dataFilePath = PoAVPlayerResourceCacheFileHandler.dataFilePath(for: sourceId)
        do {
            let data = try Data(contentsOf: indexFilePath)
            cacheInfo = try JSONDecoder().decode(CacheInfo.self, from: data)
        } catch (let error) {
            fatalError("CacheInfo decode fail: \(error.localizedDescription)")
        }
        response = HTTPURLResponse(url: resourceIdentifier, mimeType: cacheInfo.mimeType, expectedContentLength: cacheInfo.expectedLength, textEncodingName: nil)
        debugPrint(dataFilePath)
    }
    
    deinit {
        writeHandle.closeFile()
        readHandle.closeFile()
    }
    
    // MARK: - Data
    
    /// save data
    func saveData(_ data: Data, at fileOffset: UInt64) {
        writeHandle.seek(toFileOffset: fileOffset)
        writeHandle.write(data)
    }
    
    /// read data
    func readData(offset: Int, length: Int) -> Data {
        readHandle.seek(toFileOffset: UInt64(offset))
        return readHandle.readData(ofLength: length)
    }
    
    // MARK: - Fragment
    
    func saveFragment(_ range: NSRange) {
        cacheInfo.fragments.insert(range)
    }
        
    /// cached fragment
    func firstCachedFragment(in range: NSRange) -> NSRange? {
        for fragment in cacheInfo.fragments {
            if let intersection = fragment.intersection(range) {
                return intersection
            }
        }
        return nil
    }
    
    // MARK: - Synchronize
    
    func synchronize() {
        do {
            let data = try JSONEncoder().encode(cacheInfo)
            try data.write(to: indexFilePath)
        } catch (let error) {
            fatalError("CacheInfo encode fail: \(error.localizedDescription)")
        }
    }
}


// MARK: - Path helper

extension PoAVPlayerResourceCacheFileHandler {
    
    static func cacheDomainDirectory() -> String {
        var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        path += kCacheDomainName
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch (let error) {
                fatalError("PoAVPlayerResourceCacheFileHandler init error: [\(error.localizedDescription)].")
            }
        }
        return path
    }
    
    static func indexFilePath(for key: String) -> URL {
        let path = cacheDomainDirectory() + "/\(key).index"
        if !FileManager.default.fileExists(atPath: path) {
            let defaultJSON = """
                {"mimeType":null,"fragments":[],"expectedLength":-1}
            """
            let success = FileManager.default.createFile(atPath: path, contents: defaultJSON.data(using: .utf8), attributes: nil)
            if !success {
                fatalError("PoAVPlayerResourceCacheFileHandler create index file fail.")
            }
        }
        return URL(fileURLWithPath: path)
    }
    
    static func dataFilePath(for key: String) -> String {
        let path = cacheDomainDirectory() + "/\(key)"
        if !FileManager.default.fileExists(atPath: path) {
            let success = FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
            if !success {
                fatalError("PoAVPlayerResourceCacheFileHandler create data file fail.")
            }
        }
        return path
    }
}


// MARK: - CacheInfo

extension PoAVPlayerResourceCacheFileHandler {
    
    struct CacheInfo: Codable {
        var expectedLength: Int
        var mimeType: String?
        var fragments: FragmentArray
        
        init(expectedLength: Int, mimeType: String?, fragments: [NSRange]) {
            self.expectedLength = expectedLength
            self.mimeType = mimeType
            self.fragments = FragmentArray(fragments)
        }
        
        enum CodingKeys: String, CodingKey {
            case expectedLength
            case mimeType
            case fragments
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let expectedLength = try container.decode(Int.self, forKey: .expectedLength)
            let mimeType = try container.decode(Optional<String>.self, forKey: .mimeType)
            var unkeyedContainer = try container.nestedUnkeyedContainer(forKey: .fragments)
            
            var fragments = [NSRange]()
            while !unkeyedContainer.isAtEnd {
                let range = try unkeyedContainer.decode(NSRange.self)
                fragments.append(range)
            }
            self.init(expectedLength: expectedLength, mimeType: mimeType, fragments: fragments)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(expectedLength, forKey: .expectedLength)
            try container.encode(mimeType, forKey: .mimeType)
            var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .fragments)
            try fragments.forEach { (range) in
                try unkeyedContainer.encode(range)
            }
        }
    }
}
