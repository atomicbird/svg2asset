//
//  main.swift
//  svg2asset
//
//  Created by Tom Harrington on 2/18/20.
//  Copyright © 2020 Atomic Bird LLC. All rights reserved.
//

import Foundation
import DashDashSwift

let svg2pdfURL = ValidationChecks.converterURL()

var parser = CommandLineParser(title: "svg2asset", description: "Convert SVGs to PDF asset catalog")
//parser.maxLineLength = 100
parser.arguments = CommandLine.arguments

extension CommandLineArgument {
    static let input = CommandLineArgument(key: .input, shortKey: "i", index: 0, description: "Input directory containing SVGs. Default is '.'")
    static let output = CommandLineArgument(key: .output, shortKey: "o", index: 1, description: "Path to output asset catalog. Default is './Assets.xcassets'")
    static let verbose = CommandLineArgument(key: .verbose, shortKey: "v", index: nil, description: "Print verbose output")
    static let help = CommandLineArgument(key: .help, shortKey: "h", index: nil, description: "Print this help message")
    static let force = CommandLineArgument(key: .force, shortKey: "f", index: nil, description: "Overwrite an asset catalog at the destination, if it exists.")
    static let swiftgen = CommandLineArgument(key: .swiftgen, shortKey: "s", index: nil, description: "Use SwiftGen to generate code for the asset catalog (if SwiftGen is installed).")
}

enum CommandLineArgumentKeys: String {
    case input
    case output
    case verbose
    case help
    case force
    case swiftgen
}

parser.register(arg: .input)
parser.register(arg: .output)
parser.register(arg: .verbose)
parser.register(arg: .help)
parser.register(arg: .force)
parser.register(arg: .swiftgen)

if parser.bool(forKey: .help) {
    parser.printHelp()
    exit(0)
}

let inputURL: URL
let assetCatalogURL: URL

do {
    (inputURL, assetCatalogURL) = try ValidationChecks.dataDirectories(with: parser)
} catch {
    if let validationError = error as? ValidationChecks.DirectoryCheckError {
        print("\(validationError.rawValue)")
    } else {
        print("\(error)")
    }
    exit(-1)
}

// Asset catalog dir exists at this point.

// Write Contents.json
let contentsJSONString = """
{
    "info" : {
        "version" : 1,
        "author" : "xcode"
    }
}
"""

let contentsJSONURL = assetCatalogURL.appendingPathComponent("Contents.json")
try? contentsJSONString.write(to: contentsJSONURL, atomically: true, encoding: .utf8)

guard var inputFileList = try? FileManager.default.contentsOfDirectory(at: inputURL, includingPropertiesForKeys: nil, options: []) else {
    exit(-1)
}

// Sort URLs alphabetically by file name. By default the order is not guaranteed, and it makes more sense to be ordered when seeing names go by.
inputFileList.sort { (url1, url2) -> Bool in
    return url1.path < url2.path
}

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted

var imageCount = 0

print("Converting SVG images at \(inputURL.path) to assets at \(assetCatalogURL.path)")
for inputFileURL in inputFileList where inputFileURL.pathExtension == "svg" {
//    print("Input: \(inputFileURL)")
    let svgName = (inputFileURL.lastPathComponent as NSString).deletingPathExtension
    if parser.bool(forKey: .verbose) {
        print("Processing \(inputFileURL.lastPathComponent)")
    }
    let currentAssetURL = assetCatalogURL.appendingPathComponent("\(svgName).imageset")
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
    svg2pdfProcess.executableURL = svg2pdfURL
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

if parser.bool(forKey: .swiftgen), let swiftGenURL = ValidationChecks.swiftGenURL() {
    let assetCatalogName = (assetCatalogURL.lastPathComponent as NSString).deletingPathExtension
    let outputFileURL = assetCatalogURL.deletingLastPathComponent().appendingPathComponent("\(assetCatalogName).swift")
    print("Generating Swift code via SwiftGen at \(outputFileURL.path)")
    // Currently letting SwiftGen decide whether to overwrite the file, so there's no --force check here.
    let swiftGenProcess = Process()
    swiftGenProcess.executableURL = swiftGenURL
    swiftGenProcess.arguments = ["xcassets",
                                 "--templateName", "swift4",
                                 "--output", outputFileURL.path,
                                 "--param", "enumName=\(assetCatalogName)Assets",
                                 assetCatalogURL.path
    ]
    swiftGenProcess.launch()
    swiftGenProcess.waitUntilExit()
}
