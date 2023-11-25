//
//  PryntTrimmerView.swift
//  PryntTrimmerView
//
//  Created by HHK on 27/03/2017.
//  Copyright © 2017 Prynt. All rights reserved.
//

import AVFoundation
import UIKit

public protocol TrimmerViewDelegate: AnyObject {
    func didChangePositionBar(_ playerTime: CMTime)
    func positionBarStoppedMoving(_ playerTime: CMTime)
}

public protocol TrimmerScrollDelegate: AnyObject {
    func scrollDidMove(_ contentOffset: CGPoint)
}


@IBDesignable public class TrimmerView: AVAssetTimeSelector {

    // MARK: Color Customization

    /// The color of the main border of the view
    @IBInspectable public var mainColor: UIColor = UIColor.black {
        didSet {
//            updateMainColor()
        }
    }

    /// The color of the handles on the side of the view
    @IBInspectable public var handleColor: UIColor = UIColor.white {
        didSet {
//           updateHandleColor()
        }
    }

    /// The color of the position indicator
    @IBInspectable public var positionBarColor: UIColor = UIColor.white {
        didSet {
            positionBar.backgroundColor = positionBarColor
        }
    }

    /// The color used to mask unselected parts of the video
    @IBInspectable public var maskColor: UIColor = UIColor.white {
        didSet {
//            leftMaskView.backgroundColor = maskColor
//            rightMaskView.backgroundColor = maskColor
        }
    }

    // MARK: Interface

    public weak var delegate: TrimmerViewDelegate?
    public weak var scrollDelegate: TrimmerScrollDelegate?

    // MARK: Subviews

    private let positionBar = TimeBar()
    private let trimRepresentation = TrimRepresentationView()
    private let timestampScrollView = TimestampScrollView()

    // MARK: Constraints

    private var currentPositionConstraint: CGFloat = 0
    private var positionConstraint: NSLayoutConstraint?

    public let handleWidth: CGFloat = 10

    public override var maxDuration: Double {
        didSet {
            assetPreview.maxDuration = maxDuration
        }
    }
    
    public var minDuration: Double = 3

    // MARK: - View & constraints configurations

    override func setupSubviews() {
        super.setupSubviews()
        backgroundColor = UIColor.clear
        layer.zPosition = 1
        setupTrimmerView()
        setupPositionBar()
        setupGestures()
        bringSubviewToFront(positionBar)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        assetPreview.layer.cornerRadius = 16
    }

    override func constrainAssetPreview() {
        assetPreview.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        assetPreview.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        assetPreview.topAnchor.constraint(equalTo: topAnchor).isActive = true
        assetPreview.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }

    private func setupTrimmerView() {
        trimRepresentation.delegate = self
        addSubview(trimRepresentation)
        trimRepresentation.translatesAutoresizingMaskIntoConstraints = false

        trimRepresentation.topAnchor.constraint(equalTo: topAnchor).isActive = true
        trimRepresentation.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        trimRepresentation.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        trimRepresentation.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    }
    
    private func setupPositionBar() {
        positionBar.backgroundColor = positionBarColor
        positionBar.layer.cornerRadius = 2
        positionBar.translatesAutoresizingMaskIntoConstraints = false
        positionBar.isUserInteractionEnabled = true
        
        addSubview(positionBar)

        positionBar.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        positionBar.widthAnchor.constraint(equalToConstant: 4).isActive = true
        positionBar.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 1.2).isActive = true
        positionConstraint = positionBar.leadingAnchor.constraint(equalTo: trimRepresentation.leadingAnchor)
        positionConstraint?.isActive = true
    }

    private func setupGestures() {
        let positionBarPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TrimmerView.handlePositionGesture))
        positionBar.addGestureRecognizer(positionBarPanGestureRecognizer)
    }
    
    // MARK: - Trim Gestures

    @objc func handlePositionGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let superView = gestureRecognizer.view?.superview else { return }
        switch gestureRecognizer.state {

        case .began:
            currentPositionConstraint = positionConstraint!.constant
            updateSelectedTime(stoppedMoving: false)
        case .changed:
            let translation = gestureRecognizer.translation(in: superView)
            let maxConstraint = trimRepresentation.endTimePosition - handleWidth * 0.5 - 4
            let minConstraint: CGFloat = trimRepresentation.startTimePosition + handleWidth * 0.5

            let translatedConstraint = currentPositionConstraint + translation.x
            var newConstraint = translatedConstraint
            if translatedConstraint < minConstraint {
                newConstraint = minConstraint
            }

            if translatedConstraint > maxConstraint {
                newConstraint = maxConstraint
            }
            print("leading: \(newConstraint)")
            positionConstraint?.constant = newConstraint

            let time = getTime(from: newConstraint + assetPreview.contentOffset.x)
            seek(to: time!)
            updateSelectedTime(stoppedMoving: false)

        case .cancelled, .ended, .failed:
            updateSelectedTime(stoppedMoving: false)
        default: break
        }
    }

    // MARK: - Asset loading

    override func assetDidChange(newAsset: AVAsset?) {
        super.assetDidChange(newAsset: newAsset)
    }

    // MARK: - Time Equivalence
    
    public func changeTo(startTime: CMTime, endTime: CMTime) {
        let startTimeSeconds = CMTimeGetSeconds(startTime)
        let endTimeSeconds = CMTimeGetSeconds(endTime)
        
        let middleSeconds = endTimeSeconds - (endTimeSeconds - startTimeSeconds) / 2
        guard let middlePosition = getPosition(from: CMTime(seconds: middleSeconds, preferredTimescale: startTime.timescale)) else {
            return
        }
        
        // Add correct contentOffset (check left first)
        self.assetPreview.contentOffset = CGPoint(x: middlePosition > self.assetPreview.frame.width ? middlePosition - self.assetPreview.frame.width / 2 : 0 , y: self.assetPreview.contentOffset.y)
        
        // Check content offset right
        if (self.assetPreview.contentOffset.x + self.assetPreview.frame.width > self.assetPreview.contentView.frame.width) {
            let diff = self.assetPreview.contentOffset.x + self.assetPreview.frame.width - self.assetPreview.contentView.frame.width
            self.assetPreview.contentOffset = CGPoint(x: self.assetPreview.contentOffset.x - diff, y: self.assetPreview.contentOffset.y)
        }
        
        guard let startPositon = getPosition(from: startTime), let endPosition = getPosition(from: endTime) else {
            return
        }
        let startValue = startPositon - self.assetPreview.contentOffset.x
        let endValue = -(self.assetPreview.frame.width - (endPosition - self.assetPreview.contentOffset.x))
        trimRepresentation.updateTrim(left: startValue, right: endValue)
    }

    /// Move the position bar to the given time.
    public func seek(to time: CMTime) {
        print("seek time: \(time.seconds)")
        if let newPosition = getPosition(from: time) {
            let offsetPosition = newPosition - assetPreview.contentOffset.x
            let maxPosition = trimRepresentation.endTimePosition
            let normalizedPosition = min(max(0, offsetPosition), maxPosition)
            positionConstraint?.constant = normalizedPosition
        }
    }
    
    public func seekToStartTime() {
        let startTimePosition = trimRepresentation.startTimePosition
        positionConstraint?.constant = startTimePosition + handleWidth * 0.5
//        setNeedsUpdateConstraints()
    }
    
    public func seekToEndTime() {
        let startTimePosition = trimRepresentation.endTimePosition
        positionConstraint?.constant = startTimePosition - handleWidth * 0.5 - 4
//        setNeedsUpdateConstraints()
    }
    
    override func getPosition(from time: CMTime) -> CGFloat? {
        guard let asset = asset else {
            return nil
        }
        let timeRatio = CGFloat(time.value) * CGFloat(asset.duration.timescale) /
        (CGFloat(time.timescale) * CGFloat(asset.duration.value))
        return timeRatio * durationSize
    }
    
    override var durationSize: CGFloat {
        let value = super.durationSize - handleWidth
        return value
    }

    /// The selected start time for the current asset.
    public var startTime: CMTime? {
        let startPosition = trimRepresentation.startTimePosition + assetPreview.contentOffset.x + handleWidth * 0.5
//        print(startPosition)
        return getTime(from: startPosition)
    }

    /// The selected end time for the current asset.
    public var endTime: CMTime? {
        let endPosition = trimRepresentation.endTimePosition + assetPreview.contentOffset.x - handleWidth * 0.5
//        print(endPosition)
        return getTime(from: endPosition)
    }

    private func updateSelectedTime(stoppedMoving: Bool) {
        guard let playerTime = positionBarTime else {
            return
        }
        if stoppedMoving {
            delegate?.positionBarStoppedMoving(playerTime)
        } else {
            delegate?.didChangePositionBar(playerTime)
        }
    }

    private var positionBarTime: CMTime? {
        let barPosition = positionBar.frame.origin.x + assetPreview.contentOffset.x
        return getTime(from: barPosition)
    }

    private var minimumDistanceBetweenHandle: CGFloat {
        guard let asset = asset else { return 0 }
        return CGFloat(minDuration) * assetPreview.contentView.frame.width / CGFloat(asset.duration.seconds)
    }

    // MARK: - Scroll View Delegate

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateSelectedTime(stoppedMoving: true)
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateSelectedTime(stoppedMoving: false)
        }
    }
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateSelectedTime(stoppedMoving: false)
        scrollDelegate?.scrollDidMove(scrollView.contentOffset)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitFrame = bounds.insetBy(dx: -5, dy: -10)
        return hitFrame.contains(point) ? super.hitTest(point, with: event) : nil
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitFrame = bounds.insetBy(dx: -5, dy: -10)
        return hitFrame.contains(point)
    }
}

extension TrimmerView: TrimRepresentationDelegate {
    func canTrim(edge: TrimRepresentationEdge, change: CGFloat) -> Bool {
        if edge == .left {
            guard change >= 0 else {
                return false
            }
            let distanceBetweenHandles = trimRepresentation.endTimePosition - change
            return distanceBetweenHandles >= minimumDistanceBetweenHandle
        } else {
            guard change <= assetPreview.bounds.size.width else {
                return false
            }
            let distanceBetweenHandles = change - trimRepresentation.startTimePosition
            return distanceBetweenHandles >= minimumDistanceBetweenHandle
        }
    }
    
    func trimSnapPosition(edge: TrimRepresentationEdge, change: CGFloat) -> CGFloat {
        if edge == .left {
            guard change >= 0 else {
                return 0
            }
            return trimRepresentation.endTimePosition - minimumDistanceBetweenHandle
        } else {
            guard change <= assetPreview.bounds.size.width else {
                return assetPreview.bounds.size.width
            }
            return trimRepresentation.startTimePosition + minimumDistanceBetweenHandle
        }
    }
    
    func trim(edge: TrimRepresentationEdge, change: CGFloat) {
        edge == .left ? seekToStartTime() : seekToEndTime()
        updateSelectedTime(stoppedMoving: false)
    }
    
    func finishedTrimming(edge: TrimRepresentationEdge) {
        updateSelectedTime(stoppedMoving: true)
    }
}
