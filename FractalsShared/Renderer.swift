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

enum Fractal {
    case mandelbrot
    case julia
}

struct Configuration {
    var fractal: Fractal
    let juliaConstant: simd_float2
    var region: Region
    var colorMapIndex: Int
    let maxIterations: Int
    // let panDirection: PanDirection
    // let panSpeed: Float
    // let zoomSpeed: Float
}

extension Configuration {
    static let Default = Configuration(fractal: .mandelbrot,
                                       juliaConstant: simd_float2(),
                                       region: Region(bottomLeft: simd_float2(-0.22, -0.7),
                                                      topRight: simd_float2(-0.21, -0.69)),
                                       colorMapIndex: 0,
                                       maxIterations: 120)
}

class Renderer: NSObject, MTKViewDelegate, KeyboardControlDelegate {
    
    private let mtkView: MTKView
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let mandelbrotPipelineState: MTLRenderPipelineState
    private let juliaPipelineState: MTLRenderPipelineState
    private var uniforms: FractalUniforms
    private let uniformsLength = MemoryLayout<FractalUniforms>.stride
    private var currentConfiguration: Configuration
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
        
        currentConfiguration = Configuration.Default
        
        super.init()
        
        displayConfiguration(configuration: currentConfiguration)
        schedulePan()
        scheduleZoom()
    }
    
    private func schedulePan() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 20) {
            self.currentConfiguration.region.pan(percent: 0.1)
            self.needRender = true
            self.schedulePan()
        }
    }
    
    private func scheduleZoom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 20) {
            self.currentConfiguration.region.zoom(percent: 1)
            self.needRender = true
            self.scheduleZoom()
        }
    }
    
    private func evaluatePoint(configuration: Configuration, point: simd_float2) -> Int {
        var z = configuration.fractal == .mandelbrot ? simd_float2() : simd_float2(point)
        let c = configuration.fractal == .mandelbrot ? simd_float2(point) : configuration.juliaConstant
        var iteration = 0
        while iteration < configuration.maxIterations {
            if simd_dot(z, z) >= 4 {
                break
            }
            let zSquared = simd_float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y)
            z = zSquared + c
            iteration += 1
        }
        return iteration
    }
    
    private func evaluatePoints(configuration: Configuration, gridSize: Int) -> [Int] {
        let region = configuration.region
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
                results.append(evaluatePoint(configuration: configuration, point: point))
            }
        }
        return results
    }
    
    private func isInteresting(configuration: Configuration) -> Bool {
        let gridSize = 8
        let values = evaluatePoints(configuration: configuration, gridSize: gridSize)
        return Float(Set(values).count) >= Float(values.count) * 0.6
    }
    
    private func createRandomConfiguration() -> Configuration {
        let fractal = [Fractal.mandelbrot, Fractal.julia].randomElement()!
        let cx = Float.random(in: -2...0.75)
        let cy = Float.random(in: -1.5...1.5)
        let juliaConstant = simd_float2(cx, cy)
        let sz = fractal == .mandelbrot
            ? Float.random(in: 0.005...0.05)
            : Float.random(in: 0.05...0.5)
        let bottomLeft = simd_float2(cx - sz, cy - sz)
        let topRight = simd_float2(cx + sz, cy + sz)
        var region = Region(bottomLeft: bottomLeft, topRight: topRight)
        let drawableWidth = Float(mtkView.drawableSize.width)
        let drawableHeight = Float(mtkView.drawableSize.height)
        region.adjustAspectRatio(drawableWidth: drawableWidth, drawableHeight: drawableHeight)
        var colorMapIndex = currentConfiguration.colorMapIndex
        while colorMapIndex == currentConfiguration.colorMapIndex {
            colorMapIndex = colorMaps.indices.randomElement()!
        }
        let maxIterations = Int.random(in: 40...256)
        return Configuration(fractal: fractal,
                             juliaConstant: juliaConstant,
                             region: region,
                             colorMapIndex: colorMapIndex,
                             maxIterations: maxIterations)
    }
    
    private func chooseConfiguration() {
        var iterations = 0
        var configuration = createRandomConfiguration()
        while !isInteresting(configuration: configuration) {
            configuration = createRandomConfiguration()
            iterations += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(5)) {
            self.displayConfiguration(configuration: configuration)
        }
    }
    
    private func displayConfiguration(configuration: Configuration) {
        currentConfiguration = configuration
        let drawableWidth = Float(mtkView.drawableSize.width)
        let drawableHeight = Float(mtkView.drawableSize.height)
        currentConfiguration.region.adjustAspectRatio(drawableWidth: drawableWidth, drawableHeight: drawableHeight)
        needRender = true
        backgroundDispatchQueue.async(execute: chooseConfiguration)
    }
    
    func onSwitchFractal() {
        switch currentConfiguration.fractal {
        case .mandelbrot:
            currentConfiguration.fractal = .julia
            break
        case .julia:
            currentConfiguration.fractal = .mandelbrot
            break
        }
        needRender = true
    }
    
    func onSwitchColorMap() {
        currentConfiguration.colorMapIndex = (currentConfiguration.colorMapIndex + 1) % colorMaps.count
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
            FractalVertex(position: simd_float2(1, 1), region: currentConfiguration.region.topRight),
            FractalVertex(position: simd_float2(-1, 1), region: currentConfiguration.region.topLeft),
            FractalVertex(position: simd_float2(1, -1), region: currentConfiguration.region.bottomRight),
            FractalVertex(position: simd_float2(-1, -1), region: currentConfiguration.region.bottomLeft)
        ]
        let verticesLength = MemoryLayout<FractalVertex>.stride * vertices.count
        uniforms.maxIterations = Int32(currentConfiguration.maxIterations)
        let colorMap = colorMaps[currentConfiguration.colorMapIndex]
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
            FractalVertex(position: simd_float2(1, 1), region: currentConfiguration.region.topRight),
            FractalVertex(position: simd_float2(-1, 1), region: currentConfiguration.region.topLeft),
            FractalVertex(position: simd_float2(1, -1), region: currentConfiguration.region.bottomRight),
            FractalVertex(position: simd_float2(-1, -1), region: currentConfiguration.region.bottomLeft)
        ]
        let verticesLength = MemoryLayout<FractalVertex>.stride * vertices.count
        uniforms.maxIterations = Int32(currentConfiguration.maxIterations)
        let colorMap = colorMaps[currentConfiguration.colorMapIndex]
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
                switch currentConfiguration.fractal {
                case .mandelbrot:
                    renderMandelbrot(renderEncoder: renderEncoder)
                    break
                case .julia:
                    renderJulia(renderEncoder: renderEncoder, juliaConstant: currentConfiguration.juliaConstant)
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
        let drawableWidth = Float(size.width)
        let drawableHeight = Float(size.height)
        currentConfiguration.region.adjustAspectRatio(drawableWidth: drawableWidth,
                                                      drawableHeight: drawableHeight)
        needRender = true
    }
}
