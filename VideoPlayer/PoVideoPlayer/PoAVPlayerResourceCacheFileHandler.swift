//
//  PoAVPlayerResourceCacheFileHandler.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/31.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import Foundation


//let kCacheDomainName = "/com.avplayercaches.po"

class PoAVPlayerResourceCacheFileHandler {
    
    let indexFilePath: URL
    let dataFilePath: String
    let response: URLResponse
    var cacheInfo: CacheInfo!
    private lazy var writeHandle: FileHandle = FileHandle(forWritingAtPath: self.dataFilePath)!
    private lazy var readHandle: FileHandle = FileHandle(forReadingAtPath: self.dataFilePath)!
    
    
    init(resourceIdentifier: URL) {
        let key = resourceIdentifier.absoluteString
        
        self.indexFilePath = PoAVPlayerCacheManager.indexFilePathCreateIfNotExist(for: key)
        self.dataFilePath = PoAVPlayerCacheManager.dataFilePathCreateIfNotExist(for: key)
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
        PoAVPlayerCacheManager.ioQueue.async {
            self.writeHandle.seek(toFileOffset: fileOffset)
            self.writeHandle.write(data)
        }
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
        PoAVPlayerCacheManager.ioQueue.async {
            do {
                let data = try JSONEncoder().encode(self.cacheInfo)
                try data.write(to: self.indexFilePath)
            } catch (let error) {
                fatalError("CacheInfo encode fail: \(error.localizedDescription)")
            }
        }
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
