//
//  CommandLineParser+Extension.swift
//  svg2asset
//
//  Created by Tom Harrington on 2/19/20.
//  Copyright © 2020 Atomic Bird LLC. All rights reserved.
//

import Foundation
import DashDashSwift

/// Extensions and stuff to allow enumerations for argument names instead of bare strings.

/// This is an approximate duplicate of DashDashSwift's non-public `CommandLineFlag`, modified to use `CommandLineArgumentKeys` instead of strings.
struct CommandLineArgument {
    let key: CommandLineArgumentKeys
    let shortKey: String?
    let index: Int?
    let description: String?
}

extension CommandLineParser {
//    mutating func register(key: CommandLineArgumentKeys, shortKey: String? = nil, index: Int? = nil, description: String? = nil) {
//        self.register(key: key.rawValue, shortKey: shortKey, index: index, description: description)
//    }
    func bool(forKey key: CommandLineArgumentKeys, shortKey: String? = nil, args: [String]? = nil) -> Bool {
        return self.bool(forKey: key.rawValue, shortKey: shortKey, args: args)
    }
    func string(forKey key: CommandLineArgumentKeys, shortKey: String? = nil, index: Int? = nil, args: [String]? = nil) -> String? {
        return self.string(forKey: key.rawValue, shortKey: shortKey, index: index, args: args)
    }
    
    mutating func register(arg:CommandLineArgument) -> Void {
        self.register(key: arg.key.rawValue, shortKey: arg.shortKey, index: arg.index, description: arg.description)
    }
}
