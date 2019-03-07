//
//  PoProgressView.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/3/6.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import UIKit

class PoProgressView: UIControl {
    
    private var _progressValue: Float = 0
    var progressValue: Float {
        get { return _progressValue }
        set {
            if abs(newValue - _progressValue) < 0.01 { return }
            if newValue < 0 {
                if _progressValue == 0 { return }
                _progressValue = 0
            } else if newValue > 1 {
                if _progressValue == 1 { return }
                _progressValue = 1
            } else {
                _progressValue = newValue
            }
            setNeedsDisplay()
        }
    }

    private var _sliderValue: Float = 0
    var sliderValue: Float {
        get { return _sliderValue }
        set {
            if abs(newValue - _sliderValue) < 0.01 { return }
            if newValue < 0 {
                _sliderValue = 0
            } else if newValue > 1 {
                _sliderValue = 1
            } else {
                _sliderValue = newValue
            }
            setNeedsDisplay()
        }
    }
    
    var backgroundTintColor: UIColor = UIColor.white {
        didSet { setNeedsDisplay() }
    }
    var progressTintColor: UIColor = UIColor.gray {
        didSet { setNeedsDisplay() }
    }
    var sliderTintColor: UIColor = UIColor.blue {
        didSet { setNeedsDisplay() }
    }
    var thumbTintColor: UIColor = UIColor.red {
        didSet { setNeedsDisplay() }
    }
    private var thumbRect: CGRect = .zero
    private var thumbRadius: CGFloat = 8
    
    var isContinuous: Bool = true
    var isTouching: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    private func setUp() {
        backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let lineWidth: CGFloat = 4
        let width = bounds.width - thumbRadius * 2
        let centerY = bounds.height / 2
        
        let value = CGFloat(1 - max(progressValue, sliderValue)) * width
        if value >= 1 {
            context.saveGState()
            defer { context.restoreGState() }
            
            let startPoint = CGPoint(x: CGFloat(max(progressValue, sliderValue)) * width + thumbRadius, y: centerY)
            let endPoint = CGPoint(x: width + thumbRadius, y: centerY)
            context.setStrokeColor(backgroundTintColor.cgColor)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.setLineWidth(lineWidth)
            context.strokePath()
        }
        
        if sliderValue < progressValue {
            context.saveGState()
            defer { context.restoreGState() }
            
            let startPoint = CGPoint(x: CGFloat(sliderValue) * width + thumbRadius, y: centerY)
            let endPoint = CGPoint(x: CGFloat(progressValue) * width + thumbRadius, y: centerY)
            context.setStrokeColor(progressTintColor.cgColor)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.setLineWidth(lineWidth)
            context.strokePath()
        }
        
        if sliderValue > 0 {
            context.saveGState()
            defer { context.restoreGState() }
            
            let startPoint = CGPoint(x: thumbRadius, y: centerY)
            let endPoint = CGPoint(x: CGFloat(sliderValue) * width + thumbRadius, y: centerY)
            context.setStrokeColor(sliderTintColor.cgColor)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.setLineWidth(lineWidth)
            context.strokePath()
        }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        let sliderX = CGFloat(sliderValue) * width
        thumbRect = CGRect(x: sliderX, y: centerY - thumbRadius, width: thumbRadius * 2, height: thumbRadius * 2)
        context.addEllipse(in: thumbRect)
        context.setFillColor(thumbTintColor.cgColor)
        context.setShadow(offset: CGSize(width: 2, height: 2), blur: 4)
        context.fillPath()
    }
    
}

extension PoProgressView {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point = touches.first!.location(in: self)
        if thumbRect.contains(point) {
            isTouching = true
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTouching {
            let point = touches.first!.location(in: self)
            let value = point.x - thumbRadius
            let newValue = Float(value / (bounds.width - thumbRadius * 2))
            if newValue < -0.01 || newValue > 1.01 { return }
            if abs(newValue - _sliderValue) < 0.01 { return }
            sliderValue = newValue
            if isContinuous {
                sendActions(for: .valueChanged)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTouching {
            if !isContinuous {
                sendActions(for: .valueChanged)
            }
            isTouching = false
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTouching {
            isTouching = false
        }
    }
}
