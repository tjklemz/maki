//
//  ViewController.swift
//  Maki
//
//  Created by Thomas Klemz on 12/19/17.
//  Copyright © 2017 Lory & Ludlow. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var canvas : Canvas!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let trackingArea: NSTrackingArea = NSTrackingArea(rect: canvas.bounds, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited], owner: canvas, userInfo: nil)
        canvas.addTrackingArea(trackingArea)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

