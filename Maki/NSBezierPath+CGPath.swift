//
//  NSBezierPath+CGPath.swift
//  Maki
//
//  Created by Thomas Klemz on 12/28/17.
//  Copyright © 2017 Lory & Ludlow. All rights reserved.
//

import Cocoa
import CoreGraphics

public extension NSBezierPath {
    public var cgPath : CGPath {
        let path = CGMutablePath()
        var didClose = true
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveToBezierPathElement:
                path.move(to: points[0])
            case .lineToBezierPathElement:
                didClose = false
                path.addLine(to: points[0])
            case .curveToBezierPathElement:
                didClose = false
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePathBezierPathElement:
                didClose = true
                path.closeSubpath()
            }
        }
        
        if (!didClose) {
            path.closeSubpath()
        }
        
        return path
    }
    
    public var lineCap : CGLineCap {
        switch lineCapStyle {
        case .buttLineCapStyle:
            return CGLineCap.butt
        case .roundLineCapStyle:
            return CGLineCap.round
        case .squareLineCapStyle:
            return CGLineCap.square
        }
    }
    
    public var lineJoin : CGLineJoin {
        switch lineJoinStyle {
        case .bevelLineJoinStyle:
            return CGLineJoin.bevel
        case .miterLineJoinStyle:
            return CGLineJoin.miter
        case .roundLineJoinStyle:
            return CGLineJoin.round
        }
    }
    
    public var targetRect : CGRect {
        let s = lineWidth + 1
        return bounds.insetBy(dx: -s, dy: -s)
    }
    
    func outlinePath() -> CGPath {
        return cgPath.copy(strokingWithWidth: max(35, lineWidth), lineCap: lineCap, lineJoin: lineJoin, miterLimit: miterLimit)
    }
}

