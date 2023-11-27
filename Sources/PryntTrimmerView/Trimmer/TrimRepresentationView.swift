//
//  File.swift
//  
//
//  Created by Victor Tatarasanu on 21.11.2023.
//

import Foundation
import UIKit

enum TrimRepresentationEdge {
    case left, right
}

protocol TrimRepresentationDelegate: NSObject {
    func canTrim(edge: TrimRepresentationEdge, change: CGFloat) -> Bool
    func trim(edge: TrimRepresentationEdge, change: CGFloat)
    func finishedTrimming(edge: TrimRepresentationEdge)
    func trimSnapPosition(edge: TrimRepresentationEdge, change: CGFloat) -> CGFloat
}

public class TrimRepresentationView: UIView {
    weak var delegate: TrimRepresentationDelegate?
    private let leftHandleView: HandleView = .init(position: .left)
    private let rightHandleView: HandleView = .init(position: .right)
    private let trimmedAreaView: UIView = .init()
    private let maskLayer: CAShapeLayer = CAShapeLayer()
    private let maskingView: UIView = .init()
    
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    
    private var currentLeftPosition: CGFloat = .zero {
        didSet {
            print("left: \(currentLeftPosition)")
        }
    }
    private var currentRightPosition: CGFloat = .zero {
        didSet {
            print("right: \(currentRightPosition)")
        }
    }
    
    var editablePositionRange: ClosedRange<CGFloat> {
        return leftHandleView.center.x...rightHandleView.center.x
    }
    
    var availableEditableRange: ClosedRange<CGFloat> {
        frame.minX...frame.maxX
    }
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        layer.cornerRadius = 16
        clipsToBounds = false
        backgroundColor = .clear
        maskingView.backgroundColor = .clear
        
        maskingView.translatesAutoresizingMaskIntoConstraints = false
        maskingView.clipsToBounds = true
        maskingView.layer.cornerRadius = 16
        addSubview(maskingView)
        
        trimmedAreaView.backgroundColor = .clear
        trimmedAreaView.layer.cornerRadius = 16
        trimmedAreaView.clipsToBounds = true
        trimmedAreaView.translatesAutoresizingMaskIntoConstraints = false
        trimmedAreaView.layer.borderWidth = 3
        trimmedAreaView.layer.borderColor = UIColor.white.cgColor
        
        addSubview(trimmedAreaView)
        
        leftHandleView.translatesAutoresizingMaskIntoConstraints = false
        rightHandleView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(leftHandleView)
        addSubview(rightHandleView)
        
        NSLayoutConstraint.activate([
            leftHandleView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.66),
            leftHandleView.widthAnchor.constraint(equalToConstant: 10),
            leftHandleView.centerXAnchor.constraint(equalTo: trimmedAreaView.leadingAnchor),
            leftHandleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            rightHandleView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.66),
            rightHandleView.widthAnchor.constraint(equalToConstant: 10),
            rightHandleView.centerXAnchor.constraint(equalTo: trimmedAreaView.trailingAnchor),
            rightHandleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            trimmedAreaView.topAnchor.constraint(equalTo: topAnchor),
            trimmedAreaView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            maskingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            maskingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            maskingView.topAnchor.constraint(equalTo: topAnchor),
            maskingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        self.leadingConstraint = trimmedAreaView.leadingAnchor.constraint(equalTo: self.leadingAnchor)
        self.trailingConstraint = trimmedAreaView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        
        self.leadingConstraint?.isActive = true
        self.trailingConstraint?.isActive = true
        
        setupGestures()
        setupMaskLayer()
    }
    
    private func setupGestures() {
        let leftPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TrimRepresentationView.handlePanGesture))
        leftHandleView.addGestureRecognizer(leftPanGestureRecognizer)
        let rightPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TrimRepresentationView.handlePanGesture))
        rightHandleView.addGestureRecognizer(rightPanGestureRecognizer)
    }
    
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let view = gestureRecognizer.view, let superview = gestureRecognizer.view?.superview else { return }
        let isLeftGesture = view == leftHandleView
        
        switch gestureRecognizer.state {
            case .began:
                if isLeftGesture {
                    currentLeftPosition = editablePositionRange.lowerBound
                } else {
                    currentRightPosition = editablePositionRange.upperBound
                }
            case .changed:
                let translation = gestureRecognizer.translation(in: superview)
                
                if isLeftGesture {
                    updateLeftHandle(translation: translation)
                } else {
                    updateRightHandle(translation: translation)
                }
            case .cancelled, .ended, .failed:
                delegate?.finishedTrimming(edge: isLeftGesture ? .left : .right)
            default: break
        }
    }
    
    private func updateLeftHandle(translation: CGPoint) {
        let change = currentLeftPosition + translation.x
        
        if delegate?.canTrim(edge: .left, change: change) == true {
            delegate?.trim(edge: .left, change: change)
            leadingConstraint?.constant = change
        } else if let min = delegate?.trimSnapPosition(edge: .left, change: change) {
            delegate?.trim(edge: .left, change: min)
            leadingConstraint?.constant = min
        }
        layoutIfNeeded()
    }
    
    private func updateRightHandle(translation: CGPoint) {
        let change = currentRightPosition + translation.x
        
        if delegate?.canTrim(edge: .right, change: change) == true {
            trailingConstraint?.constant = change - self.bounds.width
            delegate?.trim(edge: .right, change: change)
        } else if let max = delegate?.trimSnapPosition(edge: .right, change: change) {
            let trailing = max - self.bounds.width
            trailingConstraint?.constant = trailing
            delegate?.trim(edge: .right, change: trailing)
        }
    }
    
    private func setupMaskLayer() {
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        maskLayer.fillRule = .evenOdd
        maskLayer.cornerRadius = 16
        maskingView.layer.addSublayer(maskLayer)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateTrimmedArea()
    }
    
    private func updateTrimmedArea() {
        let path = UIBezierPath(rect: bounds)
        let clearPath = UIBezierPath(roundedRect: trimmedAreaView.frame, cornerRadius: 16).reversing()
        path.append(clearPath)
        maskLayer.path = path.cgPath
    }
    
    public func updateTrim(left: CGFloat, right: CGFloat) {
        self.leadingConstraint?.constant = left
        self.trailingConstraint?.constant = right
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitFrame = bounds.insetBy(dx: -10, dy: -10)
        return hitFrame.contains(point) ? super.hitTest(point, with: event) : nil
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitFrame = bounds.insetBy(dx: -10, dy: -10)
        return hitFrame.contains(point)
    }
}

class HandleView: UIView {
    enum HandlerPosition {
        case left
        case right
    }
    var position: HandlerPosition
    var knob: UIView = .init()
    
    init(position: HandlerPosition) {
        self.position = position
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        knob.translatesAutoresizingMaskIntoConstraints = false
        addSubview(knob)
        
        NSLayoutConstraint.activate([
            knob.centerYAnchor.constraint(equalTo: centerYAnchor),
            knob.centerXAnchor.constraint(equalTo: centerXAnchor),
            knob.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5),
            knob.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),
        ])
        
        knob.backgroundColor = .black
        backgroundColor = .white
        
        layer.cornerRadius = 4
        knob.layer.cornerRadius = 2
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitFrame = CGRect(x: position == .left ? -bounds.width * 0.5 : 0, y: -bounds.height * 0.5, width: bounds.width * 1.5, height: bounds.height * 1.5)
        return hitFrame.contains(point) ? self : nil
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitFrame = CGRect(x: position == .left ? -bounds.width * 0.5 : 0, y: -bounds.height * 0.5, width: bounds.width * 1.5, height: bounds.height * 1.5)
        return hitFrame.contains(point)
    }
}
