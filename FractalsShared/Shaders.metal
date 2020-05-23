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
    
    float4 position = float4(fractalVertex.position, 1.0, 1.0);
    
    FractalInOut out {
        .position = uniforms.modelViewMatrix * position,
        .region = fractalVertex.region
    };
    
    return out;
}

float4 loop(int maxIterations, constant float4 *colormap, float cr, float ci, float zr, float zi)
{
    int divergesAt = maxIterations - 1;
    for (int iteration = 0; iteration < maxIterations; iteration++) {
        float zrNext = zr * zr - zi * zi + cr;
        float ziNext = 2.0 * zr * zi + ci;
        zr = zrNext;
        zi = ziNext;
        if (zr * zr + zi * zi >= 4.0) {
            divergesAt = iteration;
            break;
        }
    }
    int index = 256 * divergesAt / maxIterations;
    return colormap[index];
}

fragment float4 mandelbrotShader(FractalInOut in [[stage_in]],
                                 constant FractalUniforms &uniforms [[buffer(0)]],
                                 constant float4 *colormap [[buffer(1)]])
{
    float cr = in.region.x;
    float ci = in.region.y;
    float zr = 0.0;
    float zi = 0.0;
    return loop(uniforms.maxIterations, colormap, cr, ci, zr, zi);
}

fragment float4 juliaShader(FractalInOut in [[stage_in]],
                            constant FractalUniforms &uniforms [[buffer(0)]],
                            constant float4 *colormap [[buffer(1)]],
                            constant float2 &juliaConstant [[buffer(2)]])
{
    float cr = juliaConstant.x;
    float ci = juliaConstant.y;
    float zr = in.region.x;
    float zi = in.region.y;
    return loop(uniforms.maxIterations, colormap, cr, ci, zr, zi);
}
