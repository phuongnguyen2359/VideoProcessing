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
import CoreFoundation

final class MainViewController: UIViewController {
    
    var captureSession: AVCaptureSession!
    let firstPlayer: AVPlayer = AVPlayer()
    let secondPlayer: AVPlayer = AVPlayer()
    var firstPlayerItem: AVPlayerItem!
    var secondPlayerItem: AVPlayerItem!
    var overlapDuration: Float = Constant.maxOverlapDuration
    
    var firstVideoUrl: URL? {
        didSet {
            leftButtonContainerView.backgroundColor = firstVideoUrl == nil ? UIColor.clear : UIColor.white
            if secondVideoUrl == nil {
                statusLabel.text = "Add one more video"
            } else if firstVideoUrl != nil {
                statusLabel.text = "Now you can play or save new video with our effect"
            } else {
                statusLabel.text = ""
            }
        }
    }
    var secondVideoUrl: URL? {
        didSet {
            rightButtonContainerView.backgroundColor = secondVideoUrl == nil ? UIColor.clear : UIColor.white
            if firstVideoUrl == nil {
                statusLabel.text = "Add one more video"
            } else if secondVideoUrl != nil {
                statusLabel.text = "Now you can play or save new video with our effect"
            } else {
                statusLabel.text = ""
            }
        }
    }
    
    var firstVidAssetReader: AVAssetReader!
    var secondVidAssetReader: AVAssetReader!
    var firstVidAssetOutput: AVAssetReaderTrackOutput!
    var secondVidAssetOutput: AVAssetReaderTrackOutput!
    var textureCache: CVMetalTextureCache?
    
    var blurWeights = [BlurWeight]()
    
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
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barTintColor = #colorLiteral(red: 0.1005150601, green: 0.7877844572, blue: 0.5518413186, alpha: 1)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard blurWeights.isEmpty else { return }
        setupBlurWeights()
        metalView.blurWeights = blurWeights
    }
    
    func addObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(secondVideoDidPlayToEnd), name: .AVPlayerItemDidPlayToEndTime, object: secondPlayer.currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(firstVideoDidPlayToEnd), name: .AVPlayerItemDidPlayToEndTime, object: firstPlayer.currentItem)
    }
    
    func removeObserver() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func secondVideoDidPlayToEnd() {
        print("second did end")
        
        secondPlayer.pause()
        displayLink.isPaused = true
        removeObserver()
    }
    @objc func firstVideoDidPlayToEnd() {
        print("first did end")
        firstPlayer.pause()
    }
    
    deinit {
        displayLink.invalidate()
        removeObserver()
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
        if firstPlayer.rate != 0 {
            if firstPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: firstVideoTime) {
                firstPixelBuffer = firstPlayerItemVideoOutput.copyPixelBuffer(forItemTime: firstVideoTime, itemTimeForDisplay: nil)
                self.metalView.firstPixelBuffer = firstPixelBuffer
            }
            self.metalView.firstVidRemainTime = firstPlayerItem.duration.seconds - firstVideoTime.seconds
        } else {
            self.metalView.firstPixelBuffer = nil
            self.metalView.firstVidRemainTime = 0
        }
        
        if secondPlayer.rate != 0 {
            if secondPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: secondVideoTime) {
                secondPixelBuffer = secondPlayerItemVideoOutput.copyPixelBuffer(forItemTime: secondVideoTime, itemTimeForDisplay: nil)
                self.metalView.secondPixelBuffer = secondPixelBuffer
            }
            
            self.metalView.secondVidRemainTime = secondPlayerItem.duration.seconds - secondVideoTime.seconds
        } else {
            self.metalView.secondPixelBuffer = nil
            self.metalView.secondVidRemainTime = 0
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
        removeObserver()
        addObserver()
        
        metalView.overlapDuration = self.overlapDuration
        
    }
    
    private func prepareRecording() throws {
        guard let firstURL = firstVideoUrl, let secondURL = secondVideoUrl else { return }
        let firstAsset = AVAsset(url: firstURL)
        firstVidAssetReader = try AVAssetReader(asset: firstAsset)
        
        let secondAsset = AVAsset(url: secondURL)
        secondVidAssetReader = try AVAssetReader(asset: secondAsset)
        
        let videoReaderSetting: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        firstVidAssetOutput = AVAssetReaderTrackOutput(track: firstAsset.tracks(withMediaType: .video).first!, outputSettings: videoReaderSetting)
        if firstVidAssetReader.canAdd(firstVidAssetOutput) {
            firstVidAssetReader.add(firstVidAssetOutput)
        } else {
            fatalError()
        }
        
        secondVidAssetOutput = AVAssetReaderTrackOutput(track: secondAsset.tracks(withMediaType: .video).first!,
                                                                   outputSettings: videoReaderSetting)
        if secondVidAssetReader.canAdd(secondVidAssetOutput) {
            secondVidAssetReader.add(secondVidAssetOutput)
        } else { fatalError() }
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, Renderer.sharedInstance.device, nil, &textureCache)
    }
    
    private func getTexture(from sampleBuffer: CMSampleBuffer) -> MTLTexture? {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)

            var texture: CVMetalTexture?
            
            CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, imageBuffer, nil, MTLPixelFormat.bgra8Unorm, width, height, 0, &texture)
          
            if let texture = texture {
                return CVMetalTextureGetTexture(texture)
            }
        }
        
        return nil
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
    
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBAction func playVideo(_ sender: Any) {
        guard firstVideoUrl != nil && secondVideoUrl != nil else {
            statusLabel.text = "Add 2 videos so you can enjoy"
            return
        }
        statusLabel.text = ""
        preparePlayerItem()
        metalView.videoMaker?.startSession()
        firstPlayer.play()
        displayLink.isPaused = false
    }
    @IBOutlet weak var directoryContainerView: UIView! {
        
        didSet {
            directoryContainerView.layer.cornerRadius = 25
            directoryContainerView.layer.shadowColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
            directoryContainerView.layer.shadowOpacity = 1
            directoryContainerView.layer.shadowOffset = .zero
            directoryContainerView.layer.shadowRadius = 10
        }
    }
    @IBAction func openDirectory(_ sender: Any) {
        
    }
    
    @IBAction func saveVideo(_ sender: Any) {
        guard let firstUrl = self.firstVideoUrl, let secondUrl = self.secondVideoUrl else {
            statusLabel.text = "Add 2 videos so you can enjoy"
            return
        }
        statusLabel.text = ""
        LoadingIndicator.instance.show(with: "Saving...")
        let contentMode = SupportedContentMode.createFromUIViewContentMode(metalView.contentMode) ?? SupportedContentMode.scaleAspectFit
        self.metalView.prepareForSaveVideo()
        self.metalView.videoMaker?.startSession()
        
        DispatchQueue.global().async {
             do {
                try self.prepareRecording()
                
                self.firstVidAssetReader.startReading()
                self.secondVidAssetReader.startReading()
                       
                var isStartReadingSecondVid = false
                var firstVidToEnd = false
                var secondVidToEnd = false
                var firstTexture: MTLTexture? = nil
                var secondTexture: MTLTexture? = nil
                
                let firstDuration = AVAsset(url: firstUrl).duration
                let secondDuration = AVAsset(url: secondUrl).duration
                       
                while !firstVidToEnd || !secondVidToEnd {
                    autoreleasepool {
                        if let firstSample = self.firstVidAssetOutput.copyNextSampleBuffer() {
                            
                            let currentTimeStamp = firstSample.presentationTimeStamp
                            if (firstDuration.seconds - currentTimeStamp.seconds) <= Double(self.overlapDuration) {
                                isStartReadingSecondVid = true
                            }
                            if let firstFrame = self.getTexture(from: firstSample) {
                                self.metalView.firstVidRemainTime = firstDuration.seconds - currentTimeStamp.seconds
                                firstTexture = firstFrame
                            }
                        } else {
                            firstTexture = nil
                            firstVidToEnd = true
                        }
                               
                        if isStartReadingSecondVid {
                            if let secondSample = self.secondVidAssetOutput.copyNextSampleBuffer() {
                                let currentTimeStamp = secondSample.presentationTimeStamp
                                if let secondFrame = self.getTexture(from: secondSample) {
                                    self.metalView.secondVidRemainTime = secondDuration.seconds - currentTimeStamp.seconds
                                    secondTexture = secondFrame
                                }
                            } else {
                                secondTexture = nil
                                secondVidToEnd = true
                            }
                        }
                               
                        self.metalView.writeFrame(firstVideoTexture: firstTexture, secondVideoTexture: secondTexture, supportedContentMode: contentMode)
                    }
                    
                    
                }
                self.metalView.videoMaker?.finishSession()
                self.metalView.videoMaker = nil
                self.firstVidAssetReader.cancelReading()
                self.secondVidAssetReader.cancelReading()
                       
                DispatchQueue.main.async {
                    self.statusLabel.text = ""
                    Toast.instance.showText("Saving successfully!")
                    LoadingIndicator.instance.hide()
                }
                       
            } catch {
                DispatchQueue.main.async {
                    self.statusLabel.text = ""
                    Toast.instance.showText("Saving unsuccessfully: \(error.localizedDescription)")
                }
            }
                   
        }
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
