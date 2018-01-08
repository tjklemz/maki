//
//  NSBezierPath+Boolean.swift
//  Maki
//
//  Created by Thomas Klemz on 1/3/18.
//  Copyright © 2018 Lory & Ludlow. All rights reserved.
//

import Cocoa

extension NSPoint: Hashable {
    public var hashValue: Int {
        return self.x.hashValue << (MemoryLayout<CGFloat>.size ^ self.y.hashValue)
    }
}

extension NSPoint {
    public func isCloseTo(_ other: NSPoint) -> Bool {
        return abs(x - other.x) < 1 && abs(y - other.y) < 1
    }
}

public typealias Curve = [NSPoint]
public typealias Intersection = (ClosedRange<CGFloat>, ClosedRange<CGFloat>)

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
    var parts = [Curve]()
    var el = points
    
    for u in split(t: t) {
        let splits = split(el, t: u)
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

func direction(_ points: Curve, point: NSPoint) -> Curve? {
    if points[0].isCloseTo(point) {
        return points
    }
    if points[3].isCloseTo(point) {
        return points.reversed()
    }
    return nil
}

public extension NSBezierPath {
    convenience init?(points: Curve) {
        guard points.count == 2 || points.count == 4 else {
            return nil
        }
        self.init()
        let p = points.count == 2 ? lineToCurve(points[0], points[1]) : points
        self.move(to: p[0])
        self.curve(to: p[3], controlPoint1: p[1], controlPoint2: p[2])
    }

    convenience init(parts: [Curve]) {
        self.init()

        // debug
        for part in parts {
            print("first", part[0], "last", part[3])
        }

        var els = parts

        var first = els.removeFirst()
        self.move(to: first[0])
        self.curve(to: first[3], controlPoint1: first[1], controlPoint2: first[2])

        var cur = first[3]

        while parts.count > 0 {
            var found = false
            for i in 0..<els.count {
                if let el = direction(els[i], point: cur) {
                    self.curve(to: el[3], controlPoint1: el[1], controlPoint2: el[2])
                    cur = el[3]
                    els.remove(at: i)
                    found = true
                    break
                }
            }
            if !found {
                break
            }
        }
    }

    public func elements() -> [Curve] {
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
    
    func intersections(_ el: Curve, _ otherEl: Curve, t: Intersection = (0...1, 0...1)) -> [Intersection] {
        let threshold : CGFloat = 0.0001

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

        return intersections(split1[0], split2[0], t: (t0_l, t1_l))
             + intersections(split1[0], split2[1], t: (t0_l, t1_u))
             + intersections(split1[1], split2[0], t: (t0_u, t1_l))
             + intersections(split1[1], split2[1], t: (t0_u, t1_u))
    }
    
    public func intersections(with other: NSBezierPath) -> (ours: [Curve], theirs: [Curve], points: [NSPoint]) {
        let els = self.elements()
        let otherEls = other.elements()
        let mult: CGFloat = 1000
        var points = Set<NSPoint>()
        var elSplits = [Int: Set<CGFloat>]()
        var otherElSplits = [Int: Set<CGFloat>]()

        for (i, el) in els.enumerated() {
            for (j, otherEl) in otherEls.enumerated() {
                let intersects = self.intersections(el, otherEl)

                guard intersects.count > 0 else { continue }

                let t1 = Set(intersects.map({ round(mult*$0.0.lowerBound) / mult }))
                let t2 = Set(intersects.map({ round(mult*$0.1.lowerBound) / mult }))

                points = points.union(t1.map({ point(el, $0) }))

                let elSplit = elSplits[i] ?? Set<CGFloat>()
                elSplits[i] = elSplit.union(t1)

                let otherElSplit = otherElSplits[j] ?? Set<CGFloat>()
                otherElSplits[j] = otherElSplit.union(t2)
            }
        }

        let ours = els.enumerated().flatMap { (n, el) -> [Curve] in
            guard let splits = elSplits[n] else {
                return [el]
            }
            return split(el, t: splits.sorted())
        }

        let theirs = otherEls.enumerated().flatMap { (n, el) -> [Curve] in
            guard let splits = otherElSplits[n] else {
                return [el]
            }
            return split(el, t: splits.sorted())
        }

        // debug
        print("ours", ours.count, "theirs", theirs.count)

        return (ours: ours, theirs: theirs, points: Array(points))
    }
    
    public func union(with other: NSBezierPath) -> NSBezierPath {
        let (ours, theirs, _) = intersections(with: other)
        let parts = ours.filter{ !other.contains(point($0, 0.5)) } + theirs.filter { !self.contains(point($0, 0.5)) }
        return NSBezierPath(parts: parts)
    }
}
