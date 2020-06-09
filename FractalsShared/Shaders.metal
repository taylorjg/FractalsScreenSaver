//
//  Shaders.metal
//  FractalsShared
//
//  Created by Administrator on 22/05/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

typedef struct {
    float4 position [[position]];
    float2 region;
} FractalInOut;

vertex FractalInOut vertexShader(uint vertexID [[vertex_id]],
                                 constant FractalUniforms &uniforms [[buffer(0)]],
                                 constant FractalVertex *vertices [[buffer(1)]])
{
    constant FractalVertex &fractalVertex = vertices[vertexID];
    
    float4 position = float4(fractalVertex.position, 0, 1);
    
    FractalInOut out {
        .position = uniforms.modelViewMatrix * position,
        .region = fractalVertex.region
    };
    
    return out;
}

float4 loop(int maxIterations, constant float4 *colorMap, float2 c, float2 z)
{
    int divergesAt = maxIterations - 1;
    for (int iteration = 0; iteration < maxIterations; iteration++) {
        if (dot(z, z) >= 4.0) {
            divergesAt = iteration;
            break;
        }
        z = float2(z.x * z.x - z.y * z.y + c.x, 2.0 * z.x * z.y + c.y);
    }
    int index = 256 * divergesAt / maxIterations;
    return colorMap[index];
}

fragment float4 mandelbrotShader(FractalInOut in [[stage_in]],
                                 constant FractalUniforms &uniforms [[buffer(0)]],
                                 constant float4 *colorMap [[buffer(1)]])
{
    return loop(uniforms.maxIterations, colorMap, in.region, float2());
}

fragment float4 juliaShader(FractalInOut in [[stage_in]],
                            constant FractalUniforms &uniforms [[buffer(0)]],
                            constant float4 *colorMap [[buffer(1)]],
                            constant float2 &juliaConstant [[buffer(2)]])
{
    return loop(uniforms.maxIterations, colorMap, juliaConstant, in.region);
}
