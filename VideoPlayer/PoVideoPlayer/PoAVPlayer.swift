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
    
    static let scheme = "__PoAVPlayerScheme__"
}

class PoAVPlayer: UIView {
    
    // MARK: - Properties
    
    weak var delegate: PoAVPlayerDelegate?
    
    /// seconds
    var duration: Double? {
        return _playerItem?.duration.seconds
    }
    
    /// 当前是否可以播放
    var isReadyToPlay: Bool {
        return _player.status == .readyToPlay
    }
    
    /// 是否播放中
    var isPlaying: Bool {
        if #available(iOS 10.0, *) {
            return _player.timeControlStatus != .paused
        } else {
            return _player.rate == 0
        }
    }
    
    private lazy var _player: AVPlayer = AVPlayer(playerItem: nil)
    private var _playerItem: AVPlayerItem?
    private var _timeObserver: Any?
    private lazy var _loaderDelegate: PoAVPlayerResourceLoaderDelegate = PoAVPlayerResourceLoaderDelegate()
    private var _isPlayingBeforeResignActive: Bool = false
    
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
        (self.layer as! AVPlayerLayer).player = _player
        _timeObserver = _player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 600),
                                                      queue: DispatchQueue.main) { [weak self] (time) in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.avplayer(strongSelf, periodicallyInvoke: time)
        }
        _addNotification()
    }
    
    deinit {
        if let timeObserver = _timeObserver {
            _player.removeTimeObserver(timeObserver)
        }
        _removeObserver(for: _playerItem)
        _removeNotification()
        _player.pause()
        _player.currentItem?.cancelPendingSeeks()
        _player.currentItem?.asset.cancelLoading()
    }
    
    // MARK: - Public Method
    
    /// 添加视频播放控制层
    func addControlLayer<T: UIView & PoAVPlayerDelegate>(_ layer: T) {
        self.delegate = layer
        addSubview(layer)
        layer.translatesAutoresizingMaskIntoConstraints = false
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[layer]|", options: [], metrics: nil, views: ["layer": layer]))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[layer]|", options: [], metrics: nil, views: ["layer": layer]))
    }
    
    
    /// 播放url对应的音/视频文件
    /// - Parameters:
    ///   - url: 音/视频文件地址
    ///   - needCache: 是否需要缓存本地
    func play(with url: URL, needCache: Bool = false) {
        var item: AVPlayerItem
        if needCache {
            let url = URL(string: PoAVPlayer.scheme + url.absoluteString)!
            let urlAsset = AVURLAsset(url: url)
            urlAsset.resourceLoader.setDelegate(_loaderDelegate, queue: DispatchQueue.main)
            item = AVPlayerItem(asset: urlAsset)
        } else {
            item = AVPlayerItem(url: url)
        }
        play(with: item)
    }
    
    
    /// 播放item中的音/视频文件，无法缓存本地
    /// - Parameter item: item
    private func play(with item: AVPlayerItem) {
        _removeObserver(for: _playerItem)
        _addObserver(for: item)
        _playerItem = item
        _player.replaceCurrentItem(with: _playerItem)
    }
    
    /// 播放
    func play() {
        if _player.status != .readyToPlay { return }
        _player.play()
    }
    
    /// 暂停
    func pause() {
        if _player.status != .readyToPlay { return }
        _player.pause()
    }
    
    
    /// 跳转到指定时间点
    /// - Parameters:
    ///   - timeInterval: 新的时间点(单位秒)
    ///   - completionHandler: 跳转完成后执行
    func seekToTime(_ timeInterval: TimeInterval, completionHandler: ((Bool) -> Void)? = nil) {
        guard let playItem = _playerItem else {
            completionHandler?(false)
            return
        }
        
        let seconds = playItem.duration.seconds > timeInterval ? timeInterval : playItem.duration.seconds
        if let completionHandler = completionHandler {
            _player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), completionHandler: completionHandler)
        } else {
            _player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
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
                                               selector: #selector(_appResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(_appBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(_playerItemDidPlayToEndTime),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }
    
    private func _removeNotification() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    private func _appResignActive() {
        _isPlayingBeforeResignActive = isPlaying
        if _isPlayingBeforeResignActive {
            _player.pause()
        }
    }
    
    @objc
    private func _appBecomeActive() {
        if _isPlayingBeforeResignActive {
            _player.play()
        }
    }
    
    @objc
    private func _playerItemDidPlayToEndTime() {
        delegate?.avplayerDidPlayToEndTime(self)
    }
}
