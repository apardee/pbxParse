//
//  ParsedNode.swift
//  pbxParse
//
//  Created by Anthony Pardee on 11/1/15.
//  Copyright © 2015 Anthony Pardee. All rights reserved.
//

import Foundation

protocol ParsedNode {
    
    /// Dump the string representation of the structured node.
    func dump() -> String
}

extension ParsedNode {
    
    /// Recursively dump the content of all child nodes.
    func dumpWithNodes(nodes : [ParsedNode]) -> String {
        var value = ""
        nodes.forEach{ value += $0.dump() }
        return value
    }
}
