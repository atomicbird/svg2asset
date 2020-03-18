//
//  ValidationChecks.swift
//  svg2asset
//
//  Created by Tom Harrington on 2/18/20.
//  Copyright © 2020 Atomic Bird LLC. All rights reserved.
//

import Foundation
import DashDashSwift

class ValidationChecks {
    static func converterURL() -> URL {
        let svg2pdfURL = URL(fileURLWithPath: "/usr/local/bin/svg2pdf")
        if !FileManager.default.fileExists(atPath: svg2pdfURL.path) {
            print("This tool requires svg2pdf. Please install it via HomeBrew")
            exit(-1)
        }
        return svg2pdfURL
    }
    
    static func swiftGenURL() -> URL? {
        // /usr/local/bin/swiftgen
        let swiftGenURL = URL(fileURLWithPath: "/usr/local/bin/swiftgen")
        if FileManager.default.fileExists(atPath: swiftGenURL.path) {
            return swiftGenURL
        } else {
            return nil
        }
    }
    
    enum DirectoryCheckError: String, Error {
        case missingDirectories = "Input and output directories must exist"
        case noInputResourceValues = "Can't check input directory"
        case inputDirectoryCheckFailed = "Input must be a directory and must be readable"
        case assetCatalogNameError = "Output filename should end with `.xcassets`"
        case noOutputResourceValues = "Can't check output directory"
        case outputDirectoryCheckFailed = "Output must be a directory and must be writeable"
        case assetCatalogNotCreated = "Could not create asset catalog at output path"
        case assetCatalogAlreadyExists = "An asset catalog already exists at the destination"
    }
    
    static func dataDirectories(with parser:CommandLineParser) throws -> (URL, URL) {
        let inputDir = parser.string(forKey: .input) ?? "."
        let assetCatalogPath = parser.string(forKey: .output) ?? "./Assets.xcassets"
        let outputDir = (assetCatalogPath as NSString).deletingLastPathComponent

        // Check asset catalog name
        let assetCatalogURL = URL(fileURLWithPath: assetCatalogPath)//.resolvingSymlinksInPath()
        let assetCatalogName = assetCatalogURL.lastPathComponent
        if (assetCatalogName as NSString).pathExtension != "xcassets" {
            throw DirectoryCheckError.assetCatalogNameError
        }
        
        // Make sure directories exist
        if !(FileManager.default.fileExists(atPath: inputDir) && FileManager.default.fileExists(atPath: outputDir)) {
            throw DirectoryCheckError.missingDirectories
        }

        if parser.bool(forKey: .force) && FileManager.default.fileExists(atPath: assetCatalogURL.path) {
            print("Overwriting existing asset catalog at destination.")
            try FileManager.default.removeItem(at: assetCatalogURL)
        }
        
        // Make sure input and output dirs are directories and have appropriate permittions.
        let inputURL = URL(fileURLWithPath: inputDir).resolvingSymlinksInPath()
        let outputURL = URL(fileURLWithPath: outputDir)//.resolvingSymlinksInPath()

        if let inputURLProperties = try? inputURL.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey]),
            let isDirectory = inputURLProperties.isDirectory,
            let isReadable = inputURLProperties.isReadable {
            if !(isDirectory && isReadable) {
                throw DirectoryCheckError.inputDirectoryCheckFailed
            }
        } else {
            throw DirectoryCheckError.noInputResourceValues
        }

        if let outputURLProperties = try? outputURL.resourceValues(forKeys: [.isDirectoryKey, .isWritableKey, .isSymbolicLinkKey]),
//            let isSymbolicLink = outputURLProperties.isSymbolicLink,
            let isDirectory = outputURLProperties.isDirectory,
            let isWriteable = outputURLProperties.isWritable {
//            if isSymbolicLink {
//                if let linkDestination = try? FileManager.default.destinationOfSymbolicLink(atPath: outputURL.path) {
//                    outputURL = URL(fileURLWithPath: linkDestination)
//                    } else {
//
//                    }
//            }
            if !(isDirectory && isWriteable) {
                throw DirectoryCheckError.outputDirectoryCheckFailed
            }
        } else {
            throw DirectoryCheckError.noOutputResourceValues
        }

        // Create the asset catalog directory
        if FileManager.default.fileExists(atPath: assetCatalogURL.path) {
            throw DirectoryCheckError.assetCatalogAlreadyExists
        }
        
        do {
            try FileManager.default.createDirectory(at: assetCatalogURL, withIntermediateDirectories: false, attributes: nil)
        } catch {
            throw DirectoryCheckError.assetCatalogNotCreated
        }
        
        return (inputURL, assetCatalogURL)
    }
}
