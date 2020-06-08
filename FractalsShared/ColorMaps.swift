//
//  ColorMaps.swift
//  FractalsShared
//
//  Created by Administrator on 22/05/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Foundation

// https://github.com/matplotlib/matplotlib/blob/master/lib/matplotlib/_cm.py
// https://github.com/matplotlib/matplotlib/blob/master/lib/matplotlib/colors.py

let jet = buildColorMap(colorMapData: JET_DATA)
let gistStern = buildColorMap(colorMapData: GIST_STERN_DATA)
let ocean = buildColorMap2(colorMapData: OCEAN_DATA)
let gnuplot = buildColorMap2(colorMapData: GNUPLOT_DATA)
let gnuplot2 = buildColorMap2(colorMapData: GNUPLOT2_DATA)

private struct ColorMapData {
    let red: [[Float]]
    let green: [[Float]]
    let blue: [[Float]]
}

private struct ColorMapData2 {
    let red: (Float) -> Float
    let green: (Float) -> Float
    let blue: (Float) -> Float
}

private let JET_DATA = ColorMapData(
    red: [
        [0, 0, 0],
        [0.35, 0, 0],
        [0.66, 1, 1],
        [0.89, 1, 1],
        [1, 0.5, 0.5]
    ],
    green: [
        [0, 0, 0],
        [0.125, 0, 0],
        [0.375, 1, 1],
        [0.64, 1, 1],
        [0.91, 0, 0],
        [1, 0, 0]
    ],
    blue: [
        [0, 0.5, 0.5],
        [0.11, 1, 1],
        [0.34, 1, 1],
        [0.65, 0, 0],
        [1, 0, 0]
])

private let GIST_STERN_DATA = ColorMapData(
    red: [
        [0, 0, 0],
        [0.0547, 1, 1],
        [0.250, 0.027, 0.250],
        [1, 1, 1]
    ],
    green: [
        [0, 0, 0],
        [1, 0, 0]
    ],
    blue: [
        [0, 0, 0],
        [0.5, 1, 1],
        [0.735, 0, 0],
        [1, 0, 0]
])

private let OCEAN_DATA = ColorMapData2(
    red: gnuplotPaletteFunctions[23],
    green: gnuplotPaletteFunctions[28],
    blue: gnuplotPaletteFunctions[3])

private let GNUPLOT_DATA = ColorMapData2(
    red: gnuplotPaletteFunctions[7],
    green: gnuplotPaletteFunctions[5],
    blue: gnuplotPaletteFunctions[15])

private let GNUPLOT2_DATA = ColorMapData2(
    red: gnuplotPaletteFunctions[30],
    green: gnuplotPaletteFunctions[31],
    blue: gnuplotPaletteFunctions[32])

private let gnuplotPaletteFunctions: [(Float) -> Float] = [
{ (_: Float) -> Float in 0 },
{ (_: Float) -> Float in 0.5 },
{ (_: Float) -> Float in 1 },
{ (x: Float) -> Float in x },
{ (x: Float) -> Float in pow(x, 2) },
{ (x: Float) -> Float in pow(x, 3) },
{ (x: Float) -> Float in pow(x, 4) },
{ (x: Float) -> Float in sqrt(x) },
{ (x: Float) -> Float in sqrt(sqrt(x)) },
{ (x: Float) -> Float in sin(x * Float.pi / 2) },
{ (x: Float) -> Float in cos(x * Float.pi / 2) },
{ (x: Float) -> Float in abs(x - 0.5) },
{ (x: Float) -> Float in pow(2 * x - 1, 2) },
{ (x: Float) -> Float in sin(x * Float.pi) },
{ (x: Float) -> Float in abs(cos(x * Float.pi)) },
{ (x: Float) -> Float in sin(x * 2 * Float.pi) },
{ (x: Float) -> Float in cos(x * 2 * Float.pi) },
{ (x: Float) -> Float in abs(sin(x * 2 * Float.pi)) },
{ (x: Float) -> Float in abs(cos(x * 2 * Float.pi)) },
{ (x: Float) -> Float in abs(sin(x * 4 * Float.pi)) },
{ (x: Float) -> Float in abs(cos(x * 4 * Float.pi)) },
{ (x: Float) -> Float in 3 * x },
{ (x: Float) -> Float in 3 * x - 1 },
{ (x: Float) -> Float in 3 * x - 2 },
{ (x: Float) -> Float in abs(3 * x - 1) },
{ (x: Float) -> Float in abs(3 * x - 2) },
{ (x: Float) -> Float in (3 * x - 1) / 2 },
{ (x: Float) -> Float in (3 * x - 2) / 2 },
{ (x: Float) -> Float in abs((3 * x - 1) / 2) },
{ (x: Float) -> Float in abs((3 * x - 2) / 2) },
{ (x: Float) -> Float in x / 0.32 - 0.78125 },
{ (x: Float) -> Float in 2 * x - 0.84 },
{ (x: Float) -> Float in x < 0.25 ? 4 * x : x < 0.92 ? -2 * x + 1.84 : x / 0.08 - 11.5 },
{ (x: Float) -> Float in abs(2 * x - 0.5) },
{ (x: Float) -> Float in 2 * x },
{ (x: Float) -> Float in 2 * x - 0.5 },
{ (x: Float) -> Float in 2 * x - 1 }
]

private func buildColorMap(colorMapData: ColorMapData) -> [simd_float4] {
    let n = 256
    let rs = makeMappingArray(n: n, adata: colorMapData.red)
    let gs = makeMappingArray(n: n, adata: colorMapData.green)
    let bs = makeMappingArray(n: n, adata: colorMapData.blue)
    return (0..<n).map { i in
        simd_float4(rs[i], gs[i], bs[i], 1)
    }
}

private func buildColorMap2(colorMapData: ColorMapData2) -> [simd_float4] {
    let n = 256
    let rs = makeMappingArray2(n: n, f: colorMapData.red)
    let gs = makeMappingArray2(n: n, f: colorMapData.green)
    let bs = makeMappingArray2(n: n, f: colorMapData.blue)
    return (0..<n).map { i in
        simd_float4(rs[i], gs[i], bs[i], 1)
    }
}

private func makeMappingArray(n: Int, adata: [[Float]]) -> [Float] {
    
    var x = adata.map { e in e[0] }
    let y0 = adata.map { e in e[1] }
    let y1 = adata.map { e in e[2] }
    
    x = x.map { v in v * (Float(n) - 1) }
    
    var lut = [Float](repeating: 0, count: n)
    let xind = (0..<n).map { n in n }
    
    let ind = Array(searchSorted(arr: x, vs: xind)
        .dropFirst()
        .dropLast())
    
    let distances = ind.indices.map { i -> Float in
        let numerator = Float(xind[i + 1]) - x[ind[i] - 1]
        let denominator = Float(x[ind[i]]) - x[ind[i] - 1]
        return numerator / denominator
    }
    
    ind.indices.forEach { i in
        lut[i + 1] = distances[i] * (y0[ind[i]] - y1[ind[i] - 1]) + y1[ind[i] - 1]
    }
    
    lut[0] = y1.first!
    lut[n - 1] = y0.last!
    
    return lut.map(clipZeroToOne)
}

private func searchSorted(arr: [Float], vs: [Int]) -> [Int] {
    var result = [Int](repeating: 0, count: vs.count)
    let arrLen = arr.count
    for i in 0..<vs.count {
        let v = Float(vs[i])
        var added = false
        for j in 0..<arrLen {
            if v <= arr[j] {
                result[i] = j
                added = true
                break
            }
        }
        if !added { result[i] = arrLen }
    }
    return result
}

private func makeMappingArray2(n: Int, f: (Float) -> Float) -> [Float] {
    return linearSpaced(length: n, start: 0, stop: 1)
        .map(f)
        .map(clipZeroToOne)
}

private func linearSpaced(length: Int, start: Float, stop: Float) -> [Float] {
    let step = (stop - start) / (Float(length) - 1)
    var data = (0..<length).map { index in start + Float(index) * step }
    data[length - 1] = stop
    return data
}

private func clipZeroToOne(v: Float) -> Float {
    return simd_clamp(v, 0, 1)
}
