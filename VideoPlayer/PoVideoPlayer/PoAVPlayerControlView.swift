//
//  PoAVControlView.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/16.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import UIKit
import AVFoundation

class PoAVPlayerControlView: UIView {
    
    unowned(unsafe) var player: PoAVPlayer
    
    private(set) var isPlayToEndTime: Bool = false
    
    private let topToolBar = UIView()
    private let titleLabel: UILabel = UILabel()
    
    private let activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .whiteLarge)
    
    private let bottomToolBar = UIView()
    private let currentTimeLabel: UILabel = UILabel()
    private let durationTimeLabel: UILabel = UILabel()
    private let playButton: UIButton = UIButton()
    private let fullScreenButton: UIButton = UIButton()
    private let progress: PoProgressView = PoProgressView()
    private var isIgnorePeriod: Bool = false
    
    init(player: PoAVPlayer) {
        self.player = player
        super.init(frame: .zero)
        _setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func _setup() {
        _addSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        _layoutSubviews()
    }
    
    private func _addSubviews() {
        /* ------------------------------topToolBar ------------------------------ */
        topToolBar.backgroundColor = UIColor(white: 0.5, alpha: 0.7)
        self.addSubview(topToolBar)
        
        // 名称
        titleLabel.textColor = UIColor.white
        topToolBar.addSubview(titleLabel)
        titleLabel.text = "title"
        
        
        // 网络指示器
        self.addSubview(activityIndicator)
        
        /* -----------------------------bottomToolBar ----------------------------- */
        bottomToolBar.backgroundColor = UIColor(white: 0.5, alpha: 0.7)
        self.addSubview(bottomToolBar)
        
        // 播放/暂停按钮
        playButton.addTarget(self, action: #selector(PoAVPlayerControlView.playButtonHandle(_:)), for: .touchUpInside)
        bottomToolBar.addSubview(playButton)
        playButton.setTitle("播放", for: .normal)
        playButton.setTitle("暂停", for: .selected)
        
        // 当前播放时间
        currentTimeLabel.text = "00:00:00"
        currentTimeLabel.textColor = UIColor.white
        currentTimeLabel.font = UIFont.systemFont(ofSize: 13)
        bottomToolBar.addSubview(currentTimeLabel)
        
        // 播放/缓冲进度
        progress.isContinuous = false
        progress.addTarget(self, action: #selector(PoAVPlayerControlView.progressChangeHandle(_:)), for: .valueChanged)
        bottomToolBar.addSubview(progress)
        
        // 总播放时间
        durationTimeLabel.text = "00:00:00"
        durationTimeLabel.textColor = UIColor.white
        durationTimeLabel.font = UIFont.systemFont(ofSize: 13)
        bottomToolBar.addSubview(durationTimeLabel)
        
        // 全屏
        fullScreenButton.addTarget(self, action: #selector(PoAVPlayerControlView.fullScreenButtonHandle(_:)), for: .touchUpInside)
        bottomToolBar.addSubview(fullScreenButton)
        fullScreenButton.setTitle("全屏", for: .normal)
    }
    
    private func _layoutSubviews() {
        /* ------------------------------topToolBar ------------------------------ */
        
        let size = CGSize(width: 45, height: 30)
        let padding: CGFloat = 8
        
        topToolBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 60)
        
        // 名称
        titleLabel.frame = CGRect(x: padding, y: 0, width: topToolBar.bounds.width - 40, height: 60)
        
        
        // 网络指示器
        activityIndicator.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        
        /* -----------------------------bottomToolBar ----------------------------- */
        bottomToolBar.frame = CGRect(x: 0, y: bounds.height - 60, width: bounds.width, height: 60)
        
        // 播放/暂停按钮
        let y = (bottomToolBar.bounds.height - size.height)/2
        
        playButton.frame = CGRect(x: padding, y: y, width: size.width, height: size.height)
        
        // 当前播放时间
        currentTimeLabel.frame = CGRect(x: playButton.frame.maxX + padding, y: y, width: 60, height: size.height)
        
        // 全屏按钮
        fullScreenButton.frame = CGRect(x: bounds.width - size.width - padding, y: y, width: size.width, height: size.height)
        
        // 总时长
        durationTimeLabel.frame = CGRect(x: fullScreenButton.frame.minX - padding - 60, y: y, width: 60, height: size.height)
        
        // 缓冲进度
        let width: CGFloat = bounds.width - padding - playButton.bounds.width - padding - currentTimeLabel.bounds.width - padding - padding - durationTimeLabel.bounds.width - padding - fullScreenButton.bounds.width - padding
        
        progress.frame = CGRect(x: currentTimeLabel.frame.maxX + padding, y: (bottomToolBar.bounds.height - 20)/2, width: width, height: 20)
    }
    
    // MARK: - selector
    @objc
    private func playButtonHandle(_ sender: UIButton) {
        if sender.isSelected {
            player.pause()
        } else {
            if isPlayToEndTime {
                player.seekToTime(0) { (finished) in
                    if finished {
                        self.player.play()
                    }
                }
                isPlayToEndTime = false
            } else {
                player.play()
            }
        }
        sender.isSelected.toggle()
    }
    
    @objc
    private func progressChangeHandle(_ sender: PoProgressView) {
        guard let duration = player.duration else { return }
        
        let isPlaying = player.isPlaying
        if isPlaying {
            player.pause()
            playButton.isSelected = false
            isIgnorePeriod = true
        }
        
        let target = Double(sender.sliderValue) *  duration
        print(target)
        player.seekToTime(target) { (finished) in
            if finished && isPlaying {
                self.player.play()
                self.playButton.isSelected = true
                self.isIgnorePeriod = false
            }
        }
    }
    
    @objc
    private func fullScreenButtonHandle(_ sender: UIButton) {
        debugPrint("not implement.")
    }
    
    // MARK: - helper
    private func formartDuration(_ duration: Double) -> String {
        let duration = Int(duration)
        let second = duration % 60
        let minute = (duration % 3600) / 60
        let hour = duration / 3600
        return String(format: "%02d:%02d:%02d", hour, minute, second)
    }
}


// MARK: - PoAVPlayerDelegate
extension PoAVPlayerControlView: PoAVPlayerDelegate {
    
    /// 音视频资源加载的状态，是否可以播放: unknown, readyToPlay, failed
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            durationTimeLabel.text = formartDuration(player.duration!)
        default:
            debugPrint("player item can't be played. status: \(status.rawValue)")
        }
    }
    
    /// 缓冲到了哪儿
    func avplayer(_ player: PoAVPlayer, loadedTimeRange range: CMTimeRange) {
        let loaded = range.end.seconds
        let duration = player.duration!
        progress.progressValue = Float(loaded / duration)
    }
    
    /// 缓冲数据是否够用
    func avplayer(_ player: PoAVPlayer, playbackBufferStatus status: PoAVPlayer.PlaybackBufferStatus) {
        switch status {
        case .full:
            activityIndicator.stopAnimating()
        case .empty:
            activityIndicator.startAnimating()
        }
    }
    
    /// 播放时周期性回调
    func avplayer(_ player: PoAVPlayer, periodicallyInvoke time: CMTime) {
        let current = time.seconds
        let duration = player.duration!
        if !progress.isTouching && !isIgnorePeriod {
            progress.sliderValue = Float(current / duration)
        }
        currentTimeLabel.text = formartDuration(current)
    }
    
    /// 播放完毕
    func avplayerDidPlayToEndTime(_ player: PoAVPlayer) {
        isPlayToEndTime = true
        playButton.isSelected = false
    }
}
