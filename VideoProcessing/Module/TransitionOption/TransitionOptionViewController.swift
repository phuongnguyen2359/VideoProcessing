//
//  TransitionOptionViewController.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/7/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import UIKit

protocol TransitionOptionViewControllerDelegate: class {
    func didChangeDurationValue(to value: Float)
}

final class TransitionOptionViewController: UIViewController {
    
    weak var delegate: TransitionOptionViewControllerDelegate?
    
    var durationValue: Float {
        return Float(slider.value * 100).rounded() / 100
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        changeDuration(to: durationValue)
        maxValueLabel.text = "\(slider.maximumValue)"
    }
    
    private func changeDuration(to value: Float) {
        let stringValue = String(format: "%.2f", value)
        durationLabel.text = "Transition duration: \(stringValue)"
    }
    
    @IBOutlet weak var durationLabel: UILabel!
    
    @IBOutlet weak var slider: UISlider! {
        didSet {
            slider.maximumValue = Constant.maxOverlapDuration
            slider.minimumValue = Constant.minOverlapDuration
        }
    }
    
    @IBAction func sliderDidChangeValue(_ sender: UISlider) {
        
        changeDuration(to: durationValue)
        delegate?.didChangeDurationValue(to: durationValue)
    }
    @IBOutlet weak var maxValueLabel: UILabel!
}
