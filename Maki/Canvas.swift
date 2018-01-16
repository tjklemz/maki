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
}

extension Symbol {
    init(_ path: NSBezierPath) {
        self.init(uuid: UUID().uuidString, path: path)
    }
    
    init(_ symbol: Symbol) {
        self.init(uuid: symbol.uuid, path: symbol.path.copy() as! NSBezierPath)
    }
}

extension Symbol {
    func inBounds(_ point: NSPoint) -> Bool {
        return self.path.targetRect.contains(point)
    }
    
    func inPath(_ point: NSPoint) -> Bool {
        // TODO: have list of outlinePaths (tapTargets) so we don't create each time
        //  Then there won't be two checks, since the shape will be cached
        return self.path.contains(point) || self.path.outlinePath().contains(point)
    }
}

struct Selection {
    var symbol: Symbol
    var offset: NSPoint
    
    init(symbol: Symbol, point: NSPoint) {
        self.symbol = symbol
        self.offset = NSPoint(x: symbol.path.bounds.minX - point.x, y: symbol.path.bounds.minY - point.y)
    }
    
    func move(to point: NSPoint) -> NSRect {
        let bounds = symbol.path.bounds
        let oldTargetRect = symbol.path.targetRect
        symbol.path.transform(using: AffineTransform(translationByX: point.x - bounds.minX + offset.x, byY: point.y - bounds.minY + offset.y))
        return symbol.path.targetRect.union(oldTargetRect)
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
            let path = el.path
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
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        for el in frames[current].elements.reversed() {
            guard el.inBounds(point) else {
                continue
            }

            if el.inPath(point) {
                selection = Selection(symbol: el, point: point)
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
                let path = NSBezierPath(rect: self.bounds)
                addShape(Symbol(path))
                return
            case "m", "M":
                if frames[current].elements.count == 0 {
                    addShape(createCircle())
                }
                let els = frames[current].elements
                let top = els[els.count - 1]
                let parts = top.path.elements()
                let oldBounds = top.path.bounds
                let maxY = oldBounds.maxY
                let minY = oldBounds.minY
                let maxX = oldBounds.maxX
                let minX = oldBounds.minX
                let midX = (maxX - minX)/2
                let h = maxY - minY
                let otherSign: CGFloat = key == "M" ? -1 : 1
                let newParts = parts.map { el -> Curve in
                    return el.map { p in
                        let perY = (p.y - minY)/h
                        let perX = (midX - (p.x - minX))/midX
                        let sign: CGFloat = perX >= 0 ? 1 : -1
                        return NSPoint(x: p.x + otherSign*sign*(exp(abs(perX) - 1)), y: p.y + otherSign*2*(exp(perY) - 1))
                    }
                }
                frames[current].elements[frames[current].elements.count - 1] = Symbol(uuid: top.uuid, path: NSBezierPath(parts: newParts))
                //top.path = NSBezierPath(parts: newParts)
                setNeedsDisplay(self.bounds)
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
                        return top.path.union(with: bottom.path)
                    case "i":
                        return top.path.intersect(with: bottom.path)
                    case "d":
                        return top.path.difference(with: bottom.path)
                    case "x":
                        return top.path.xor(with: bottom.path)
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
        setNeedsDisplay(el.path.targetRect)
    }
    
    func removeLast(_ n: Int = 1) {
        var rect = NSRect()
        var k = n
        while k > 0 && frames[current].elements.count > 0 {
            let shape = frames[current].elements.removeLast()
            rect = rect.union(shape.path.targetRect)
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
