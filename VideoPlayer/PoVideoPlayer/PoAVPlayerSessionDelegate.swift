//
//  PoAVPlayerSessionDelegate.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/23.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import Foundation


class PoAVPlayerSessionDelegate: NSObject {
    
    // MARK: - Properties
    
    private var tasks: [URLSessionTask: PoAVPlayerResourceRequestRemoteTask] = [:]
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
    
    // MARK: - Convenience Initializator
    
    func remoteDataTask(with url: URL, requestRange: NSRange) -> PoAVPlayerResourceRequestRemoteTask {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpShouldUsePipelining = true
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue(correctRange(requestRange), forHTTPHeaderField: "Range")
        let dataTask = session.dataTask(with: urlRequest)
        let remoteTask = PoAVPlayerResourceRequestRemoteTask(task: dataTask, requestRange: requestRange)
        tasks[dataTask] = remoteTask
        return remoteTask
    }
    
    // MARK: - Helper
    
    private func correctRange(_ range: NSRange) -> String? {
        guard range.location != NSNotFound || range.length > 0 else { return nil }
        
        if range.location == NSNotFound {
            return "bytes=-\(range.length)"
        } else if range.length == .max {
            return "bytes=\(range.location)-"
        } else {
            return "bytes=\(range.location)-\(range.upperBound - 1)"
        }
    }
    
    private func task(for task: URLSessionTask) -> PoAVPlayerResourceRequestRemoteTask? {
        guard let remoteTask = tasks[task] else { return nil }
        guard remoteTask.task.taskIdentifier == task.taskIdentifier else { return nil }
        return remoteTask
    }
    
    private func remove(task: URLSessionTask) {
        tasks.removeValue(forKey: task)
    }
}


extension PoAVPlayerSessionDelegate: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let card = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, card)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let task = task(for: dataTask), let response = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        if response.statusCode < 400 && response.statusCode != 304 {
            if response.mimeType?.contains("video") == true || response.mimeType?.contains("audio") == true {
                task.delegate?.requestTask(task, didReceiveResponse: response)
            }
            completionHandler(.allow)
        } else {
            completionHandler(.cancel)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let task = task(for: dataTask) else { return }

        task.delegate?.requestTask(task, didReceiveData: data)
        task.currentOffset += data.count
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let task = self.task(for: task) {
            task.delegate?.requestTask(task, didCompleteWithError: error)
        }
        remove(task: task)
    }
    
}

