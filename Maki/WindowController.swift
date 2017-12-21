//
//  WindowController.swift
//  Maki
//
//  Created by Thomas Klemz on 12/19/17.
//  Copyright © 2017 Lory & Ludlow. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        self.window?.appearance = NSAppearance(named: .vibrantDark)
    }
}
