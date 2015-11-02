//
//  PbxParse.swift
//  pbxParse
//
//  Created by Anthony Pardee on 11/1/15.
//  Copyright © 2015 Anthony Pardee. All rights reserved.
//

import Foundation

// MARK: - Token types

/// All token types in the pbxProj grammar.
enum PbxToken : ScannerTokenType {
    case Comment
    case OpenBracket
    case CloseBracket
    case Equal
    case Terminator
    case Separator
    case ArrayStart
    case ArrayEnd
    case Identifier
    case WhiteSpace
    
    static func tokenDefs() -> [(PbxToken, String)] {
        return [
            (.Comment, "\\/\\/.*?\\n|\\/\\*.*?\\*\\/"),
            (.OpenBracket, "\\{"),
            (.CloseBracket, "\\}"),
            (.Equal, "="),
            (.Terminator, ";"),
            (.Separator, ","),
            (.ArrayStart, "\\("),
            (.ArrayEnd, "\\)"),
            (.Identifier, "(\".+?\")+|([^(\\s|\\{|\\}|=|;|,|\\(|\\)|\\*)]+)"),
            (.WhiteSpace, "\\s+")
        ]
    }
}

// MARK: - AST Node types

/// Wraps a token, also consuming surrounding comments.
struct TokenNode : ParsedNode {
    let primaryToken : ScannedToken<PbxToken>
    let allTokens : [ScannedToken<PbxToken>]
    
    static func fromStream(stream : ScannerStream<PbxToken>, type : PbxToken) -> TokenNode? {
        guard let next = stream.peekExcluding([ .Comment, .WhiteSpace ]) where next.tokenType == type else {
            return nil
        }
        
        var otherTokens = [ScannedToken<PbxToken>]()
        
        while let previewNext = stream.peek() where
            previewNext.tokenType == .Comment ||
                previewNext.tokenType == .WhiteSpace {
                    
                    otherTokens.append(previewNext)
                    stream.next()
        }
        
        let primaryToken = stream.next()!
        otherTokens.append(primaryToken)
        
        return TokenNode(primaryToken: primaryToken, allTokens: otherTokens)
    }
    
    func dump() -> String {
        var valueString = ""
        for token in allTokens {
            valueString += token.value
        }
        return valueString
    }
}

/// Object -> { ObjectEntry+ };
struct ObjectNode : ParsedNode {
    let openBracket : TokenNode
    let content : [ObjectEntryNode]
    let closeBracket : TokenNode
    let terminator : TokenNode?
    
    static func fromStream(stream : ScannerStream<PbxToken>) -> ObjectNode? {
        guard let openBracket = TokenNode.fromStream(stream, type: .OpenBracket) else {
            return nil
        }
        
        var content = [ObjectEntryNode]()
        while let objectEntry = ObjectEntryNode.fromStream(stream) {
            content.append(objectEntry)
        }
        
        guard let closeBracket = TokenNode.fromStream(stream, type: .CloseBracket) else {
            return nil
        }
        
        let terminator = TokenNode.fromStream(stream, type: .Terminator)
        
        return ObjectNode(openBracket: openBracket,
            content: content,
            closeBracket: closeBracket,
            terminator: terminator)
    }
    
    func dump() -> String {
        var nodes = [ParsedNode]()
        nodes.append(openBracket)
        content.forEach{ nodes.append($0) }
        nodes.append(closeBracket)
        if let terminator = terminator {
            nodes.append(terminator)
        }
        return dumpWithNodes(nodes)
    }
}

/// ObjectEntry -> Ident = ObjectValue
struct ObjectEntryNode : ParsedNode {
    let identifier : TokenNode
    let equal : TokenNode
    let objectValue : ObjectValueNode
    let comma : TokenNode?
    
    static func fromStream(stream : ScannerStream<PbxToken>) -> ObjectEntryNode? {
        guard let identifier = TokenNode.fromStream(stream, type: .Identifier),
            let equal = TokenNode.fromStream(stream, type: .Equal),
            let objectValue = ObjectValueNode.fromStream(stream) else {
                return nil
        }
        
        let comma = TokenNode.fromStream(stream, type: .Separator)
        
        return ObjectEntryNode(identifier: identifier,
            equal: equal,
            objectValue: objectValue,
            comma: comma)
    }
    
    func dump() -> String {
        var nodes : [ParsedNode] = [ identifier, equal, objectValue ]
        if let comma = comma {
            nodes.append(comma)
        }
        return dumpWithNodes(nodes)
    }
}

/// ObjectValue -> (Object | Array | Ident);
struct ObjectValueNode : ParsedNode {
    let value : ParsedNode
    let terminator : TokenNode?
    
    static func fromStream(stream : ScannerStream<PbxToken>) -> ObjectValueNode? {
        var value : ParsedNode? = nil
        if let nextToken = stream.peekExcluding([ .Comment, .WhiteSpace ]) {
            switch nextToken.tokenType {
            case .ArrayStart:
                value = ArrayNode.fromStream(stream)
            case .OpenBracket:
                value = ObjectNode.fromStream(stream)
            case .Identifier:
                value = TokenNode.fromStream(stream, type: .Identifier)
            default:
                break
            }
        }
        
        var terminator : TokenNode?
        if let nextToken = stream.peekExcluding([ .Comment, .WhiteSpace ])
            where nextToken.tokenType == .Terminator || nextToken.tokenType == .Separator {
                terminator = TokenNode.fromStream(stream, type: nextToken.tokenType)
        }
        
        let returnVal : ObjectValueNode? = value != nil ? ObjectValueNode(value: value!, terminator: terminator) : nil
        return returnVal
    }
    
    func dump() -> String {
        var nodes : [ParsedNode] = [ value ]
        if let terminator = terminator {
            nodes.append(terminator)
        }
        return dumpWithNodes(nodes)
    }
}

/// Array -> ( ObjectValue+ );
struct ArrayNode : ParsedNode {
    let openParen : TokenNode
    let elements : [ObjectValueNode]
    let closeParen : TokenNode
    let terminator : TokenNode?
    
    static func fromStream(stream : ScannerStream<PbxToken>) -> ArrayNode? {
        guard let openParen = TokenNode.fromStream(stream, type: .ArrayStart) else {
            return nil
        }
        
        var elements = [ObjectValueNode]()
        while let element = ObjectValueNode.fromStream(stream) {
            elements.append(element)
        }
        
        guard let closeParen = TokenNode.fromStream(stream, type: .ArrayEnd) else {
            return nil
        }
        
        let terminator = TokenNode.fromStream(stream, type: .Terminator)
        return ArrayNode(openParen: openParen,
            elements: elements,
            closeParen: closeParen,
            terminator: terminator)
    }
    
    func dump() -> String {
        var nodes = [ParsedNode]()
        nodes.append(openParen)
        elements.forEach{ nodes.append($0) }
        nodes.append(closeParen)
        if let terminator = terminator {
            nodes.append(terminator)
        }
        return dumpWithNodes(nodes)
    }
}
