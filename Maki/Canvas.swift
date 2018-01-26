//
//  Canvas.swift
//  Maki
//
//  Created by Thomas Klemz on 12/19/17.
//  Copyright © 2017 Lory & Ludlow. All rights reserved.
//

import Cocoa
import CoreGraphics

struct Symbol {
    let uuid: String
    var path: NSBezierPath
    var transform: AffineTransform?
}

extension Symbol {
    init(uuid: String, path: NSBezierPath) {
        self.init(uuid: uuid, path: path, transform: nil)
    }

    init(_ path: NSBezierPath) {
        self.init(uuid: UUID().uuidString, path: path)
    }
    
    init(_ symbol: Symbol) {
        self.init(uuid: symbol.uuid, path: symbol.path.copy() as! NSBezierPath, transform: symbol.transform)
    }
}

extension Symbol {
    var transformedPath: NSBezierPath {
        if let transform = self.transform {
            let path = self.path.copy() as! NSBezierPath
            let cx = NSMidX(path.bounds)
            let cy = NSMidY(path.bounds)
            path.transform(using: AffineTransform(translationByX: -cx, byY: -cy))
            path.transform(using: transform)
            path.transform(using: AffineTransform(translationByX: cx, byY: cy))
            return path
        }
        return self.path
    }

    func contains(_ point: NSPoint) -> Bool {
        // TODO: stroke issues should be handled by entirely separate paths, instead of Postscript style strokes
        let path = self.transformedPath
        return path.targetRect.contains(point) && path.contains(point)
    }
    
    var bounds: NSRect {
        return self.transformedPath.bounds
    }
}

struct Selection {
    var symbol: Symbol
    var point: NSPoint
    
    mutating func move(to point: NSPoint) -> NSRect {
        let bounds = symbol.bounds
        let dx = self.point.x - point.x
        let dy = self.point.y - point.y
        symbol.path.transform(using: AffineTransform(translationByX: -dx, byY: -dy))
        self.point = point
        return symbol.bounds.union(bounds).insetBy(dx: -5, dy: -5)
    }
}

struct Frame {
    var elements = [Symbol]()
}

extension Frame {
    init(_ frame: Frame?) {
        if let elements = frame?.elements.map({ return Symbol($0) }) {
            self.init(elements: elements)
        } else {
            self.init()
        }
    }
}

extension Canvas {
    var center: NSPoint {
        return NSPoint(x: NSMidX(self.bounds), y: NSMidY(self.bounds))
    }
}

class Canvas: NSView {
    var frames = [Frame()]
    var current = 0
    var selection: Selection?
    var intersections = [NSPoint]() {
        didSet {
            self.setNeedsDisplay(bounds)
        }
    }
    var transformTool = false
    var originalPoint = NSPoint()

    override var preservesContentDuringLiveResize : Bool {
        return true
    }
    override var acceptsFirstResponder: Bool {
        return true
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
            let path = el.transformedPath
            if needsToDraw(path.targetRect) {
                path.fill()
                path.stroke()
            }
        }

        NSColor.red.setStroke()
        
        for inter in intersections {
            let path = NSBezierPath(ovalIn: NSRect(origin: NSPoint(x: inter.x - 5, y: inter.y - 5), size: CGSize(width: 10, height: 10)))
            path.stroke()
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let count = frames[current].elements.count

        guard transformTool && count > 0 else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)

        let path = frames[current].elements[count - 1].path
        let p = originalPoint
        
        let cx = NSMidX(path.bounds)
        let cy = NSMidY(path.bounds)
        let dx = point.x - cx
        let dy = point.y - cy
        let dist = max(sqrt((p.x - cx)*(p.x - cx) + (p.y - cy)*(p.y - cy)), 1)
        let newDist = sqrt(dx*dx + dy*dy)
        let scale = max(newDist / dist, 0.2)
        var angle: CGFloat = 180*atan(dy/dx) / CGFloat.pi
        if angle.isNaN {
            angle = 0
        } else if angle.isInfinite {
            angle = angle < 0 ? -90 : 90
        }

        var transform = AffineTransform()
        transform.rotate(byDegrees: angle)
        transform.scale(x: scale, y: 1 / scale)
        transform.rotate(byDegrees: -angle)

        frames[current].elements[count - 1].transform = transform

        setNeedsDisplay(self.bounds)
        return
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if transformTool {
            transformTool = false
            originalPoint = NSPoint()
            setNeedsDisplay(self.bounds)
            return
        }

        for el in frames[current].elements.reversed() {
            if el.contains(point) {
                selection = Selection(symbol: el, point: point)
                setNeedsDisplay(self.bounds)
                return
            }
        }
        selection = nil
        setNeedsDisplay(self.bounds)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let bounds = selection?.move(to: point) {
            setNeedsDisplay(bounds)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let rect = selection?.symbol.path.bounds else {
            return
        }
        setNeedsDisplay(rect)
    }
    
    override func keyDown(with event: NSEvent) {
        let hasOption = event.modifierFlags.contains(.option)
        let hasCommand = event.modifierFlags.contains(.command)

        if let key = event.charactersIgnoringModifiers?.first {
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
            case "q":
                let count = frames[current].elements.count
                if !transformTool && count > 0 {
                    let point = convert(event.locationInWindow, from: nil)
                    transformTool = true
                    originalPoint = point
                }
                return
            case "b":
                let path = NSBezierPath(rect: self.bounds)
                addShape(Symbol(path))
                return
            case "t":
                let t: [CGFloat] = [1/6.0, 2/6.0, 3/6.0, 4/6.0, 5/6.0]
                print("t", t)
                let els = createCircle().path.elements()
                for el in els {
                    for points in split(el, t: t) {
                        let path = NSBezierPath(points: points)
                        addShape(Symbol(path!))
                    }
                }
                return
            case "u", "i", "d", "x":
                let els = frames[current].elements
                let len = els.count
                guard len > 1 else { return }
                let top = els[len - 1]
                let bottom = els[len - 2]
                let start = NSDate()
                //self.intersections = top.path.intersections(with: bottom.path).points
                let result: NSBezierPath = {
                    switch key {
                    case "u":
                        return top.transformedPath.union(with: bottom.transformedPath)
                    case "i":
                        return top.transformedPath.intersect(with: bottom.transformedPath)
                    case "d":
                        return top.transformedPath.difference(with: bottom.transformedPath)
                    case "x":
                        return top.transformedPath.xor(with: bottom.transformedPath)
                    default:
                        return NSBezierPath()
                    }
                }()
                let elapsed = start.timeIntervalSinceNow
                print("elapsed", elapsed)
                if !result.isEmpty {
                    removeLast(2)
                    addShape(Symbol(result))
                }
                return
            case "c":
                self.intersections = []
                return
            case ".":
                var didChangeFrame = false

                if hasOption || hasCommand {
                    let newFrame = hasOption ? Frame(frames[current]) : Frame()
                    frames.insert(newFrame, at: current + 1)
                    didChangeFrame = nextFrame()
                } else {
                    didChangeFrame = nextFrame()
                }

                if didChangeFrame {
                    print("frame", current)
                }
                return
            case ",":
                var didChangeFrame = false

                if hasOption || hasCommand {
                    let newFrame = hasOption ? Frame(frames[current]) : Frame()
                    frames.insert(newFrame, at: current)
                    setNeedsDisplay(bounds) // already at the newFrame
                } else {
                    didChangeFrame = prevFrame()
                }

                if didChangeFrame {
                    print("frame", current)
                }
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
    
    func createLine() -> Symbol {
        let rect = centerRect()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY))
        return Symbol(path)
    }
    
    func createCircle() -> Symbol {
        let rect = centerRect()
        let path = NSBezierPath(ovalIn: rect)
        return Symbol(path)
    }
    
    func createTriangle() -> Symbol {
        let rect = centerRect()
        let s = rect.height
        let d = s*sqrt(3)/3 // half of the length of equilateral triangle that is of height rect.height
        let path = NSBezierPath()
        path.move(to: NSPoint(x: NSMidX(rect), y: rect.maxY))
        path.relativeLine(to: NSPoint(x: d, y: -s))
        path.relativeLine(to: NSPoint(x: -d*2, y: 0))
        path.close()
        return Symbol(path)
    }
    
    func createRect() -> Symbol {
        let rect = centerRect()
        let path = NSBezierPath(rect: rect)
        return Symbol(path)
    }
    
    func addShape(_ el: Symbol) {
        frames[current].elements.append(el)
        setNeedsDisplay(el.transformedPath.targetRect)
    }
    
    func removeLast(_ n: Int = 1) {
        var rect = NSRect()
        var k = n
        while k > 0 && frames[current].elements.count > 0 {
            let shape = frames[current].elements.removeLast()
            rect = rect.union(shape.transformedPath.targetRect)
            k -= 1
        }
        setNeedsDisplay(rect)
    }
    
    func nextFrame() -> Bool {
        if current < frames.count - 1 {
            current += 1
            setNeedsDisplay(bounds)
            return true
        }
        return false
    }
    
    func prevFrame() -> Bool {
        if (current > 0) {
            current -= 1
            setNeedsDisplay(bounds)
            return true
        }
        return false
    }
}
