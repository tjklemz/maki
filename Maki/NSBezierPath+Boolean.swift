//
//  NSBezierPath+Boolean.swift
//  Maki
//
//  Created by Thomas Klemz on 1/3/18.
//  Copyright © 2018 Lory & Ludlow. All rights reserved.
//

import Cocoa

extension Array {
    func splitCurve(at t: CGFloat) -> ([NSPoint], [NSPoint]) {
        let p = self as! [NSPoint]
        let (x1, y1) = (p[0].x, p[0].y)
        let (x2, y2) = (p[1].x, p[1].y)
        let (x3, y3) = (p[2].x, p[2].y)
        let (x4, y4) = (p[3].x, p[3].y)
        
        let x12 = (x2-x1)*t+x1
        let y12 = (y2-y1)*t+y1

        let x23 = (x3-x2)*t+x2
        let y23 = (y3-y2)*t+y2

        let x34 = (x4-x3)*t+x3
        let y34 = (y4-y3)*t+y3
    
        let x123 = (x23-x12)*t+x12
        let y123 = (y23-y12)*t+y12
    
        let x234 = (x34-x23)*t+x23
        let y234 = (y34-y23)*t+y23

        let x1234 = (x234-x123)*t+x123
        let y1234 = (y234-y123)*t+y123
        
        let mid = NSPoint(x: x1234, y: y1234)
        
        return (
            [p[0], NSPoint(x: x12, y: y12), NSPoint(x: x123, y: y123), mid],
            [mid, NSPoint(x: x234, y: y234), NSPoint(x: x34, y: y34), p[3]]
        )
    }

    func point(at t: CGFloat) -> NSPoint {
        let p = self as! [NSPoint]
        let c0: CGFloat = (1-t)*(1-t)*(1-t)
        let c1: CGFloat = 3 * (1-t)*(1-t) * t
        let c2: CGFloat = 3 * (1-t) * t*t
        let c3: CGFloat = t*t*t

        return NSPoint(x: c0*p[0].x + c1*p[1].x + c2*p[2].x + c3*p[3].x,
                       y: c0*p[0].y + c1*p[1].y + c2*p[2].y + c3*p[3].y)
    }

    func rect(_ t: ClosedRange<CGFloat> = (0...1)) -> NSRect {
        let p = self as! [NSPoint]
        let split1 = t.lowerBound == 0 ? p : self.splitCurve(at: t.lowerBound).1
        let split2 = t.upperBound == 1 ? p : self.splitCurve(at: t.upperBound).0
        let points = [split1[0], split1[1], split2[2], split2[3]]
        
        let x1 = points.min(by: { (a, b) -> Bool in a.x < b.x })!.x
        let y1 = points.min(by: { (a, b) -> Bool in a.y < b.y })!.y
        let x2 = points.max(by: { (a, b) -> Bool in a.x < b.x })!.x
        let y2 = points.max(by: { (a, b) -> Bool in a.y < b.y })!.y
        
        let w = x2 - x1
        let h = y2 - y1

        return NSRect(x: x1, y: y1, width: w > 0 ? w : 0.25, height: h > 0 ? h : 0.25)
    }
}

public extension NSBezierPath {
    func lineToPath(_ start: NSPoint, _ end: NSPoint) -> [NSPoint] {
        let scale: CGFloat = 0.333333
        let dy = scale*(end.y - start.y)
        let dx = scale*(end.x - start.x)
        let cp1 = NSPoint(x: start.x + dx, y: start.y + dy)
        let cp2 = NSPoint(x: end.x - dx, y: end.y - dy)
        return [start, cp1, cp2, end]
    }

    public func elements() -> [[NSPoint]] {
        var cur = NSPoint()
        var els = [[NSPoint]]()
        let points = NSPointArray.allocate(capacity: 3)

        for i in 0..<self.elementCount {
            let type = self.element(at: i, associatedPoints: points)
            switch type {
            case .moveToBezierPathElement:
                cur = points[0]
            case .lineToBezierPathElement:
                let path = lineToPath(cur, points[0])
                els.append(path)
                cur = points[0]
            case .curveToBezierPathElement:
                els.append([cur, points[0], points[1], points[2]])
                cur = points[0]
            case .closePathBezierPathElement:
                guard let first = els.first?.first else { break }
                let path = lineToPath(cur, first)
                els.append(path)
                cur = first
            }
        }
        
        return els
    }
    
    func intersections(_ el: [NSPoint], _ otherEl: [NSPoint], t: (ClosedRange<CGFloat>, ClosedRange<CGFloat>) = (0...1, 0...1)) -> [(CGFloat, CGFloat)] {
        let threshold : CGFloat = 0.1

        let rect = el.rect(t.0)
        let otherRect = otherEl.rect(t.1)
        
        if !otherRect.intersects(rect) {
            return []
        }

        if t.0.upperBound - t.0.lowerBound < threshold && t.1.upperBound - t.1.lowerBound < threshold {
            return [(t.0.lowerBound, t.1.lowerBound)]
        }

        let t0_l = t.0.lowerBound...((t.0.upperBound - t.0.lowerBound)/2 + t.0.lowerBound)
        let t1_l = t.1.lowerBound...((t.1.upperBound - t.1.lowerBound)/2 + t.1.lowerBound)
        let t0_u = (t.0.upperBound - (t.0.upperBound - t.0.lowerBound)/2)...t.0.upperBound
        let t1_u = (t.1.upperBound - (t.1.upperBound - t.1.lowerBound)/2)...t.1.upperBound

        var intersects = [(CGFloat, CGFloat)]()
        intersects.append(contentsOf: intersections(el, otherEl, t: (t0_l, t1_l)))
        intersects.append(contentsOf: intersections(el, otherEl, t: (t0_l, t1_u)))
        intersects.append(contentsOf: intersections(el, otherEl, t: (t0_u, t1_l)))
        intersects.append(contentsOf: intersections(el, otherEl, t: (t0_u, t1_u)))
        return intersects
    }
    
    public func intersections(with other: NSBezierPath) {
        let els = self.elements()
        let otherEls = other.elements()

        for el in els {
            let rect = el.rect()

            for otherEl in otherEls {
                let otherRect = otherEl.rect()
                
                if otherRect.intersects(rect) {
                    let intersects = self.intersections(el, otherEl)
                    // have intersections as as (el_t, otherEl_t)
                    // now need to split the curves
                    print("intersects", intersects)
                }
            }
        }
    }
}
