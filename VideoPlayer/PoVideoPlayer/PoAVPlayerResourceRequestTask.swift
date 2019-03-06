//
//  PoAVPlayerResourceRequestTask.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/22.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import UIKit
import AVFoundation

protocol PoAVPlayerResourceRequestTaskDelegate: class {
    
    func requestTask(_ task: PoAVPlayerResourceRequestTask, didReceiveResponse response: URLResponse)
    
    func requestTask(_ task: PoAVPlayerResourceRequestTask, didReceiveData data: Data)
    
    func requestTask(_ task: PoAVPlayerResourceRequestTask, didCompleteWithError error: Error?)
}

// MARK: - PoAVPlayerResourceRequestTask

class PoAVPlayerResourceRequestTask: NSObject {
    
    weak var delegate: PoAVPlayerResourceRequestTaskDelegate?
    let requestRange: NSRange
    var currentOffset: Int
    
    var isCached: Bool = false
    var isExecuting: Bool = false
    var isFinished: Bool = false
    var isCancelled: Bool = false
    
    init(requestRange: NSRange) {
        self.requestRange = requestRange
        self.currentOffset = requestRange.location
    }
    
    func start() {
        isExecuting = true
    }
    
    func cancel() {
        isExecuting = false
        isCancelled = true
    }
}


// MARK: - PoAVPlayerResourceRequestLocalTask
private let kBufferSize = 1024 * 64
class PoAVPlayerResourceRequestLocalTask: PoAVPlayerResourceRequestTask {
    
    // MARK: - Properties
    unowned let fileHandler: PoAVPlayerResourceCacheFileHandler
    unowned let queue: DispatchQueue
    
    init(fileHandler: PoAVPlayerResourceCacheFileHandler, requestRange: NSRange, queue: DispatchQueue) {
        self.fileHandler = fileHandler
        self.queue = queue
        super.init(requestRange: requestRange)
    }
    
    
    override func start() {
        super.start()
        queue.async {
            self.loadLocalData()
        }
    }
    
    private func loadLocalData() {
        if isCancelled { isCancelled = true; return }
        
        self.delegate?.requestTask(self, didReceiveResponse: fileHandler.response)
        let upperBound = self.requestRange.upperBound
        
        while currentOffset < upperBound {
            if isCancelled { break }
            autoreleasepool { () -> Void in
                let length = min(upperBound - currentOffset, kBufferSize)
                let data = self.fileHandler.readData(offset: currentOffset, length: length)
                self.delegate?.requestTask(self, didReceiveData: data)
                currentOffset += length
            }
        }
        self.delegate?.requestTask(self, didCompleteWithError: nil)
        isFinished = true
    }
    
}


// MARK: - PoAVPlayerResourceRequestRemoteTask

class PoAVPlayerResourceRequestRemoteTask: PoAVPlayerResourceRequestTask {
    
    // MARK: - Properties
    let task: URLSessionDataTask
    
    init(task: URLSessionDataTask, requestRange: NSRange) {
        self.task = task
        super.init(requestRange: requestRange)
    }
    
    override func start() {
        super.start()
        task.resume()
    }
    
    override func cancel() {
        if isCancelled || isFinished { return }
        super.cancel()
        task.cancel()
    }
}

