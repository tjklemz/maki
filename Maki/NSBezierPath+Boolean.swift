//
//  NSBezierPath+Boolean.swift
//  Maki
//
//  Created by Thomas Klemz on 1/3/18.
//  Copyright © 2018 Lory & Ludlow. All rights reserved.
//

import Cocoa

struct Intersection {
    let t1: CGFloat
    let t2: CGFloat
}

extension Intersection: Equatable {
    static func ==(lhs: Intersection, rhs: Intersection) -> Bool {
        return lhs.t1 == rhs.t1 && lhs.t2 == rhs.t2
    }
}

extension Intersection: Hashable {
    public var hashValue: Int {
        return self.t1.hashValue << (MemoryLayout<CGFloat>.size ^ self.t2.hashValue)
    }
}

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

func split(_ points: Curve, t: [CGFloat]) -> [Curve] {
    let u = split(t: t)
    var parts = [Curve]()
    var el = points
    
    for s in u {
        let splits = split(el, t: s)
        parts.append(splits[0])
        el = splits[1]
    }
    parts.append(el)
    return parts
}

func split(t: [CGFloat]) -> [CGFloat] {
    var u = t

    for i in 1..<t.count {
        u[i] = (t[i] - t[i-1])/(1 - t[i-1])
    }
    
    return u
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
    return NSRect(x: x_min, y: y_min, width: w > 0 ? w : 0.00001, height: h > 0 ? h : 0.00001)
}

public extension NSBezierPath {
    func elements() -> [Curve] {
        var cur = NSPoint()
        var els = [Curve]()
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
                cur = points[2]
            case .closePathBezierPathElement:
                guard let first = els.first?.first else { break }
                let path = lineToCurve(cur, first)
                els.append(path)
                cur = first
            }
        }
        
        return els
    }
    
    func intersections(_ el: Curve, _ otherEl: Curve, t: (ClosedRange<CGFloat>, ClosedRange<CGFloat>) = (0...1, 0...1)) -> [(ClosedRange<CGFloat>, ClosedRange<CGFloat>)] {
        let threshold : CGFloat = 0.000001

        let rect = hull(el)
        let otherRect = hull(otherEl)
        
        guard rect.intersects(otherRect) else {
            return []
        }

        if t.0.upperBound - t.0.lowerBound < threshold && t.1.upperBound - t.1.lowerBound < threshold {
            return [t]
        }

        let split1 = split(el, t: 0.5)
        let split2 = split(otherEl, t: 0.5)
        
        let t0_d = (t.0.upperBound - t.0.lowerBound)/2
        let t0_l = t.0.lowerBound...(t.0.lowerBound + t0_d)
        let t0_u = (t.0.lowerBound + t0_d)...t.0.upperBound

        let t1_d = (t.1.upperBound - t.1.lowerBound)/2
        let t1_l = t.1.lowerBound...(t.1.lowerBound + t1_d)
        let t1_u = (t.1.lowerBound + t1_d)...t.1.upperBound

        var inters = [(ClosedRange<CGFloat>, ClosedRange<CGFloat>)]()
        inters.append(contentsOf: intersections(split1[0], split2[0], t: (t0_l, t1_l) ))
        inters.append(contentsOf: intersections(split1[0], split2[1], t: (t0_l, t1_u) ))
        inters.append(contentsOf: intersections(split1[1], split2[0], t: (t0_u, t1_l) ))
        inters.append(contentsOf: intersections(split1[1], split2[1], t: (t0_u, t1_u) ))
        return inters
    }
    
    public func intersections(with other: NSBezierPath) -> [NSPoint] {
        let els = self.elements()
        let otherEls = other.elements()
        let mult: CGFloat = 100
        var inters = [NSPoint]()

        for el in els {
            let rect = hull(el)

            for otherEl in otherEls {
                let otherRect = hull(otherEl)

                if rect.intersects(otherRect) {
                    let intersects = self.intersections(el, otherEl).map({ (inter) -> Intersection in
                        return Intersection(t1: round(mult*inter.0.lowerBound)/mult, t2: round(mult*inter.1.lowerBound)/mult)
                    })
                    // have intersections as as (el_t, otherEl_t)
                    // now need to split the curves
                    //print("intersects", Set<Intersection>(intersects))
                    inters.append(contentsOf: Set<Intersection>(intersects).map({ (inter) -> NSPoint in
                        return point(el, inter.t1)
                    }))
                }
            }
        }
        print("intersections", inters)
        return inters
    }
}
