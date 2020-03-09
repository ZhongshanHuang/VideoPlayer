//
//  PoAVPlayerResourceLoaderManager.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/21.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import Foundation
import AVFoundation

class PoAVPlayerResourceLoaderDelegate: NSObject {}

private var pResourceLoaderKey: Void?

extension AVAssetResourceLoader {
    var pResourceLoader: PoAVPlayerResourceLoader? {
        get {
            return objc_getAssociatedObject(self, &pResourceLoaderKey) as? PoAVPlayerResourceLoader
        }
        set {
            objc_setAssociatedObject(self, &pResourceLoaderKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}



// MARK: - PoAVPlayerResourceLoaderManager

extension PoAVPlayerResourceLoaderDelegate: AVAssetResourceLoaderDelegate {
    
    /// avasset遇到系统无法处理的url时会调用此方法
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if resourceLoader.pResourceLoader != nil {
            resourceLoader.pResourceLoader?.appending(request: loadingRequest)
            return true
        } else if let url = loadingRequest.request.url, url.absoluteString.hasPrefix(PoAVPlayer.scheme) {
            let urlStr = url.absoluteString[PoAVPlayer.scheme.endIndex...]
            guard let originalUrl = URL(string: String(urlStr)) else { return false }
            let loader = PoAVPlayerResourceLoader(resourceIdentifier: originalUrl)
            loader.appending(request: loadingRequest)
            resourceLoader.pResourceLoader = loader
            return true
        }
        return false
    }
    
    /// 当播放跳转到别的时间时会调用此方法
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        resourceLoader.pResourceLoader?.cancel(loadingRequest)
    }
}
