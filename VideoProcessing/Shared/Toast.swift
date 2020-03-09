//
//  Toast.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/9/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//


import Foundation
import UIKit

class Toast {
    private init() {}
    
    static let instance = Toast()
    
    func showText(_ text: String) {
        
        if let window = UIApplication.shared.keyWindow {
            let toastView = UIView()
            toastView.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            toastView.layer.cornerRadius = 6
            toastView.layer.masksToBounds = true
            window.addSubview(toastView)
            
            let toastLabel = UILabel()
            toastLabel.backgroundColor = .clear
            toastLabel.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
            toastLabel.font = UIFont(name: "Avenir-Medium", size: 15.0)
            toastLabel.textAlignment = .center
            toastLabel.numberOfLines = 2
            toastLabel.text = text
            toastLabel.alpha = 1.0
            toastView.addSubview(toastLabel)
            
            toastView.layer.borderColor = #colorLiteral(red: 0.1005150601, green: 0.7877844572, blue: 0.5518413186, alpha: 1)
            toastView.layer.borderWidth = 1.0
            
            toastView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                toastView.widthAnchor.constraint(equalToConstant: window.bounds.width * 2/3),
                toastView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                toastView.bottomAnchor.constraint(equalTo: window.bottomAnchor, constant: -50),
                toastView.heightAnchor.constraint(equalToConstant: 40)
            ])
            
            toastLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                toastLabel.topAnchor.constraint(equalTo: toastView.topAnchor),
                toastLabel.leftAnchor.constraint(equalTo: toastView.leftAnchor),
                toastLabel.rightAnchor.constraint(equalTo: toastView.rightAnchor),
                toastLabel.bottomAnchor.constraint(equalTo: toastView.bottomAnchor)
            ])
            
            window.bringSubviewToFront(toastView)
                    
            UIView.animate(withDuration: 3, delay: 1, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0
                toastView.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
                toastView.removeFromSuperview()
            }
        }
    }

}

