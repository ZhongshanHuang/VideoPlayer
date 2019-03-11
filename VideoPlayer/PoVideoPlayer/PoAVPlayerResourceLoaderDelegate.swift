//
//  PoAVPlayerResourceLoaderManager.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/21.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import Foundation
import AVFoundation

let kScheme = "__PoAVPlayerScheme__"

class PoAVPlayerResourceLoaderDelegate: NSObject {
    
    /// singleton
    static let shared: PoAVPlayerResourceLoaderDelegate = PoAVPlayerResourceLoaderDelegate()
    private override init() {}
    
    // MARK: - Properties
    
    private lazy var loadingRequests: [URL: PoAVPlayerResourceLoader] = [:]
}



// MARK: - PoAVPlayerResourceLoaderManager

extension PoAVPlayerResourceLoaderDelegate: AVAssetResourceLoaderDelegate {
    
    /// avasset遇到系统无法处理的url时会调用此方法
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let url = loadingRequest.request.url, url.absoluteString.hasPrefix(kScheme) {
            if let loader = loadingRequests[url] {
                loader.appending(loadingRequest)
            } else {
                let urlStr = url.absoluteString[kScheme.endIndex...]
                let originalUrl = URL(string: String(urlStr))!
                let loader = PoAVPlayerResourceLoader(resourceIdentifier: originalUrl)
                loader.appending(loadingRequest)
                loadingRequests[url] = loader
            }
            return true
        }
        return false
    }
    
    /// 当数据加载完成或者播放跳转到到别的时间时会调用此方法
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let offset = loadingRequest.dataRequest!.requestedOffset
        let length = loadingRequest.dataRequest!.requestedLength
        print("\(Date()) request取消: [\(offset) ~ \(offset + Int64(length))]")
        if let url = loadingRequest.request.url, let loader = loadingRequests[url] {
            loader.cancel(loadingRequest)
            if loader.isEmpty {
                loadingRequests.removeValue(forKey: url)
            }
        }
    }
}
