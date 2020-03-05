//
//  ViewController.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/3/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import UIKit
import AVFoundation
import MetalKit

final class MainViewController: UIViewController {
    
    var captureSession: AVCaptureSession!
    let firstPlayer: AVPlayer = AVPlayer()
    let secondPlayer: AVPlayer = AVPlayer()
    var firstPlayerItem: AVPlayerItem!
    var secondPlayerItem: AVPlayerItem!
    let overlapDuration: CMTime = CMTime(seconds: 3, preferredTimescale: .init())
    
    lazy var firstPlayerItemVideoOutput: AVPlayerItemVideoOutput = {
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    }()
    
    lazy var secondPlayerItemVideoOutput: AVPlayerItemVideoOutput = {
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    }()
    
    lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        displayLink.add(to: .current, forMode: .default)
        displayLink.isPaused = true
        return displayLink
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    deinit {
        displayLink.invalidate()
    }

    private func setupUI() {
        transitionContainerView.addDashLineBorder(UIColor.white.cgColor)
        leftButtonContainerView.addDashLineBorder(UIColor.white.cgColor)
        rightButtonContainerView.addDashLineBorder(UIColor.white.cgColor)
        metalView.autoResizeDrawable = false
        metalView.contentMode = .scaleAspectFit
    }
    
    @objc private func readBuffer(_ sender: CADisplayLink) {
        var firstVideoTime = CMTime.invalid
        var secondVideoTime = CMTime.invalid
        
        let nextVSync = sender.timestamp + sender.duration
        firstVideoTime = firstPlayerItemVideoOutput.itemTime(forHostTime: nextVSync)
        secondVideoTime = secondPlayerItemVideoOutput.itemTime(forHostTime: nextVSync)
        
        var firstPixelBuffer: CVPixelBuffer?
        var secondPixelBuffer: CVPixelBuffer?

        if firstPlayer.rate != 0, firstPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: firstVideoTime) {
            
            firstPixelBuffer = firstPlayerItemVideoOutput.copyPixelBuffer(forItemTime: firstVideoTime, itemTimeForDisplay: nil)
            self.metalView.firstPixelBuffer = firstPixelBuffer
            self.metalView.firstInputTime = firstVideoTime.seconds
        }
        
        if secondPlayer.rate != 0, secondPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: secondVideoTime) {
            secondPixelBuffer = secondPlayerItemVideoOutput.copyPixelBuffer(forItemTime: secondVideoTime, itemTimeForDisplay: nil)
            self.metalView.secondPixelBuffer = secondPixelBuffer
            self.metalView.secondInputTime = secondVideoTime.seconds
        }
        
        if firstPixelBuffer != nil || secondPixelBuffer != nil {
            self.metalView.setNeedsDisplay()
        }
    }
    

    // MARK: - Outlet and Action
    
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var transitionContainerView: UIView!
    @IBOutlet weak var leftButtonContainerView: UIView!
    @IBOutlet weak var rightButtonContainerView: UIView!
    
    @IBOutlet weak var metalView: MetalView!
    
    @IBAction func addPhoto(_ sender: Any) {
        
        guard let firstUrl = Bundle.main.url(forResource: "first", withExtension: "mp4") else { return }
        let firstAsset = AVURLAsset(url: firstUrl)
        firstPlayerItem = AVPlayerItem(asset: firstAsset)
        firstPlayerItem.add(firstPlayerItemVideoOutput)
        firstPlayer.replaceCurrentItem(with: firstPlayerItem)
        
        guard let secondUrl = Bundle.main.url(forResource: "second", withExtension: "mp4") else { return }
        let secondAsset = AVURLAsset(url: secondUrl)
        secondPlayerItem = AVPlayerItem(asset: secondAsset)
        secondPlayerItem.add(secondPlayerItemVideoOutput)
        secondPlayer.replaceCurrentItem(with: secondPlayerItem)
        
        displayLink.isPaused = false
        
        if let button = sender as? UIButton, button === leftButton {
            firstPlayer.play()
        } else {
            secondPlayer.play()
        }
        
    }
    
}
