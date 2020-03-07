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
    
    var overlapDuration: Float = Constant.maxOverlapDuration
    
    private var textureCache: CVMetalTextureCache?
    private var commandQueue: MTLCommandQueue
    private var computePipelineState: MTLComputePipelineState
    var videoMaker: MetalVideoMaker!
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
        let device = MTLCreateSystemDefaultDevice()!
        
        self.commandQueue = device.makeCommandQueue()!
        
        let bundle = Bundle.main
        let url = bundle.url(forResource: "default", withExtension: "metallib")
        let library = try! device.makeLibrary(filepath: url!.path)
        
        let function = library.makeFunction(name: "fading")!
        
        self.computePipelineState = try! device.makeComputePipelineState(function: function)
        
        var textCache: CVMetalTextureCache?
        
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textCache) != kCVReturnSuccess {
            fatalError("Unable to allocate texture cache")
        } else {
            self.textureCache = textCache
        }
        
        lanczos = MPSImageLanczosScale(device: device)
        super.init(coder: coder)
        
        videoMaker = MetalVideoMaker(url: videoPath, size: self.drawableSize)
        
        self.device = device
        
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
        computeCommandEncoder?.setComputePipelineState(computePipelineState)
        
        
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
        
        guard let drawable: CAMetalDrawable = self.currentDrawable else { return }
        computeCommandEncoder?.setTexture(drawable.texture, index: 2)
        
        var time = Float(self.firstVidRemainTime!)
        computeCommandEncoder?.setBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        
        var firstVidIsNill = firstPixelBuffer == nil
        computeCommandEncoder?.setBytes(&firstVidIsNill, length: MemoryLayout<Bool>.size, index: 1)
        
        var secondVidIsNill = secondPixelBuffer == nil
        computeCommandEncoder?.setBytes(&secondVidIsNill, length: MemoryLayout<Bool>.size, index: 2)
        
        computeCommandEncoder?.setBytes(&overlapDuration, length: MemoryLayout<Float>.size, index: 3)
        
        computeCommandEncoder?.dispatchThreadgroups(drawable.texture.threadGroups(), threadsPerThreadgroup: drawable.texture.threadGroupCount())
        
        computeCommandEncoder?.endEncoding()
        
        // Blur effect
        if firstVidRemainTime!.isLessThanOrEqualTo(Double(overlapDuration)){
            var texture: MTLTexture? = drawable.texture
            
            let kernel = MPSImageGaussianBlur(device: device!, sigma: time)
            kernel.encode(commandBuffer: commandBuffer, inPlaceTexture: &texture!, fallbackCopyAllocator: nil)
        }

        if let sharedModeTexture = copyToSharedModeTexture(from: drawable.texture, commandBuffer: commandBuffer) {
            commandBuffer.addCompletedHandler({ _ in
                self.videoMaker.writeFrame(sharedModeTexture)
            })
        }
        

        commandBuffer.present(drawable)
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
        guard let device = device else { fatalError() }
        guard let desc = currentDrawable?.texture else {
            return
        }
        
        guard texture.width != desc.width || texture.height != desc.height else {
            return
        }
        
        var transform: MPSScaleTransform = texture.getScaleTransform(to: desc, contentMode: contentMode)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: desc.width, height: desc.height, mipmapped: true)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        descTexture = device.makeTexture(descriptor: textureDescriptor)
        
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
