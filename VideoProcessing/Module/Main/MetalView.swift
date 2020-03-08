//
//  MetalView.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/4/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import MetalKit
import CoreVideo
import MetalPerformanceShaders
import UIKit

final class MetalView: MTKView {
    
    var firstVidRemainTime: CFTimeInterval?
    
    var secondVidRemainTime: CFTimeInterval?
    
    var firstPixelBuffer: CVPixelBuffer?
    
    var secondPixelBuffer: CVPixelBuffer?
    
    var firstTransformedTexture: MTLTexture?
    
    var secondTransformedTexture: MTLTexture?
    
    var lanczos: MPSImageLanczosScale
    
    var isRecording: Bool = false
    
    var overlapDuration: Float = Constant.maxOverlapDuration
    
    var blurWeights = [BlurWeight]()
    
    private var textureCache: CVMetalTextureCache?
    private var commandQueue: MTLCommandQueue
    private var fadingComputePipelineState: MTLComputePipelineState
    private var blurComputePipelineState: MTLComputePipelineState
    
    var videoMaker: MetalVideoMaker?
    var formatter: DateFormatter = {
       let formatter = DateFormatter()
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        return formatter
    }()
    
    var videoPath: URL {
        let date = Date()
        let documentPath = NSTemporaryDirectory()
        let path = "\(documentPath)/\(formatter.string(from: date)).mp4"
        return URL(fileURLWithPath: path)
    }
    
    required init(coder: NSCoder) {
        let defaultDevice: MTLDevice = Renderer.sharedInstance.device
        self.commandQueue = Renderer.sharedInstance.commandQueue
        
        let bundle = Bundle.main
        let url = bundle.url(forResource: "default", withExtension: "metallib")
        let library = try! Renderer.sharedInstance.device.makeLibrary(filepath: url!.path)
        
        let fadingFunction = library.makeFunction(name: "fading")!
        do {
            self.fadingComputePipelineState = try defaultDevice.makeComputePipelineState(function: fadingFunction)
        } catch {
            fatalError()
        }
        
        let blurFunction = library.makeFunction(name: "gaussian_blur")!
        do {
            self.blurComputePipelineState = try defaultDevice.makeComputePipelineState(function: blurFunction)
        } catch {
            fatalError()
        }

        
        var textCache: CVMetalTextureCache?
        
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, defaultDevice, nil, &textCache) != kCVReturnSuccess {
            fatalError("Unable to allocate texture cache")
        } else {
            self.textureCache = textCache
        }
        
        lanczos = MPSImageLanczosScale(device: defaultDevice)
        super.init(coder: coder)
        
        self.device = defaultDevice
        
        self.framebufferOnly = false
        
        self.autoResizeDrawable = false
        
        self.contentMode = .scaleAspectFit
        
        self.enableSetNeedsDisplay = true
        
        self.isPaused = true
        
        self.contentScaleFactor = UIScreen.main.scale
    }
    
    override func draw(_ rect: CGRect) {
        autoreleasepool {
            if rect.width > 0 && rect.height > 0 && (firstVidRemainTime != nil || secondVidRemainTime != nil) {
                self.render(self)
            }
        }
    }
    
    func prepareForSaveVideo() {
        self.videoMaker = MetalVideoMaker(url: videoPath, size: self.drawableSize)
    }
    
    private func getMetalTexture(from cvBuffer: CVPixelBuffer?) -> MTLTexture? {
        guard let cvBuffer = cvBuffer else { return nil }
        let width = CVPixelBufferGetWidth(cvBuffer)
        let height = CVPixelBufferGetHeight(cvBuffer)
        
        var cvMetalTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  self.textureCache!,
                                                  cvBuffer,
                                                  nil,
                                                  .bgra8Unorm,
                                                  width, height,
                                                  0,
                                                  &cvMetalTexture)
        
        guard let metalTexture = cvMetalTexture else {
             return nil
        }
        
        return CVMetalTextureGetTexture(metalTexture)
    }
    
    private func render(_ view: MTKView) {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        
        // Fading effect
        computeCommandEncoder?.setComputePipelineState(fadingComputePipelineState)
        let firstVideoTexture = getMetalTexture(from: firstPixelBuffer)
        if let texture = firstVideoTexture {
            transformToDescTexture(texture, descTexture: &firstTransformedTexture, contentMode: contentMode)
        }
        computeCommandEncoder?.setTexture(firstTransformedTexture, index: 0)
        
    
        let secondVideoTexture = getMetalTexture(from: secondPixelBuffer)
        if let texture = secondVideoTexture {
            transformToDescTexture(texture, descTexture: &secondTransformedTexture, contentMode: contentMode)
        }
        computeCommandEncoder?.setTexture(secondTransformedTexture, index: 1)
        
        
        let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: colorPixelFormat,
                                                                            width: Int(drawableSize.width),
                                                                            height: Int(drawableSize.height),
                                                                            mipmapped: true)
        
        outTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let outTexture = Renderer.sharedInstance.device.makeTexture(descriptor: outTextureDescriptor) else { return }
        computeCommandEncoder?.setTexture(outTexture, index: 2)
        
        var time = Float(self.firstVidRemainTime!)
        computeCommandEncoder?.setBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        
        var firstVidIsNill = firstPixelBuffer == nil
        computeCommandEncoder?.setBytes(&firstVidIsNill, length: MemoryLayout<Bool>.size, index: 1)
        
        var secondVidIsNill = secondPixelBuffer == nil
        computeCommandEncoder?.setBytes(&secondVidIsNill, length: MemoryLayout<Bool>.size, index: 2)
        
        computeCommandEncoder?.setBytes(&overlapDuration, length: MemoryLayout<Float>.size, index: 3)
        
        computeCommandEncoder?.dispatchThreadgroups(outTexture.threadGroups(), threadsPerThreadgroup: outTexture.threadGroupCount())
        
        
        // Blur effect
        computeCommandEncoder?.setComputePipelineState(blurComputePipelineState)
        
        
        guard let drawable: CAMetalDrawable = self.currentDrawable else { return }
        computeCommandEncoder?.setTexture(drawable.texture, index: 3)
        
        let index = Int(min(1, (1.0 - min(time / overlapDuration, 1))) * Float(blurWeights.count - 1))
        let weight = blurWeights[index]
        
        let destTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.r32Float, width: weight.size, height: weight.size, mipmapped: false)
        guard let blurWeightTexture = device?.makeTexture(descriptor: destTextureDescriptor) else {
            return
        }
        
        let region = MTLRegionMake2D(0, 0, weight.size, weight.size);
        blurWeightTexture.replace(region: region, mipmapLevel: 0, withBytes: weight.weights, bytesPerRow: MemoryLayout<Float>.size * weight.size)
        computeCommandEncoder?.setTexture(blurWeightTexture, index: 4)
        
        computeCommandEncoder?.dispatchThreadgroups(drawable.texture.threadGroups(), threadsPerThreadgroup: drawable.texture.threadGroupCount())
        
        
        computeCommandEncoder?.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func writeFrame(firstVideoTexture: MTLTexture?, secondVideoTexture: MTLTexture?) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        computeCommandEncoder?.setComputePipelineState(fadingComputePipelineState)
        
        
        if let texture = firstVideoTexture {
            transformToDescTexture(texture, descTexture: &firstTransformedTexture, contentMode: contentMode)
        }
        computeCommandEncoder?.setTexture(firstTransformedTexture, index: 0)
        
        let secondVideoTexture = getMetalTexture(from: secondPixelBuffer)
        if let texture = secondVideoTexture {
            transformToDescTexture(texture, descTexture: &secondTransformedTexture, contentMode: contentMode)
        }
        computeCommandEncoder?.setTexture(secondTransformedTexture, index: 1)
        
        let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: colorPixelFormat, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: true)
        outTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let outTexture = Renderer.sharedInstance.device.makeTexture(descriptor: outTextureDescriptor) else { return }
        computeCommandEncoder?.setTexture(outTexture, index: 2)
        
        var time = Float(self.firstVidRemainTime!)
        computeCommandEncoder?.setBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        
        var firstVidIsNill = firstVideoTexture == nil
        computeCommandEncoder?.setBytes(&firstVidIsNill, length: MemoryLayout<Bool>.size, index: 1)
        
        var secondVidIsNill = secondVideoTexture == nil
        computeCommandEncoder?.setBytes(&secondVidIsNill, length: MemoryLayout<Bool>.size, index: 2)
        
        computeCommandEncoder?.setBytes(&overlapDuration, length: MemoryLayout<Float>.size, index: 3)
        
        computeCommandEncoder?.dispatchThreadgroups(outTexture.threadGroups(), threadsPerThreadgroup: outTexture.threadGroupCount())
        
        computeCommandEncoder?.endEncoding()
        
        commandBuffer.addCompletedHandler { (_) in
            self.videoMaker?.writeFrame(outTexture)
        }
        commandBuffer.commit()
        
    }
    
    private func copyToSharedModeTexture(from sourceTexture: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: sourceTexture.pixelFormat, width: sourceTexture.width, height: sourceTexture.height, mipmapped: true)
        
        guard let copyTexture = device?.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        blitCommandEncoder?.copy(from: sourceTexture, to: copyTexture)
        blitCommandEncoder?.endEncoding()
        return copyTexture
    }
    
    private func transformToDescTexture(_ texture: MTLTexture, descTexture: inout MTLTexture?, contentMode: UIView.ContentMode) {
        let defaultDevice = Renderer.sharedInstance.device
        guard let desc = currentDrawable?.texture else {
            return
        }
        
        guard texture.width != Int(drawableSize.width) || texture.height != Int(drawableSize.height) else {
            return
        }
        
        var transform: MPSScaleTransform = texture.getScaleTransform(to: desc, contentMode: contentMode)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: desc.width, height: desc.height, mipmapped: true)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        descTexture = defaultDevice.makeTexture(descriptor: textureDescriptor)
        
        guard let descTexture = descTexture else { fatalError() }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { fatalError() }
        withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) in
            lanczos.scaleTransform = transformPtr
            lanczos.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: descTexture)
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

extension MTLTexture {
    func threadGroupCount() -> MTLSize {
        return MTLSize(width: 8, height: 8, depth: 1)
    }
    
    func threadGroups() -> MTLSize {
        let groupCount = threadGroupCount()
        return MTLSize(width: Int(self.width) / groupCount.width,
                       height: Int(self.height) / groupCount.height,
                       depth: 1)
    }
}
