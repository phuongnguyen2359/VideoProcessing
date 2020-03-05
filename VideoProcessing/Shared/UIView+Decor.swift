//
//  UIView+Decor.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/3/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import UIKit

extension UIView {
    
    func addDashLineBorder(_ color: CGColor) {
        let newLayer = CAShapeLayer()
        newLayer.strokeColor = color
        newLayer.lineDashPattern = [2, 2]
        newLayer.frame = self.bounds
        newLayer.fillColor = nil
        newLayer.path = UIBezierPath(rect: self.bounds).cgPath
        self.layer.addSublayer(newLayer)
    }
}
