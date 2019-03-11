//
//  PoAVPlayer.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/16.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import UIKit
import AVFoundation

protocol PoAVPlayerDelegate: class {
    
    /// 音视频资源加载的状态，是否可以播放: unknown, readyToPlay, failed
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: AVPlayerItem.Status)
    /// 缓冲到了哪儿
    func avplayer(_ player: PoAVPlayer, loadedTimeRange range: CMTimeRange)
    /// 缓冲数据是否够用
    func avplayer(_ player: PoAVPlayer, playbackBufferStatus status: PoAVPlayer.PlaybackBufferStatus)
    /// 播放时周期性回调
    func avplayer(_ player: PoAVPlayer, periodicallyInvoke time: CMTime)
    /// 播放完毕
    func avplayerDidPlayToEndTime(_ player: PoAVPlayer)
}

extension PoAVPlayerDelegate {
    /// 音视频资源加载的状态，是否可以播放: unknown, readyToPlay, failed
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: AVPlayerItem.Status) {}
    /// 缓冲到了哪儿
    func avplayer(_ player: PoAVPlayer, loadedTimeRange range: CMTimeRange) {}
    /// 缓冲数据是否够用
    func avplayer(_ player: PoAVPlayer, playbackBufferStatus status: PoAVPlayer.PlaybackBufferStatus) {}
    /// 播放时周期性回调
    func avplayer(_ player: PoAVPlayer, periodicallyInvoke time: CMTime) {}
    /// 播放完毕
    func avplayerDidPlayToEndTime(_ player: PoAVPlayer) {}
}

extension PoAVPlayer {
    enum PlaybackBufferStatus {
        case full
        case empty
    }
}

class PoAVPlayer: UIView {
    
    // MARK: - Properties
    
    weak var delegate: PoAVPlayerDelegate?
    
    var duration: Double {
        return playerItem?.duration.seconds ?? -1
    }
    
    var isReadyToPlay: Bool {
        return player.status == .readyToPlay
    }
    
    var isPlaying: Bool {
        if #available(iOS 10.0, *) {
            return player.timeControlStatus != .paused
        } else {
            return player.rate == 0
        }
    }
    
    private var isPlayingBeforeResignActive: Bool = false
    
    private lazy var player: AVPlayer = AVPlayer(playerItem: nil)
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    // MARK: - Override
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _setup()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _setup()
    }
    
    private func _setup() {
        (self.layer as! AVPlayerLayer).player = player
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1),
                                                      queue: DispatchQueue.main) { [weak self] (time) in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.avplayer(strongSelf, periodicallyInvoke: time)
        }
        _addNotification()
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        _removeObserver(for: playerItem)
        _removeNotification()
        player.pause()
        player.currentItem?.cancelPendingSeeks()
        player.currentItem?.asset.cancelLoading()
    }
    
    /// 添加视频播放控制层
    func addControlLayer<T: UIView & PoAVPlayerDelegate>(_ layer: T) {
        self.delegate = layer
        addSubview(layer)
        layer.translatesAutoresizingMaskIntoConstraints = false
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[layer]|", options: [], metrics: nil, views: ["layer": layer]))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[layer]|", options: [], metrics: nil, views: ["layer": layer]))
    }
    
    /// 播放视频
    func play(with url: URL, needCache: Bool = false) {
        var item: AVPlayerItem
        if needCache {
            let url = URL(string: kScheme + url.absoluteString)!
            let urlAsset = AVURLAsset(url: url)
            urlAsset.resourceLoader.setDelegate(PoAVPlayerResourceLoaderDelegate.shared, queue: DispatchQueue.main)
            item = AVPlayerItem(asset: urlAsset)
        } else {
            item = AVPlayerItem(url: url)
        }
        play(with: item)
    }
    
    private func play(with item: AVPlayerItem) {
        _removeObserver(for: playerItem)
        _addObserver(for: item)
        playerItem = item
        player.replaceCurrentItem(with: playerItem)
    }
    
    /// 播放
    func play() {
        if player.status != .readyToPlay { return }
        player.play()
    }
    
    /// 暂停
    func pause() {
        player.pause()
    }
    
    /// 跳转
    func seekToTime(_ timeInterval: TimeInterval, completionHandler: ((Bool) -> Void)? = nil) {
        guard let playItem = playerItem else {
            completionHandler?(false)
            return
        }
        
        let seconds = (playItem.duration.seconds - timeInterval) > 0 ? timeInterval : playItem.duration.seconds
        if let completionHandler = completionHandler {
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), completionHandler: completionHandler)
        } else {
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        }
    }
    
    // MARK: - Observer
    
    private func _addObserver(for playerItem: AVPlayerItem?) {
        playerItem?.addObserver(self, forKeyPath: "loadedTimeRanges", options: [.new], context: nil)
        playerItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        playerItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [.new], context: nil)
        playerItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.new], context: nil)
    }
    
    private func _removeObserver(for playerItem: AVPlayerItem?) {
        playerItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
        playerItem?.removeObserver(self, forKeyPath: "status")
        playerItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
        playerItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let playerItem = object as? AVPlayerItem else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == "loadedTimeRanges", let range = playerItem.loadedTimeRanges.last {
            delegate?.avplayer(self, loadedTimeRange: range.timeRangeValue)
        } else if keyPath == "status" {
            delegate?.avplayer(self, playerItemStatusChanged: playerItem.status)
        } else if keyPath == "playbackBufferEmpty" {
            delegate?.avplayer(self, playbackBufferStatus: .empty)
        } else if keyPath == "playbackLikelyToKeepUp" {
            delegate?.avplayer(self, playbackBufferStatus: .full)
        }
    }
    
    // MARK: - Notification
    
    private func _addNotification() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidPlayToEndTime),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }
    
    private func _removeNotification() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    private func appResignActive() {
        isPlayingBeforeResignActive = isPlaying
        if isPlayingBeforeResignActive {
            player.pause()
        }
    }
    
    @objc
    private func appBecomeActive() {
        if isPlayingBeforeResignActive {
            player.play()
        }
    }
    
    @objc
    private func playerItemDidPlayToEndTime() {
        delegate?.avplayerDidPlayToEndTime(self)
    }
}
