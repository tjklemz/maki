//
//  Canvas.swift
//  Maki
//
//  Created by Thomas Klemz on 12/19/17.
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

struct Selection {
    var element : NSBezierPath
    var offset : NSPoint
    
    init(element: NSBezierPath, point: NSPoint) {
        self.element = element
        self.offset = NSPoint(x: element.bounds.minX - point.x, y: element.bounds.minY - point.y)
    }
    
    func move(to point: NSPoint) -> NSRect {
        let oldBounds = element.targetRect
        element.transform(using: AffineTransform(translationByX: point.x - element.bounds.minX + offset.x, byY: point.y - element.bounds.minY + offset.y))
        return element.targetRect.union(oldBounds)
    }
}

struct Frame {
    var elements : [NSBezierPath] = []
}

extension Canvas {
    var center : NSPoint {
        get {
            return NSPoint(x: NSMidX(self.bounds), y: NSMidY(self.bounds))
        }
    }
}

class Canvas: NSView {
    var frames : [Frame] = [Frame()]
    var current = 0
    var selection : Selection?

    override var preservesContentDuringLiveResize : Bool {
        get {
            return true
        }
    }
    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // draw background
        NSColor.white.set()
        let path = NSBezierPath(rect: dirtyRect)
        path.fill()
        
        NSColor.blue.setFill()
        NSColor.black.setStroke()
        
        for el in frames[current].elements {
            if needsToDraw(el.targetRect) {
                el.fill()
                el.stroke()
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        for el in frames[current].elements.reversed() {
            guard el.targetRect.contains(point) else {
                continue
            }
            // TODO: have list of outlinePaths (tapTargets) so we don't create each time
            //  Then there won't be two checks, since the shape will be cached
            if el.contains(point) || el.outlinePath().contains(point) {
                selection = Selection(element: el, point: point)
                return
            }
        }
        selection = nil
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let selection = selection else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let bounds = selection.move(to: point)
        setNeedsDisplay(bounds)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let rect = selection?.element.bounds else {
            return
        }
        setNeedsDisplay(rect)
    }
    
    override func keyDown(with event: NSEvent) {
        if let key = event.characters?.first {
            switch key {
            case "1":
                addShape(createLine())
                return
            case "2":
                addShape(createCircle())
                return
            case "3":
                addShape(createTriangle())
                return
            case "4":
                addShape(createRect())
                return
            case ".":
                nextFrame()
                print("frame", current)
                return
            case ",":
                prevFrame()
                print("frame", current)
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }
    
    func centerRect() -> NSRect {
        let center = self.center
        let s = self.bounds.width / 4
        let rect = NSRect(x: center.x - s/2, y: center.y - s/2, width: s, height: s)
        return rect
    }
    
    func createLine() -> NSBezierPath {
        let rect = centerRect()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY))
        return path
    }
    
    func createCircle() -> NSBezierPath {
        let rect = centerRect()
        let path = NSBezierPath(ovalIn: rect)
        return path
    }
    
    func createTriangle() -> NSBezierPath {
        let rect = centerRect()
        let s = rect.height
        let d = s*sqrt(3)/3 // half of the length of equilateral triangle that is of height, rect.height
        let path = NSBezierPath()
        path.move(to: NSPoint(x: NSMidX(rect), y: rect.maxY))
        path.relativeLine(to: NSPoint(x: d, y: -s))
        path.relativeLine(to: NSPoint(x: -d*2, y: 0))
        path.close()
        return path
    }
    
    func createRect() -> NSBezierPath {
        let rect = centerRect()
        let path = NSBezierPath(rect: rect)
        return path
    }
    
    func addShape(_ path: NSBezierPath) {
        frames[current].elements.append(path)
        setNeedsDisplay(path.bounds)
    }
    
    func nextFrame() {
        current += 1
        if (current >= frames.count) {
            let frame = Frame()
            frames.append(frame)
        }
        setNeedsDisplay(bounds)
    }
    
    func prevFrame() {
        current -= 1
        if (current < 0) {
            current = 0
        }
        setNeedsDisplay(bounds)
    }
}
