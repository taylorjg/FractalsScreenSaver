//
//  ConfigSheetViewController.swift
//  Fractals
//
//  Created by Administrator on 22/05/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Cocoa

class ConfigSheetViewController: NSViewController {
    
    let defaultsManager = DefaultsManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        enableMSAACheck.state = defaultsManager.enableMSAA ? .on : .off
    }
    
    @IBOutlet weak var enableMSAACheck: NSButton!
    @IBOutlet weak var okButton: NSButton!
    
    @IBAction func cancelButtonTapped(_ sender: NSButton) {
        close()
    }
    
    @IBAction func okButtonTapped(_ sender: NSButton) {
        defaultsManager.enableMSAA = enableMSAACheck.state == .on
        close()
    }
    
    private func close() {
        guard let window = view.window else { return }
        window.endSheet(window)
    }
}
