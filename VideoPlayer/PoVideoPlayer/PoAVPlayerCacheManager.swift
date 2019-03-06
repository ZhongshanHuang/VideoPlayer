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
        let cachePath = URL(fileURLWithPath: "", isDirectory: true)
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
