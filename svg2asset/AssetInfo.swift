//
//  AssetInfo.swift
//  svg2asset
//
//  Created by Tom Harrington on 2/18/20.
//  Copyright © 2020 Atomic Bird LLC. All rights reserved.
//

import Foundation

struct AssetInfo: Codable {
    struct Images: Codable {
        let idiom: String
        let filename: String
    }
    struct ImageInfo: Codable {
        var version: Int = 1
        var author: String = "xcode"
    }
    struct Properties: Codable {
        enum CodingKeys: String, CodingKey {
            case templateRenderingIntent = "template-rendering-intent"
        }
        let templateRenderingIntent: String
    }
    let images: [Images]
    let info: ImageInfo
    let properties: Properties
}

extension AssetInfo {
    static func universalTemplateAsset(for filename:String) -> AssetInfo {
        return AssetInfo(images: [AssetInfo.Images(idiom: "universal", filename: filename)], info: AssetInfo.ImageInfo(), properties: AssetInfo.Properties(templateRenderingIntent: "template"))
    }
}
