//
//  main.swift
//  svg2asset
//
//  Created by Tom Harrington on 2/18/20.
//  Copyright © 2020 Atomic Bird LLC. All rights reserved.
//

import Foundation
import ArgumentParser

// Set up printing to stderr
var standardError = FileHandle.standardError
extension FileHandle : TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

struct SVG2AssetArgs: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: ProcessInfo.processInfo.processName,
        abstract: "Convert SVGs to PDF asset catalog.",
        discussion: "This tool converts a folder containing SVGs to an Xcode asset catalog and, optionally, can use SwiftGen to create Swift source code for the catalog.")
    
    @Option(name: .shortAndLong, default: ".", help: ArgumentHelp("Input directory containing SVGs", valueName: "dir"))
    var inputDir: String
    
    @Option(name: .shortAndLong, default: "./Assets.xcassets", help: ArgumentHelp("Path to output asset catalog.", valueName: "path"))
    var assetCatalog: String
    
    @Flag(name: .shortAndLong, help: "Print verbose output")
    var verbose: Bool
    
    @Flag(name: .shortAndLong, help: "Overwrite an asset catalog at the destination, if it exists.")
    var force: Bool
    
    @Flag(name: .long, help: "Use SwiftGen to generate code for the asset catalog (if SwiftGen is installed).")
    var swiftGen: Bool
    
    @Flag(name: .long, default: false, inversion: .prefixedNo, exclusivity: .exclusive, help: "Require serial processing instead of concurrent.")
    var serial: Bool

    @Option(name: .long, parsing: .upToNextOption, help: ArgumentHelp("List of names of files to convert. If this is omitted, all icons are converted."))
    var iconNames: [String]
    
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
do {
    try contentsJSONString.write(to: contentsJSONURL, atomically: true, encoding: .utf8)
} catch {
    print("Could not create asset catalog at destination: \(error)", to: &standardError)
    exit(-1)
}

var inputFileList: [URL] = {
    do {
        return try FileManager.default.contentsOfDirectory(at: args.inputURL, includingPropertiesForKeys: nil, options: [])
    } catch {
        print("Could not read contents of directory at \(args.inputDir)", to: &standardError)
        exit(-1)
    }
}()

// Filter the file list by --icon-names, if that argument was used.
if !args.iconNames.isEmpty {
    inputFileList = inputFileList.filter {
        args.iconNames.contains($0.lastPathComponent)
    }
}

// Sort URLs alphabetically by file name so verbose output will make more sense. By default the order is not guaranteed, and it makes more sense to be ordered when seeing names go by.
inputFileList.sort { (url1, url2) -> Bool in
    return url1.path < url2.path
}

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted

var imageCount = 0

// Set up a dispatch group and queue to support parallel file conversions.
let svg2pdfGroup = DispatchGroup()
let svg2pdfQueue: DispatchQueue = {
    if args.serial {
        return DispatchQueue(label:"svg2asset queue")
    } else {
        return DispatchQueue(label: "svg2asset queue", qos: .default, attributes: .concurrent, autoreleaseFrequency: .never, target: nil)
    }
}()
// Use a semaphore to wait until the dispatch group finishes.
let loopCompleteSemaphore = DispatchSemaphore(value: 0)

print("Converting SVG images at \(args.inputURL.path) to assets at \(args.assetCatalogURL.path)")
for inputFileURL in inputFileList where inputFileURL.pathExtension == "svg" {
    svg2pdfGroup.enter()
    svg2pdfQueue.async {
        defer {
            svg2pdfGroup.leave()
        }
        let svgName = (inputFileURL.lastPathComponent as NSString).deletingPathExtension
        if args.verbose {
            print("Processing \(inputFileURL.lastPathComponent)")
        }
        let currentAssetURL = args.assetCatalogURL.appendingPathComponent("\(svgName).imageset")
        do {
            try FileManager.default.createDirectory(at: currentAssetURL, withIntermediateDirectories: false, attributes: nil)
        } catch {
            print("Could not create asset folder for \(svgName), skipping", to: &standardError)
            return
        }
        
        let pdfName = "\(svgName).pdf"
        let assetInfo = AssetInfo.universalTemplateAsset(for: pdfName)
        
        guard let assetInfoJSON = try? encoder.encode(assetInfo) else {
            print("Could not encode JSON for \(svgName), skipping", to: &standardError)
            return
        }
        
        let contentsJSONURL = currentAssetURL.appendingPathComponent("Contents.json")
        do {
            try assetInfoJSON.write(to: contentsJSONURL)
        } catch {
            print("Could not write JSON for \(svgName), skipping", to: &standardError)
            return
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
                print("Conversion to PDF failed: \(stdErrString)", to: &standardError)
            } else {
                print("Conversion to PDF failed", to: &standardError)
            }
            return
        }
        
        DispatchQueue.global().async {
            imageCount += 1
        }
    }
}

svg2pdfGroup.notify(queue: svg2pdfQueue) {
    loopCompleteSemaphore.signal()
}


loopCompleteSemaphore.wait()
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
