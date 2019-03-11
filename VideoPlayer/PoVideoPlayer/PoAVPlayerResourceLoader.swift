//
//  PoAVPlayerResourceLoader.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/21.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import Foundation
import AVFoundation
import MobileCoreServices.UTType

class PoAVPlayerResourceLoader {
    
    // MARK: - Properties
    
    let resourceIdentifier: URL
    private var requests: [AVAssetResourceLoadingRequest] = []
    var isEmpty: Bool {
        lock.wait()
        let result = requests.isEmpty
        lock.signal()
        return result
    }
    
    var requestCount: Int {
        lock.wait()
        let count = requests.count
        lock.signal()
        return count
    }
    
    private var runningRequest: AVAssetResourceLoadingRequest?
    private var requestTasks: [PoAVPlayerResourceRequestTask] = []
    private let fileHandler: PoAVPlayerResourceCacheFileHandler
    private let sessionDelegate = PoAVPlayerSessionDelegate()
    private let lock: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    // MARK: - Initializator
    
    init(resourceIdentifier: URL) {
        self.resourceIdentifier = resourceIdentifier
        self.fileHandler = PoAVPlayerResourceCacheFileHandler(resourceIdentifier: resourceIdentifier)
    }
    
    
    // MARK: - Methods
    
    func appending(_ request: AVAssetResourceLoadingRequest) {
        let lower = Int(request.dataRequest!.requestedOffset)
        let upper = request.dataRequest!.requestedLength
        print("\(Date()) request发起: [\(lower) ~ \(upper + lower)]-----------------\(upper)")
        lock.wait()
        requests.append(request)
        lock.signal()
        startHandleNextRequest()
    }
    
//    func cancelRunningRequest() {
//        guard let _ = self.runningRequest else { return }
//        self.requestTasks.first?.cancel()
//
//        lock.wait()
//        if let index = self.requests.firstIndex(of: request) {
//            let request = self.requests[index]
//            if request == self.runningRequest {
//                self.requestTasks.forEach({ print("\(Date()) 取消task: [\($0.requestRange.location) ~ \($0.requestRange.upperBound)]"); $0.cancel() })
//            } else {
//                self.requests.remove(at: index)
//            }
//        }
//        lock.signal()
//    }
    
    func cancel(_ request: AVAssetResourceLoadingRequest) {
//        let lower = Int(request.dataRequest!.requestedOffset)
//        let upper = lower + request.dataRequest!.requestedLength
//        print("取消request: [\(lower) ~ \(upper)]")
        lock.wait()
        if let index = self.requests.firstIndex(of: request) {
            let request = self.requests[index]
            if request == self.runningRequest {
//                self.requestTasks.forEach({ $0.cancel() })
                if let task = requestTasks.first {
                    print("\(Date()) 取消task: [\(task.requestRange.location) ~ \(task.requestRange.upperBound)]")
                }
                self.requestTasks.first?.cancel()
            } else {
                self.requests.remove(at: index)
            }
        }
        lock.signal()
    }
    
    
    // MARK: - Helper
    
    private func startHandleNextRequest() {
        // 如果有任务正在执行or任务列表为空, 直接返回
        if runningRequest != nil { return }
        // 取出最前面的任务，没有直接返回
        guard let next = requests.first else { return }
        
        let local = next.dataRequest?.requestedOffset ?? 0
        let length = next.dataRequest?.requestedLength ?? 0
        runningRequest = next
        let range = NSRange(location: Int(local), length: length)
        assignTasks(with: range)
    }
    
    // 分割请求的range，生成task
    private func assignTasks(with range: NSRange) {
        var offset = range.location
        let upper = range.upperBound
        
        while offset < upper {
            if let cachedRange = fileHandler.firstCachedFragment(in: NSRange(location: offset, length: upper - offset)) {
                if offset < cachedRange.location {
                    let remoteTask = sessionDelegate.remoteDataTask(with: resourceIdentifier, requestRange: NSRange(location: offset, length: cachedRange.location - 1))
                    requestTasks.append(remoteTask)
                    let localTask = PoAVPlayerResourceRequestLocalTask(fileHandler: fileHandler, requestRange: cachedRange)
                    requestTasks.append(localTask)
                    
                    offset = cachedRange.upperBound
                } else {
                    let localTask = PoAVPlayerResourceRequestLocalTask(fileHandler: fileHandler, requestRange: cachedRange)
                    requestTasks.append(localTask)
    
                    offset = cachedRange.upperBound
                }
            } else {
                let remoteTask = sessionDelegate.remoteDataTask(with: resourceIdentifier, requestRange: NSRange(location: offset, length: upper - offset))
                requestTasks.append(remoteTask)
                offset = upper
            }
        }
        
        startHandleNextTask()
    }
    
    private func startHandleNextTask() {
        if requestTasks.isEmpty {
            let lower = Int(runningRequest!.dataRequest!.requestedOffset)
            let upper = runningRequest!.dataRequest!.requestedLength
            print("\(Date()) request完成: [\(lower) ~ \(upper + lower)]")
            requests.removeFirst()
            runningRequest?.finishLoading()
            runningRequest = nil
            startHandleNextRequest()
        } else {
            requestTasks.first?.delegate = self
            requestTasks.first?.start()
            print("\(Date()) 发起task: [\(requestTasks.first!.requestRange.location) ~ \(requestTasks.first!.requestRange.upperBound)]")
        }
    }

        
    private func fillContentInformationRequest(with response: URLResponse, isFromLocal: Bool) {
        if isFilledContentInformation { return }
        isFilledContentInformation = true
        
        guard let response = response as? HTTPURLResponse else { return }
        
        if let mimeType = response.mimeType {
            let result = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
            runningRequest?.contentInformationRequest?.contentType = result?.takeRetainedValue() as String?
        }
        runningRequest?.contentInformationRequest?.isByteRangeAccessSupported = true
        if !isFromLocal {
            if let range = response.allHeaderFields["Content-Range"] as? String {
                let ranges = range.components(separatedBy: "/")
                if let lengthStr = ranges.last {
                    runningRequest?.contentInformationRequest?.contentLength = Int64(lengthStr) ?? 0
                }
            } else if let range = response.allHeaderFields["content-range"] as? String {
                let ranges = range.components(separatedBy: "/")
                if let lengthStr = ranges.last {
                    runningRequest?.contentInformationRequest?.contentLength = Int64(lengthStr) ?? 0
                }
            }
            fileHandler.cacheInfo.mimeType = response.mimeType
            fileHandler.cacheInfo.expectedLength = Int(runningRequest?.contentInformationRequest?.contentLength ?? 0)
        } else {
            runningRequest?.contentInformationRequest?.contentLength = response.expectedContentLength
        }
    }
    
    private var isFilledContentInformation: Bool = false
}


// MARK: - PoAVPlayerResourceRequestTaskDelegate

extension PoAVPlayerResourceLoader: PoAVPlayerResourceRequestTaskDelegate {
    
    func requestTask(_ task: PoAVPlayerResourceRequestTask, didReceiveResponse response: URLResponse) {
        if task is PoAVPlayerResourceRequestLocalTask {
            fillContentInformationRequest(with: response, isFromLocal: true)
        } else {
            fillContentInformationRequest(with: response, isFromLocal: false)
        }
    }
    
    func requestTask(_ task: PoAVPlayerResourceRequestTask, didReceiveData data: Data) {
        runningRequest?.dataRequest?.respond(with: data)
        if task is PoAVPlayerResourceRequestRemoteTask {
            fileHandler.saveData(data, at: UInt64(task.currentOffset))
            fileHandler.saveFragment(NSRange(location: task.currentOffset, length: data.count))
        }
    }
    
    func requestTask(_ task: PoAVPlayerResourceRequestTask, didCompleteWithError error: Error?) {
        if task is PoAVPlayerResourceRequestRemoteTask {
            fileHandler.synchronize()
        }
        print("\(Date()) 完成task: [\(task.requestRange.location) ~ \(task.requestRange.upperBound)]")
        if error != nil {
            print("\(Date()) task错误: \(error!.localizedDescription)")
            requestTasks.removeAll()
            lock.wait()
            requests.removeFirst()
            lock.signal()
            runningRequest?.finishLoading(with: error)
            runningRequest = nil
            startHandleNextRequest()
            return
        } else {
            requestTasks.removeFirst()
            startHandleNextTask()
        }
    }
}
