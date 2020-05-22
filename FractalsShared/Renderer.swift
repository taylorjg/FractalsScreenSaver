//
//  Renderer.swift
//  FractalsShared
//
//  Created by Administrator on 22/05/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Metal
import MetalKit
import simd

private struct Region {
    var bottomLeft: simd_float2
    var topRight: simd_float2
}

class Renderer: NSObject, MTKViewDelegate, KeyboardControlDelegate {
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let mandelbrotPipelineState: MTLRenderPipelineState
    private var uniforms: FractalUniforms
    private let uniformsLength = MemoryLayout<FractalUniforms>.stride
    private var region: Region
    private var needRender = true

    init?(mtkView: MTKView, bundle: Bundle? = nil) {
        self.device = mtkView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        do {
            mandelbrotPipelineState = try Renderer.buildRenderPipelineState(device: device,
                                                                            mtkView: mtkView,
                                                                            bundle: bundle)
        } catch {
            print("Unable to compile render pipeline state. Error info: \(error)")
            return nil
        }
        
        uniforms = FractalUniforms()
        uniforms.modelViewMatrix = matrix_float4x4.init(columns: (
            simd_float4(1, 0, 0, 0),
            simd_float4(0, -1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(0, 0, 0, 1)))
        uniforms.maxIterations = 120
        
        region = Region(bottomLeft: simd_float2(-0.22, -0.7),
                        topRight: simd_float2(-0.21, -0.69))
        
        super.init()
    }
    
    func onSwitchForm() {
    }
    
    class func buildRenderPipelineState(device: MTLDevice,
                                        mtkView: MTKView,
                                        bundle: Bundle?) throws -> MTLRenderPipelineState {
        let library = bundle != nil
            ? try device.makeDefaultLibrary(bundle: bundle!)
            : device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "mandelbrotShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "MandelbrotRenderPipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.sampleCount = mtkView.sampleCount
        
        let colorAttachments0 = pipelineDescriptor.colorAttachments[0]!
        colorAttachments0.pixelFormat = mtkView.colorPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func renderMandelbrot(renderEncoder: MTLRenderCommandEncoder) {
        let vertices = [
            FractalVertex(position: simd_float2(1, 1), region: simd_float2(region.topRight.x, region.topRight.y)),
            FractalVertex(position: simd_float2(-1, 1), region: simd_float2(region.bottomLeft.x, region.topRight.y)),
            FractalVertex(position: simd_float2(1, -1), region: simd_float2(region.topRight.x, region.bottomLeft.y)),
            FractalVertex(position: simd_float2(-1, -1), region: simd_float2(region.bottomLeft.x, region.bottomLeft.y))
        ]
        let verticesLength = MemoryLayout<FractalVertex>.stride * vertices.count
        renderEncoder.pushDebugGroup("Draw Fractal")
        renderEncoder.setRenderPipelineState(mandelbrotPipelineState)
        renderEncoder.setVertexBytes(&uniforms, length: uniformsLength, index: 0)
        renderEncoder.setVertexBytes(vertices, length: verticesLength, index: 1)
        renderEncoder.setFragmentBytes(&uniforms, length: uniformsLength, index: 0)
        renderEncoder.setFragmentBytes(jet, length: 4 * 4 * 256, index: 1)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        renderEncoder.popDebugGroup()
    }
    
    func draw(in view: MTKView) {
        if !needRender {
            return
        }
        needRender = false
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            let renderPassDescriptor = view.currentRenderPassDescriptor
            if let renderPassDescriptor = renderPassDescriptor,
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                renderMandelbrot(renderEncoder: renderEncoder)
                renderEncoder.endEncoding()
            }
            view.currentDrawable.map(commandBuffer.present)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        let cw = Float(size.width)
        let ch = Float(size.height)
        let rw = region.topRight.x - region.bottomLeft.x
        let rh = region.topRight.y - region.bottomLeft.y
        
        if (cw > ch) {
            let rwNew = cw * rh / ch
            let rwDelta = rwNew - rw
            let rwDeltaHalf = rwDelta / 2
            region.bottomLeft.x -= rwDeltaHalf
            region.topRight.x += rwDeltaHalf
        }
        
        if (cw < ch) {
            let rhNew = ch * rw / cw
            let rhDelta = rhNew - rh
            let rhDeltaHalf = rhDelta / 2
            region.bottomLeft.y -= rhDeltaHalf
            region.topRight.y += rhDeltaHalf
        }
        
        needRender = true
    }
}
