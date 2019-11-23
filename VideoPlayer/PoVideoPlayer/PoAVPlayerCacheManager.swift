//
//  PoAVPlayerCacheManager.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/2/21.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import UIKit

class PoAVPlayerCacheManager {
    
    static let shared = PoAVPlayerCacheManager()
    
    private init() {
        let age = (UserDefaults.standard.value(forKey: "PoAVPlayerCacheManager.maxCacheAge") as? TimeInterval) ?? 60 * 60 * 24 * 7
        let size = (UserDefaults.standard.value(forKey: "PoAVPlayerCacheManager.maxCacheAge") as? Int) ?? 0
        self.maxCacheAge = age
        self.maxCacheSize = size
        
        // Subscribe to app event
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deleteOlderFiles as () -> Void),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(backgroundDeleteOldFiles),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    static let ioQueue: DispatchQueue = DispatchQueue(label: "com.PoAVPlayerResourceLoader.www")
    
    // MARK: - Properties
    var maxCacheAge: TimeInterval {
        didSet {
            UserDefaults.standard.set(maxCacheAge, forKey: "PoAVPlayerCacheManager.maxCacheAge")
        }
    }
    var maxCacheSize: Int {
        didSet {
            UserDefaults.standard.set(maxCacheSize, forKey: "PoAVPlayerCacheManager.maxCacheSize")
        }
    }
    
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var fileManager: FileManager {
        return FileManager.default // 线程安全的
    }
    
    func deleteAllFiles(completion: ((Error?) -> Void)? = nil) {
        PoAVPlayerCacheManager.ioQueue.async {
            do {
                try self.fileManager.removeItem(atPath: PoAVPlayerCacheManager.cacheDomainDirectory())
            } catch let error {
                completion?(error)
            }
            completion?(nil)
        }
    }
    
    // MARK: - delete single file
    func deleteFile(by key: String, completion: ((Error?) -> Void)? = nil) {
        
        PoAVPlayerCacheManager.ioQueue.async {
            if let indexPath = PoAVPlayerCacheManager.indexFilePath(for: key) {
                do {
                    try self.fileManager.removeItem(atPath: indexPath)
                    if let dataPath = PoAVPlayerCacheManager.dataFilePath(for: key) {
                        try self.fileManager.removeItem(atPath: dataPath)
                    }
                } catch let error {
                    completion?(error)
                }
            }
            completion?(nil)
        }
    }
    
    // MARK: - delete olderFiles
    @objc
    private func deleteOlderFiles() {
        deleteOlderFiles(with: nil)
    }
    
    @objc
    private func backgroundDeleteOldFiles() {
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(expirationHandler: { [weak self] in
            guard let strongSelf = self else { return }
            UIApplication.shared.endBackgroundTask(strongSelf.backgroundTaskId)
            strongSelf.backgroundTaskId = .invalid
        })
        
        deleteOlderFiles {
            if self.backgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
                self.backgroundTaskId = .invalid
            }
        }
    }
    
    
    /// SDImageCache 借鉴
    private func deleteOlderFiles(with completion: (() -> Void)?) {
        let cachePath = URL(fileURLWithPath: PoAVPlayerCacheManager.cacheDomainDirectory(), isDirectory: true)
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .totalFileAllocatedSizeKey]
        let fileEnumerator = fileManager.enumerator(at: cachePath, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles], errorHandler: nil)!
        let expirationDate = Date(timeIntervalSinceNow: -maxCacheAge)
        
        var cacheFiles = [URL: URLResourceValues]()
        var currentCacheSize = 0
        var urlsToDelete = [URL]()
        
        for fileUrl in fileEnumerator {
            let url = fileUrl as! URL
            var resourceValues: URLResourceValues
            do {
                resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
            } catch let error {
                debugPrint("PoAVPlayerCacheManager error: \(error.localizedDescription)")
                continue
            }
            
            if resourceValues.isDirectory == true {
                continue
            }
            
            if let modifucationDate = resourceValues.contentModificationDate {
                if modifucationDate.compare(expirationDate) == .orderedAscending {
                    urlsToDelete.append(url)
                    continue
                }
            }
            
            if let totalAllocatedSize = resourceValues.totalFileAllocatedSize {
                currentCacheSize += totalAllocatedSize
                cacheFiles[url] = resourceValues
            }
        }
        
        for url in urlsToDelete {
            try? fileManager.removeItem(at: url)
        }
        
        if maxCacheSize > 0 && currentCacheSize > maxCacheSize {
            
            let result = cacheFiles.sorted { (keyValuePair1, keyValuePair2) -> Bool in
                return keyValuePair1.value.contentModificationDate!.compare(keyValuePair2.value.contentModificationDate!) == .orderedAscending
            }
            
            for (key, value) in result {
                if key.absoluteString.hasSuffix(".index") { continue }
                do {
                    try fileManager.removeItem(at: key)
                    try fileManager.removeItem(atPath: key.absoluteString + ".index")
                } catch {
                    continue
                }
                currentCacheSize -= value.totalFileAllocatedSize!
                if currentCacheSize < maxCacheSize {
                    break
                }
            }
        }
        if completion != nil {
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
}

// MARK: - Path Helper

let kCacheDomainName = "/com.avplayercaches.po"
extension PoAVPlayerCacheManager {
    
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
    
    static func indexFilePath(for key: String) -> String? {
        let path = cacheDomainDirectory() + "/\(key.md5).index"
        if !FileManager.default.fileExists(atPath: path) {
            return nil
        }
        return path
    }
    
    static func indexFileURL(for key: String) -> URL? {
        if let path = indexFilePath(for: key) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
    
    static func indexFilePathCreateIfNotExist(for key: String) -> URL {
        let path = cacheDomainDirectory() + "/\(key.md5).index"
        if !FileManager.default.fileExists(atPath: path) {
            let defaultJSON = #"""
                {
                    "mimeType": null,
                    "fragments": [],
                    "expectedLength": -1
                }
            """#
            let success = FileManager.default.createFile(atPath: path, contents: defaultJSON.data(using: .utf8), attributes: nil)
            if !success {
                fatalError("PoAVPlayerResourceCacheFileHandler create index file fail.")
            }
        }
        return URL(fileURLWithPath: path)
    }
    
    static func dataFilePath(for key: String) -> String? {
        let path = cacheDomainDirectory() + "/\(key.md5)"
        if !FileManager.default.fileExists(atPath: path) {
           return nil
        }
        return path
    }
    
    static func dataFileURL(for key: String) -> URL? {
        if let path = dataFilePath(for: key) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
    
    static func dataFilePathCreateIfNotExist(for key: String) -> String {
        let path = cacheDomainDirectory() + "/\(key.md5)"
        if !FileManager.default.fileExists(atPath: path) {
            let success = FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
            if !success {
                fatalError("PoAVPlayerResourceCacheFileHandler create data file fail.")
            }
        }
        return path
    }

}
