//
//  MetalVideoMaker.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/7/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import Foundation
import AVFoundation

final class MetalVideoMaker {
    
    private let assetWriter: AVAssetWriter
    private let assetWriterInput: AVAssetWriterInput
    private let assetWriterInputPixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor
    
    var startTime = TimeInterval(0)
    
    init?(url: URL, size: CGSize) {
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            return nil
        }
        
        let outputSetting: [String: Any] = [
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSetting)
        assetWriter.add(assetWriterInput)
        
        let sourcePixelBufferAtts: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height
        ]
        assetWriterInputPixelBufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAtts)
    }
    
    func startSession() {
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        startTime = CACurrentMediaTime()
    }
    
    func finishSession() {
        assetWriterInput.markAsFinished()
        assetWriter.finishWriting(completionHandler: {})
    }
    
    func writeFrame(_ frame: MTLTexture) {
        while !assetWriterInput.isReadyForMoreMediaData {}
        
        guard let pixelBufferBool = assetWriterInputPixelBufferAdapter.pixelBufferPool
            else {
                return
        }
        
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferBool, &pixelBuffer) == kCVReturnSuccess,
            let certainPixelBuffer = pixelBuffer else { return }
        
        CVPixelBufferLockBaseAddress(certainPixelBuffer, [])
        let pixelBufferPtr = CVPixelBufferGetBaseAddress(certainPixelBuffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(certainPixelBuffer)
        let region = MTLRegionMake2D(0, 0, frame.width, frame.height)
        frame.getBytes(pixelBufferPtr, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        let frameTime = CACurrentMediaTime() - startTime
        
        let presentationTime = CMTimeMakeWithSeconds(frameTime, preferredTimescale: 240)
        if assetWriterInput.isReadyForMoreMediaData {
            assetWriterInputPixelBufferAdapter.append(certainPixelBuffer, withPresentationTime: presentationTime)
        }
        
        CVPixelBufferUnlockBaseAddress(certainPixelBuffer, [])
    }
}
