//
//  Filter.swift
//  Tools
//
//  Created by 杨名宇 on 2020/12/24.
//

import Foundation
import CoreImage

// https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html#//apple_ref/doc/filter/ci/CIZoomBlur

class Filter {
    static func showAllFilters() {
        var filterGroups = [kCICategoryDistortionEffect,
                            kCICategoryGeometryAdjustment,
                            kCICategoryCompositeOperation,
                            kCICategoryHalftoneEffect,
                            kCICategoryColorAdjustment,
                            kCICategoryColorEffect,
                            kCICategoryTransition,
                            kCICategoryTileEffect,
                            kCICategoryGenerator,
                            kCICategoryReduction,
                            kCICategoryGradient,
                            kCICategoryStylize,
                            kCICategorySharpen,
                            kCICategoryBlur,
                            kCICategoryVideo,
                            kCICategoryStillImage,
                            kCICategoryInterlaced,
                            kCICategoryNonSquarePixels,
                            kCICategoryHighDynamicRange,
                            kCICategoryBuiltIn,
                            kCICategoryFilterGenerator]
        for group in filterGroups {
            print("滤镜组名称：\(group)")
            let filters = CIFilter.filterNames(inCategory: group)
            for name in filters {
                let filter = CIFilter(name: name)
                let attributes = filter?.attributes
                print("滤镜名称：\(name)")
                print("滤镜参数：\(attributes)")
            }
        }
    }
}


