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
    
    private struct Configuration {
        let fractal: Fractal
        let juliaConstant: simd_float2
        let region: Region
        let colorMapIndex: Int
        let maxIterations: Int
        // let panDirection: PanDirection
        // let panSpeed: Float
        // let zoomSpeed: Float
    }
    
    private let mtkView: MTKView
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let mandelbrotPipelineState: MTLRenderPipelineState
    private let juliaPipelineState: MTLRenderPipelineState
    private var uniforms: FractalUniforms
    private let uniformsLength = MemoryLayout<FractalUniforms>.stride
    private var colorMaps = [jet, gistStern, ocean, gnuplot, gnuplot2]
    private var currentColorMapIndex = 0
    private var currentFractal = Fractal.mandelbrot
    private var currentJuliaConstant = simd_float2(-0.22334650856389987, -0.6939525691699604)
    private var currentMaxIterations = 128
    private var currentRegion = Region(bottomLeft: simd_float2(-0.22, -0.7),
                                       topRight: simd_float2(-0.21, -0.69))
    private var needRender = true
    private let backgroundDispatchQueue = DispatchQueue.global(qos: .background)
    
    init?(mtkView: MTKView, bundle: Bundle? = nil) {
        self.mtkView = mtkView
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
        
        super.init()
        
//        let configuation = Configuration(fractal: .mandelbrot,
//                                         region: currentRegion,
//                                         colorMapIndex: 0,
//                                         maxIterations: 120)
        self.displayConfiguration(region: currentRegion, fractal: currentFractal, colorMapIndex: currentColorMapIndex)
        self.schedulePan()
        self.scheduleZoom()
    }
    
    private func schedulePan() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 20) {
            self.currentRegion.pan(percent: 0.1)
            self.needRender = true
            self.schedulePan()
        }
    }
    
    private func scheduleZoom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 20) {
            self.currentRegion.zoom(percent: 0.5)
            self.needRender = true
            self.scheduleZoom()
        }
    }
    
    private func evaluatePoint(region: Region, point: simd_float2) -> Int {
        var z = simd_float2()
        let c = simd_float2(point)
        var iteration = 0
        while iteration < currentMaxIterations {
            if simd_dot(z, z) >= 4 {
                break
            }
            let zSquared = simd_float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y)
            z = zSquared + c
            iteration += 1
        }
        return iteration
    }
    
    private func evaluatePoints(region: Region, gridSize: Int) -> [Int] {
        let w = region.topRight.x - region.bottomLeft.x
        let h = region.topRight.y - region.bottomLeft.y
        let dx = w / Float(gridSize + 1)
        let dy = h / Float(gridSize + 1)
        var results = [Int]()
        for row in 1...gridSize {
            let y = region.bottomLeft.y + Float(row) * dy
            for col in 1...gridSize {
                let x = region.bottomLeft.x + Float(col) * dx
                let point = simd_float2(x, y)
                results.append(evaluatePoint(region: region, point: point))
            }
        }
        return results
    }
    
    private func isInteresting(region: Region) -> Bool {
        let gridSize = 3
        let values = evaluatePoints(region: region, gridSize: gridSize)
        return Set(values).count == gridSize * gridSize
    }
    
    private func createRandomRegion() -> Region {
        let cx = Float.random(in: -2...0.75)
        let cy = Float.random(in: -1.5...1.5)
        let sz = Float.random(in: 0.0001...0.001)
        let bottomLeft = simd_float2(cx - sz, cy - sz)
        let topRight = simd_float2(cx + sz, cy + sz)
        return Region(bottomLeft: bottomLeft, topRight: topRight)
    }
    
    private func chooseConfiguration() {
        var iterations = 0
        var region = createRandomRegion()
        while !isInteresting(region: region) {
            region = createRandomRegion()
            iterations += 1
        }
//        print("[chooseConfiguration] iterations: \(iterations)")
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(5)) {
            // let fractal = self.currentFractal == .mandelbrot ? Fractal.julia : Fractal.mandelbrot
            let fractal = Fractal.mandelbrot
            let colorMapIndex = self.colorMaps.indices.randomElement()!
            self.displayConfiguration(region: region, fractal: fractal, colorMapIndex: colorMapIndex)
        }
    }
    
    private func displayConfiguration(region: Region, fractal: Fractal, colorMapIndex: Int) {
        currentFractal = fractal
        currentRegion = region
        let size = mtkView.drawableSize
        let width = Float(size.width)
        let height = Float(size.height)
        currentRegion.adjustAspectRatio(drawableWidth: width, drawableHeight: height)
        currentColorMapIndex = colorMapIndex
        needRender = true
        backgroundDispatchQueue.async(execute: chooseConfiguration)
    }
    
    func onSwitchFractal() {
        switch currentFractal {
        case .mandelbrot:
            currentFractal = .julia
            break
        case .julia:
            currentFractal = .mandelbrot
            break
        }
        needRender = true
    }
    
    func onSwitchColorMap() {
        currentColorMapIndex = (currentColorMapIndex + 1) % colorMaps.count
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
            FractalVertex(position: simd_float2(1, 1), region: currentRegion.topRight),
            FractalVertex(position: simd_float2(-1, 1), region: currentRegion.topLeft),
            FractalVertex(position: simd_float2(1, -1), region: currentRegion.bottomRight),
            FractalVertex(position: simd_float2(-1, -1), region: currentRegion.bottomLeft)
        ]
        let verticesLength = MemoryLayout<FractalVertex>.stride * vertices.count
        uniforms.maxIterations = Int32(currentMaxIterations)
        let colorMap = colorMaps[currentColorMapIndex]
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
            FractalVertex(position: simd_float2(1, 1), region: currentRegion.topRight),
            FractalVertex(position: simd_float2(-1, 1), region: currentRegion.topLeft),
            FractalVertex(position: simd_float2(1, -1), region: currentRegion.bottomRight),
            FractalVertex(position: simd_float2(-1, -1), region: currentRegion.bottomLeft)
        ]
        let verticesLength = MemoryLayout<FractalVertex>.stride * vertices.count
        uniforms.maxIterations = Int32(currentMaxIterations)
        let colorMap = colorMaps[currentColorMapIndex]
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
                switch currentFractal {
                case .mandelbrot:
                    renderMandelbrot(renderEncoder: renderEncoder)
                    break
                case .julia:
                    renderJulia(renderEncoder: renderEncoder, juliaConstant: currentJuliaConstant)
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
        let width = Float(size.width)
        let height = Float(size.height)
        currentRegion.adjustAspectRatio(drawableWidth: width, drawableHeight: height)
        needRender = true
    }
}
