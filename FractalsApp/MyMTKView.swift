//
//  MyMTKView.swift
//  FractalsApp
//
//  Created by Administrator on 22/05/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Cocoa
import MetalKit
import Carbon.HIToolbox.Events

class MyMTKView: MTKView {
    
    var keyboardControlDelegate: KeyboardControlDelegate?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_ANSI_F:
            keyboardControlDelegate?.onSwitchForm()
            break
        default:
            break
        }
    }
}
