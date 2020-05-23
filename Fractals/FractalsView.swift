//
//  FractalsView.swift
//  Fractals
//
//  Created by Administrator on 22/05/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import ScreenSaver
import MetalKit

class FractalsView: ScreenSaverView {
    
    private var renderer: Renderer!
    private var mtkView: MTKView!
    private let defaultsManager = DefaultsManager()

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)

        self.animationTimeInterval = 1.0/60.0
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        let subviewFrame = NSRect(origin: NSPoint.zero, size: frame.size)

        mtkView = MTKView(frame: subviewFrame, device: device)
        self.addSubview(mtkView)

        let bundle = Bundle(for: FractalsView.self)

        guard let newRenderer = Renderer(mtkView: mtkView, bundle: bundle) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        mtkView.delegate = renderer
    }

    @available(*, unavailable)
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var hasConfigureSheet: Bool {
        return false
    }
    
    override var configureSheet: NSWindow? {
        let bundle = Bundle(for: FractalsView.self)
        let storyboard = NSStoryboard(name: "Main", bundle: bundle)
        let configSheet = storyboard.instantiateController(withIdentifier: "ConfigSheetWindowController")
        let windowController = configSheet as? NSWindowController
        return windowController?.window
    }
}
