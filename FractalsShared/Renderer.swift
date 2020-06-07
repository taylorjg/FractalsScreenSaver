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

class Renderer: NSObject, MTKViewDelegate, KeyboardControlDelegate {
    
    private enum Fractal {
        case mandelbrot
        case julia
    }
    
    private struct Region {
        var bottomLeft: simd_float2
        var topRight: simd_float2
        var topLeft: simd_float2 { return simd_float2(bottomLeft.x, topRight.y) }
        var bottomRight: simd_float2 { return simd_float2(topRight.x, bottomLeft.y) }
        mutating func pan(percent: Float) {
            let width = topRight.x - bottomLeft.x
            let widthDelta = width / 100 * percent
            let height = topRight.y - bottomLeft.y
            let heightDelta = height / 100 * percent
            bottomLeft.x -= widthDelta
            topRight.x -= widthDelta
            bottomLeft.y -= heightDelta
            topRight.y -= heightDelta
        }
        mutating func zoom(percent: Float) {
            let width = topRight.x - bottomLeft.x
            let widthDelta = width / 100 * percent
            let widthDeltaHalf = widthDelta / 2
            let height = topRight.y - bottomLeft.y
            let heightDelta = height / 100 * percent
            let heightDeltaHalf = heightDelta / 2
            bottomLeft.x += widthDeltaHalf
            topRight.x -= widthDeltaHalf
            bottomLeft.y += heightDeltaHalf
            topRight.y -= heightDeltaHalf
        }
        mutating func adjustAspectRatio(drawableWidth: Float, drawableHeight: Float) {
            let width = topRight.x - bottomLeft.x
            let height = topRight.y - bottomLeft.y
            if (drawableWidth > drawableHeight) {
                let widthDelta = drawableWidth / drawableHeight * height - width
                let widthDeltaHalf = widthDelta / 2
                bottomLeft.x -= widthDeltaHalf
                topRight.x += widthDeltaHalf
            }
            if (drawableWidth < drawableHeight) {
                let heightDelta = drawableHeight / drawableWidth * width - height
                let heightDeltaHalf = heightDelta / 2
                bottomLeft.y -= heightDeltaHalf
                topRight.y += heightDeltaHalf
            }
        }
    }
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let mandelbrotPipelineState: MTLRenderPipelineState
    private let juliaPipelineState: MTLRenderPipelineState
    private var uniforms: FractalUniforms
    private let uniformsLength = MemoryLayout<FractalUniforms>.stride
    private var maxIterations: Int
    private var colorMaps: [[simd_float4]]
    private var colorMapIndex: Int
    private var fractal = Fractal.mandelbrot
    private var region: Region
    private var juliaConstant: simd_float2
    private var needRender = true
    
    init?(mtkView: MTKView, bundle: Bundle? = nil) {
        self.device = mtkView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        do {
            mandelbrotPipelineState = try Renderer.buildRenderPipelineState(name: "mandelbrot",
                                                                            device: device,
                                                                            mtkView: mtkView,
                                                                            bundle: bundle)
        } catch {
            print("Unable to compile render pipeline state. Error info: \(error)")
            return nil
        }
        
        do {
            juliaPipelineState = try Renderer.buildRenderPipelineState(name: "julia",
                                                                       device: device,
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
        
        maxIterations = 120
        colorMaps = [jet, gistStern, oceanData]
        colorMapIndex = 0
        
        region = Region(bottomLeft: simd_float2(-0.22, -0.7),
                        topRight: simd_float2(-0.21, -0.69))
        
        juliaConstant = simd_float2(-0.22334650856389987, -0.6939525691699604)
        
        super.init()
        
        self.schedulePan()
        self.scheduleZoom()
    }
    
    func schedulePan() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 20) {
            self.region.pan(percent: 0.1)
            self.needRender = true
            self.schedulePan()
        }
    }
    
    func scheduleZoom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 20) {
            self.region.zoom(percent: 0.5)
            self.needRender = true
            self.scheduleZoom()
        }
    }
    
    func onSwitchFractal() {
        switch fractal {
        case .mandelbrot:
            fractal = .julia
            break
        case .julia:
            fractal = .mandelbrot
            break
        }
        needRender = true
    }
    
    func onSwitchColorMap() {
        colorMapIndex = (colorMapIndex + 1) % colorMaps.count
        needRender = true
    }
    
    class func buildRenderPipelineState(name: String,
                                        device: MTLDevice,
                                        mtkView: MTKView,
                                        bundle: Bundle?) throws -> MTLRenderPipelineState {
        let library = bundle != nil
            ? try device.makeDefaultLibrary(bundle: bundle!)
            : device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "\(name)Shader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "MandelbrotRenderPipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        let colorAttachments0 = pipelineDescriptor.colorAttachments[0]!
        colorAttachments0.pixelFormat = mtkView.colorPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func renderMandelbrot(renderEncoder: MTLRenderCommandEncoder) {
        let vertices = [
            FractalVertex(position: simd_float2(1, 1), region: region.topRight),
            FractalVertex(position: simd_float2(-1, 1), region: region.topLeft),
            FractalVertex(position: simd_float2(1, -1), region: region.bottomRight),
            FractalVertex(position: simd_float2(-1, -1), region: region.bottomLeft)
        ]
        let verticesLength = MemoryLayout<FractalVertex>.stride * vertices.count
        uniforms.maxIterations = Int32(maxIterations)
        let colorMap = colorMaps[colorMapIndex]
        let colorMapLength = MemoryLayout<simd_float4>.stride * colorMap.count
        renderEncoder.pushDebugGroup("Draw Fractal")
        renderEncoder.setRenderPipelineState(mandelbrotPipelineState)
        renderEncoder.setVertexBytes(&uniforms, length: uniformsLength, index: 0)
        renderEncoder.setVertexBytes(vertices, length: verticesLength, index: 1)
        renderEncoder.setFragmentBytes(&uniforms, length: uniformsLength, index: 0)
        renderEncoder.setFragmentBytes(colorMap, length: colorMapLength, index: 1)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        renderEncoder.popDebugGroup()
    }
    
    private func renderJulia(renderEncoder: MTLRenderCommandEncoder, juliaConstant: simd_float2) {
        let vertices = [
            FractalVertex(position: simd_float2(1, 1), region: region.topRight),
            FractalVertex(position: simd_float2(-1, 1), region: region.topLeft),
            FractalVertex(position: simd_float2(1, -1), region: region.bottomRight),
            FractalVertex(position: simd_float2(-1, -1), region: region.bottomLeft)
        ]
        let verticesLength = MemoryLayout<FractalVertex>.stride * vertices.count
        uniforms.maxIterations = Int32(maxIterations)
        let colorMap = colorMaps[colorMapIndex]
        let colorMapLength = MemoryLayout<simd_float4>.stride * colorMap.count
        renderEncoder.pushDebugGroup("Draw Fractal")
        renderEncoder.setRenderPipelineState(juliaPipelineState)
        renderEncoder.setVertexBytes(&uniforms, length: uniformsLength, index: 0)
        renderEncoder.setVertexBytes(vertices, length: verticesLength, index: 1)
        renderEncoder.setFragmentBytes(&uniforms, length: uniformsLength, index: 0)
        renderEncoder.setFragmentBytes(colorMap, length: colorMapLength, index: 1)
        var juliaConstant = juliaConstant
        renderEncoder.setFragmentBytes(&juliaConstant, length: MemoryLayout<simd_float2>.stride, index: 2)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        renderEncoder.popDebugGroup()
    }
    
    func draw(in view: MTKView) {
        if !needRender {
            return
        }
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            let renderPassDescriptor = view.currentRenderPassDescriptor
            if let renderPassDescriptor = renderPassDescriptor,
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                switch fractal {
                case .mandelbrot:
                    renderMandelbrot(renderEncoder: renderEncoder)
                    break
                case .julia:
                    renderJulia(renderEncoder: renderEncoder, juliaConstant: juliaConstant)
                    break
                }
                renderEncoder.endEncoding()
            }
            view.currentDrawable.map(commandBuffer.present)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        needRender = false
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        region.adjustAspectRatio(drawableWidth: Float(size.width),
                                 drawableHeight: Float(size.height))
        needRender = true
    }
}
