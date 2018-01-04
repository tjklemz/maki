//
//  NSBezierPath+Boolean.swift
//  Maki
//
//  Created by Thomas Klemz on 1/3/18.
//  Copyright © 2018 Lory & Ludlow. All rights reserved.
//

import Cocoa

public typealias Curve = [NSPoint]

func point(_ points: Curve, _ t: CGFloat) -> NSPoint {
    let c0: CGFloat = (1-t)*(1-t)*(1-t)
    let c1: CGFloat = 3 * (1-t)*(1-t) * t
    let c2: CGFloat = 3 * (1-t) * t*t
    let c3: CGFloat = t*t*t
    
    return NSPoint(x: c0*points[0].x + c1*points[1].x + c2*points[2].x + c3*points[3].x,
                   y: c0*points[0].y + c1*points[1].y + c2*points[2].y + c3*points[3].y)
}

func interp(_ a: NSPoint, _ b: NSPoint, _ t: CGFloat) -> NSPoint {
    return NSPoint(x: (1-t)*a.x + t*b.x,
                   y: (1-t)*a.y + t*b.y)
}

func split(_ points: Curve, t: CGFloat) -> [Curve] {
    let p1 = interp(points[0], points[1], t)
    let p2 = interp(points[1], points[2], t)
    let p3 = interp(points[2], points[3], t)
    
    let p4 = interp(p1, p2, t)
    let p5 = interp(p2, p3, t)
    let p = interp(p4, p5, t) // the actual point on the curve

    return [
        [points[0], p1, p4, p],
        [p, p5, p3, points[3]]
    ]
}

func lineToCurve(_ start: NSPoint, _ end: NSPoint) -> Curve {
    let t: CGFloat = 1.0 / 3.0
    return [start, interp(start, end, t), interp(start, end, 1-t), end]
}

func hull(_ points: Curve) -> NSRect {
    let x = points.map { return $0.x }
    let y = points.map { return $0.y }
    let x_max = x.max()!
    let x_min = x.min()!
    let y_max = y.max()!
    let y_min = y.min()!
    let w = x_max - x_min
    let h = y_max - y_min
    return NSRect(x: x_min, y: y_min, width: w > 0 ? w : 0.25, height: h > 0 ? h : 0.25)
}

public extension NSBezierPath {
    func elements() -> [Curve] {
        var cur = NSPoint()
        var els = [[NSPoint]]()
        let points = NSPointArray.allocate(capacity: 3)

        for i in 0..<self.elementCount {
            let type = self.element(at: i, associatedPoints: points)
            switch type {
            case .moveToBezierPathElement:
                cur = points[0]
            case .lineToBezierPathElement:
                let path = lineToCurve(cur, points[0])
                els.append(path)
                cur = points[0]
            case .curveToBezierPathElement:
                els.append([cur, points[0], points[1], points[2]])
                cur = points[0]
            case .closePathBezierPathElement:
                guard let first = els.first?.first else { break }
                let path = lineToCurve(cur, first)
                els.append(path)
                cur = first
            }
        }
        
        return els
    }
    
    func intersections(_ el: Curve, _ otherEl: Curve) -> Bool {
        let threshold : CGFloat = 0.01

        let rect = hull(el)
        let otherRect = hull(otherEl)
        
        guard otherRect.intersects(rect) else {
            return false
        }

        if rect.width*rect.height + otherRect.width*otherRect.height < threshold {
            return true
        }
        
        let split1 = split(el, t: 0.5)
        let split2 = split(otherEl, t: 0.5)
        
        return intersections(split1[0], split2[0])
            || intersections(split1[0], split2[1])
            || intersections(split1[1], split2[0])
            || intersections(split1[1], split2[1])
    }
    
    public func intersections(with other: NSBezierPath) {
        let els = self.elements()
        let otherEls = other.elements()

        for el in els {
            let rect = hull(el)

            for otherEl in otherEls {
                let otherRect = hull(otherEl)
                
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
