//
//  Canvas.swift
//  Maki
//
//  Created by Thomas Klemz on 12/19/17.
//  Copyright © 2017 Lory & Ludlow. All rights reserved.
//

import Cocoa

struct Selection {
    var element : NSBezierPath
    var offset : NSPoint
    
    init(element: NSBezierPath, point: NSPoint) {
        self.element = element
        self.offset = NSPoint(x: element.bounds.minX - point.x, y: element.bounds.minY - point.y)
    }
    
    func move(to point: NSPoint) -> NSRect {
        let oldBounds = element.bounds
        element.transform(using: AffineTransform(translationByX: point.x - element.bounds.minX + offset.x, byY: point.y - element.bounds.minY + offset.y))
        return element.bounds.union(oldBounds)
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
        
        NSColor.blue.set()
        
        for el in frames[current].elements {
            if needsToDraw(el.bounds) {
                el.fill()
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let element = frames[current].elements.first(where: { $0.contains(point) }) {
            selection = Selection(element: element, point: point)
        } else {
            selection = nil
        }
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
            print("key", key)
            switch key {
            case "c":
                let center = self.center
                let s = self.bounds.width / 4
                let rect = NSRect(x: center.x - s/2, y: center.y - s/2, width: s, height: s)
                let path = NSBezierPath(ovalIn: rect)
                frames[current].elements.append(path)
                setNeedsDisplay(rect)
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
