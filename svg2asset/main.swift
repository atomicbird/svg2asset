//
//  main.swift
//  svg2asset
//
//  Created by Tom Harrington on 2/18/20.
//  Copyright © 2020 Atomic Bird LLC. All rights reserved.
//

import Foundation
import ArgumentParser

struct SVG2AssetArgs: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "argtest2",
        abstract: "Convert SVGs to PDF asset catalog.",
        discussion: "This tool converts a folder containing SVGs to an Xcode asset catalog and, optionally, can use SwiftGen to create Swift source code for the catalog.")
    
    @Option(name: .shortAndLong, default: ".", help: "Input directory containing SVGs")
    var inputDir: String
    
    @Option(name: .shortAndLong, default: "./Assets.xcassets", help: "Path to output asset catalog.")
    var assetCatalog: String
    
    @Flag(name: .shortAndLong, help: "Print verbose output")
    var verbose: Bool
    
    @Flag(name: .shortAndLong, help: "Overwrite an asset catalog at the destination, if it exists.")
    var force: Bool
    
    @Flag(name: .shortAndLong, help: "Use SwiftGen to generate code for the asset catalog (if SwiftGen is installed).")
    var swiftGen: Bool
    
    var inputURL: URL!
    var assetCatalogURL: URL!
    var svg2pdfURL: URL!
    
    mutating func validate() throws {
        try validateDataDirectories()
        try validateSvg2Pdf()
    }
}

let args = SVG2AssetArgs.parseOrExit()

// Asset catalog dir exists at this point, because it's created during validation.

// Write Contents.json
let contentsJSONString = """
{
    "info" : {
        "version" : 1,
        "author" : "xcode"
    }
}
"""

let contentsJSONURL = args.assetCatalogURL.appendingPathComponent("Contents.json")
try? contentsJSONString.write(to: contentsJSONURL, atomically: true, encoding: .utf8)

guard var inputFileList = try? FileManager.default.contentsOfDirectory(at: args.inputURL, includingPropertiesForKeys: nil, options: []) else {
    exit(-1)
}

// Sort URLs alphabetically by file name. By default the order is not guaranteed, and it makes more sense to be ordered when seeing names go by.
inputFileList.sort { (url1, url2) -> Bool in
    return url1.path < url2.path
}

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted

var imageCount = 0

print("Converting SVG images at \(args.inputURL.path) to assets at \(args.assetCatalogURL.path)")
for inputFileURL in inputFileList where inputFileURL.pathExtension == "svg" {
//    print("Input: \(inputFileURL)")
    let svgName = (inputFileURL.lastPathComponent as NSString).deletingPathExtension
    if args.verbose {
        print("Processing \(inputFileURL.lastPathComponent)")
    }
    let currentAssetURL = args.assetCatalogURL.appendingPathComponent("\(svgName).imageset")
    do {
        try FileManager.default.createDirectory(at: currentAssetURL, withIntermediateDirectories: false, attributes: nil)
    } catch {
        exit(-1)
    }
    
    let pdfName = "\(svgName).pdf"
    let assetInfo = AssetInfo.universalTemplateAsset(for: pdfName)

    guard let assetInfoJSON = try? encoder.encode(assetInfo) else {
        exit(-1)
    }
    
    let contentsJSONURL = currentAssetURL.appendingPathComponent("Contents.json")
    do {
        try assetInfoJSON.write(to: contentsJSONURL)
    } catch {
        exit(-1)
    }
    
    let pdfURL = currentAssetURL.appendingPathComponent(pdfName)
    
    let svg2pdfProcess = Process()
    svg2pdfProcess.executableURL = args.svg2pdfURL
    svg2pdfProcess.arguments = [inputFileURL.path, pdfURL.path]

    let processStdErr = Pipe()
    let processStdErrHandle = processStdErr.fileHandleForReading
    svg2pdfProcess.standardError = processStdErr
    svg2pdfProcess.launch()
    svg2pdfProcess.waitUntilExit()

    if svg2pdfProcess.terminationStatus != 0 {
        let stdErrData = processStdErrHandle.readDataToEndOfFile()
        if let stdErrString = String(data: stdErrData, encoding: .utf8) {
            print("Conversion to PDF failed: \(stdErrString)")
        } else {
            print("Conversion to PDF failed")
        }
        exit(-1)
    }
    
    imageCount += 1
}

print("Processed \(imageCount) assets")

if args.swiftGen, let swiftGenURL = args.swiftGenURL {
    let assetCatalogName = (args.assetCatalogURL.lastPathComponent as NSString).deletingPathExtension
    let outputFileURL = args.assetCatalogURL.deletingLastPathComponent().appendingPathComponent("\(assetCatalogName).swift")
    print("Generating Swift code via SwiftGen at \(outputFileURL.path)")
    // Currently letting SwiftGen decide whether to overwrite the file, so there's no --force check here.
    let swiftGenProcess = Process()
    swiftGenProcess.executableURL = swiftGenURL
    swiftGenProcess.arguments = ["xcassets",
                                 "--templateName", "swift4",
                                 "--output", outputFileURL.path,
                                 "--param", "enumName=\(assetCatalogName)Assets",
                                 args.assetCatalogURL.path
    ]
    swiftGenProcess.launch()
    swiftGenProcess.waitUntilExit()
}
