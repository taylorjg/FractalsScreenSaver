//
//  DefaultsManager.swift
//  Fractals
//
//  Created by Administrator on 26/04/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Foundation
import ScreenSaver

private let KEY_ENABLE_MSAA = "enable-msaa"

private let DEFAULTS: [String: Any] = [
    KEY_ENABLE_MSAA: Settings.defaultEnableMSAA
]

class DefaultsManager {
    
    let screenSaverDefaults: ScreenSaverDefaults
    
    init() {
        let identifier = Bundle(for: ConfigSheetViewController.self).bundleIdentifier!
        screenSaverDefaults = ScreenSaverDefaults.init(forModuleWithName: identifier)!
        screenSaverDefaults.register(defaults: DEFAULTS)
    }
    
    var enableMSAA: Bool {
        get {
            return screenSaverDefaults.bool(forKey: KEY_ENABLE_MSAA)
        }
        set {
            screenSaverDefaults.set(newValue, forKey: KEY_ENABLE_MSAA)
            screenSaverDefaults.synchronize()
        }
    }
}
