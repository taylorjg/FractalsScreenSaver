//
//  Region.swift
//  FractalsShared
//
//  Created by Administrator on 08/06/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Foundation

struct Region {
    
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
