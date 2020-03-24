//
//  ValidationChecks.swift
//  svg2asset
//
//  Created by Tom Harrington on 2/18/20.
//  Copyright © 2020 Atomic Bird LLC. All rights reserved.
//

import Foundation
import ArgumentParser

extension ValidationError {
    enum DirectoryCheckError: String {
        case missingDirectories = "Input and output directories must exist"
        case noInputResourceValues = "Can't check input directory"
        case inputDirectoryCheckFailed = "Input must be a directory and must be readable"
        case assetCatalogNameError = "Output filename should end with `.xcassets`"
        case noOutputResourceValues = "Can't check output directory"
        case outputDirectoryCheckFailed = "Output must be a directory and must be writeable"
        case assetCatalogNotCreated = "Could not create asset catalog at output path"
        case assetCatalogAlreadyExists = "An asset catalog already exists at the destination"
    }
    init(_ directoryError: DirectoryCheckError) {
        self.init(directoryError.rawValue)
    }
}

extension SVG2AssetArgs {
    mutating func validateDataDirectories() throws {
        // Guard because validation might get called more than once and this function can fail if called twice. May need to rethink that. It happens because the destination URL gets created in this function, and the function fails if the destination already exists.
        guard inputURL == nil, assetCatalogURL == nil else { return }
        let outputDir = (assetCatalog as NSString).deletingLastPathComponent
        
        // Check asset catalog name
        let assetCatalogURL = URL(fileURLWithPath: assetCatalog)
        let assetCatalogName = assetCatalogURL.lastPathComponent
        if (assetCatalogName as NSString).pathExtension != "xcassets" {
            throw ValidationError(.assetCatalogNameError)
        }
        
        // Make sure directories exist
        if !(FileManager.default.fileExists(atPath: inputDir) && FileManager.default.fileExists(atPath: outputDir)) {
            #if DEBUG
            if !FileManager.default.fileExists(atPath: inputDir) && inputDir.hasSuffix("feather/icons") {
                print("To run this code with the built-in Xcode arguments, please initialize the 'feather' submodule.", to: &standardError)
            }
            #endif
            throw ValidationError(.missingDirectories)
        }
        
        if force && FileManager.default.fileExists(atPath: assetCatalogURL.path) {
            print("Overwriting existing asset catalog at destination.")
            try FileManager.default.removeItem(at: assetCatalogURL)
        }
        
        // Make sure input and output dirs are directories and have appropriate permittions.
        let inputURL = URL(fileURLWithPath: inputDir).resolvingSymlinksInPath()
        let outputURL = URL(fileURLWithPath: outputDir)
        
        if let inputURLProperties = try? inputURL.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey]),
            let isDirectory = inputURLProperties.isDirectory,
            let isReadable = inputURLProperties.isReadable {
            if !(isDirectory && isReadable) {
                throw ValidationError(.inputDirectoryCheckFailed)
            }
        } else {
            throw ValidationError(.noInputResourceValues)
        }
        
        if let outputURLProperties = try? outputURL.resourceValues(forKeys: [.isDirectoryKey, .isWritableKey, .isSymbolicLinkKey]),
            let isDirectory = outputURLProperties.isDirectory,
            let isWriteable = outputURLProperties.isWritable {
            if !(isDirectory && isWriteable) {
                throw ValidationError(.outputDirectoryCheckFailed)
            }
        } else {
            throw ValidationError(.noOutputResourceValues)
        }
        
        // Create the asset catalog directory
        if FileManager.default.fileExists(atPath: assetCatalogURL.path) {
            throw ValidationError(.assetCatalogAlreadyExists)
        }
        
        do {
            try FileManager.default.createDirectory(at: assetCatalogURL, withIntermediateDirectories: false, attributes: nil)
        } catch {
            throw ValidationError(.assetCatalogNotCreated)
        }
        
        self.inputURL = inputURL
        self.assetCatalogURL = assetCatalogURL
    }
    
    mutating func validateSvg2Pdf() throws {
        guard svg2pdfURL == nil else { return }
        svg2pdfURL = URL(fileURLWithPath: "/usr/local/bin/svg2pdf")
        if !FileManager.default.fileExists(atPath: svg2pdfURL.path) {
            throw ValidationError("Could not find svg2pdf. Please install it via HomeBrew")
        }
    }
    
    var swiftGenURL: URL? {
        // /usr/local/bin/swiftgen
        let swiftGenURL = URL(fileURLWithPath: "/usr/local/bin/swiftgen")
        if FileManager.default.fileExists(atPath: swiftGenURL.path) {
            return swiftGenURL
        } else {
            return nil
        }
    }

}
