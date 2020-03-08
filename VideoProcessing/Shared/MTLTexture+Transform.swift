//
//  MTLTexture+Transform.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/5/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import Metal
import UIKit
import MetalPerformanceShaders

extension MTLTexture {
    func getScaleTransform(to texture: MTLTexture, contentMode: UIView.ContentMode) -> MPSScaleTransform {
        
        var scaleX: Double
        var scaleY: Double
        
        switch contentMode {
        case .scaleToFill:
            scaleX = Double(texture.width) / Double(self.width)
            scaleY = Double(texture.height) / Double(self.height)
        case .scaleAspectFill:
            scaleX = Double(texture.width) / Double(self.width)
            scaleY = Double(texture.height) / Double(self.height)
            
            if scaleX > scaleY {
                scaleY = scaleX
            } else {
                scaleX = scaleY
            }
        case .scaleAspectFit:
            scaleX = Double(texture.width) / Double(self.width)
            scaleY = Double(texture.height) / Double(self.height)
            
            if scaleX > scaleY {
                scaleX = scaleY
            } else {
                scaleY = scaleX
            }
        default:
            scaleX = 1
            scaleY = 1
        }
        
        let translateX: Double = (Double(texture.width) - Double(self.width) * scaleX) / 2
        let translateY: Double = (Double(texture.height) - Double(self.height) * scaleY) / 2
        return MPSScaleTransform(scaleX: scaleX, scaleY: scaleY, translateX: translateX, translateY: translateY)
    }
    
    
    
    
}
