//
//  LoadingIndicator.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/9/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import UIKit

class LoadingIndicator {
    static let instance = LoadingIndicator()
    
    func show(with text: String) {
        if let window = UIApplication.shared.keyWindow {
            let view = UIView()
            view.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.2950288955)
            view.tag = 2020
            window.addSubview(view)
            
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: window.topAnchor),
                view.leftAnchor.constraint(equalTo: window.leftAnchor),
                view.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                view.rightAnchor.constraint(equalTo: window.rightAnchor)
            ])
            
            let label = UILabel()
            label.font = UIFont(name: "Avenir-Bold", size: 17.0)
            label.textColor = UIColor.white
            label.text = text
            view.addSubview(label)
            
            label.translatesAutoresizingMaskIntoConstraints =  false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
            
            window.bringSubviewToFront(view)
        }
    }
    
    func hide() {
        if let window = UIApplication.shared.keyWindow,
            let view = window.viewWithTag(2020) {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                view.alpha = 0

            }) { _ in
                view.removeFromSuperview()
            }
        }
    }
}
