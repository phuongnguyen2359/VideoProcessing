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
    var overlapDuration: Float = Constant.maxOverlapDuration
    var firstVideoUrl: URL?
    var secondVideoUrl: URL?
    
    var didSelectVideo: ((URL) -> ())?
    
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
        preparePlayerItem()
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
        
        if secondPlayer.rate == 0 && ((firstPlayerItem.duration.seconds - firstVideoTime.seconds) <= Double(self.overlapDuration)) {
            secondPlayer.play()
        }

        if firstPlayer.rate != 0, firstPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: firstVideoTime) {
            
            firstPixelBuffer = firstPlayerItemVideoOutput.copyPixelBuffer(forItemTime: firstVideoTime, itemTimeForDisplay: nil)
            self.metalView.firstPixelBuffer = firstPixelBuffer
            self.metalView.firstVidRemainTime = firstPlayerItem.duration.seconds - firstVideoTime.seconds
        }
        
        if secondPlayer.rate != 0, secondPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: secondVideoTime) {
            secondPixelBuffer = secondPlayerItemVideoOutput.copyPixelBuffer(forItemTime: secondVideoTime, itemTimeForDisplay: nil)
            self.metalView.secondPixelBuffer = secondPixelBuffer
            self.metalView.secondVidRemainTime = secondPlayerItem.duration.seconds - secondVideoTime.seconds
        }
        
        if firstPixelBuffer != nil || secondPixelBuffer != nil {
            self.metalView.setNeedsDisplay()
        }
    }
    
    private func preparePlayerItem() {
        guard let firstUrl = firstVideoUrl else { return }
        let firstAsset = AVURLAsset(url: firstUrl)
        firstPlayerItem = AVPlayerItem(asset: firstAsset)
        firstPlayerItem.add(firstPlayerItemVideoOutput)
        firstPlayer.replaceCurrentItem(with: firstPlayerItem)
        
        guard let secondUrl = secondVideoUrl else { return }
        let secondAsset = AVURLAsset(url: secondUrl)
        secondPlayerItem = AVPlayerItem(asset: secondAsset)
        secondPlayerItem.add(secondPlayerItemVideoOutput)
        secondPlayer.replaceCurrentItem(with: secondPlayerItem)
        
        metalView.overlapDuration = self.overlapDuration
        
    }
    

    // MARK: - Outlet and Action
    
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var transitionContainerView: UIView!
    @IBOutlet weak var leftButtonContainerView: UIView!
    @IBOutlet weak var rightButtonContainerView: UIView!
    
    @IBOutlet weak var metalView: MetalView!
    
    @IBAction func showTransitionOption(_ sender: Any) {
        let transionOptionVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(identifier: "TransitionOptionViewController") as! TransitionOptionViewController
        transionOptionVC.delegate = self
        _ = transionOptionVC.view
        transionOptionVC.slider.setValue(metalView.overlapDuration, animated: false)
        transionOptionVC.slider.value = metalView.overlapDuration
        transionOptionVC.modalPresentationStyle = .popover
        transionOptionVC.popoverPresentationController?.sourceView = optionButton
        self.present(transionOptionVC, animated: true, completion: nil)
    }
    
    @IBOutlet weak var optionButton: UIButton!
    
    @IBAction func playVideo(_ sender: Any) {
        preparePlayerItem()
        metalView.videoMaker.startSession()
        firstPlayer.play()
        displayLink.isPaused = false
    }
    
    @IBAction func saveVideo(_ sender: Any) {
        metalView.videoMaker.finishSession()
    }
    
    @IBAction func addPhoto(_ sender: Any) {
        guard let button = sender as? UIButton else { fatalError() }
        if button === leftButton {
            didSelectVideo = { [weak self] in self?.firstVideoUrl = $0 }
        } else {
            didSelectVideo = { [weak self] in self?.secondVideoUrl = $0 }
        }
        openVideoBrowser(sourceType: .savedPhotosAlbum, delegate: self)
        
    }
    
}

extension MainViewController: TransitionOptionViewControllerDelegate {
    func didChangeDurationValue(to value: Float) {
        self.overlapDuration = value
    }
}
