//
//  Renderer.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/8/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import Foundation
import Metal

class Renderer {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    static let sharedInstance = Renderer()
    
    private init() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice(),
            let queue = defaultDevice.makeCommandQueue() else {
            fatalError("GPU is not supported")
        }
        
        self.device = defaultDevice
        self.commandQueue = queue
    }
    
}
