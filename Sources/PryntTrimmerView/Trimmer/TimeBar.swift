//
//  File.swift
//  
//
//  Created by Victor Tatarasanu on 23.11.2023.
//

import Foundation
import UIKit

class TimeBar: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitFrame = bounds.insetBy(dx: -5, dy: -10)
        return hitFrame.contains(point) ? self : nil
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitFrame = bounds.insetBy(dx: -5, dy: -10)
        return hitFrame.contains(point)
    }

}
