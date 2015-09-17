//
//  main.swift
//  pbxParse
//
//  Created by Anthony Pardee on 6/30/15.
//  Copyright © 2015 Anthony Pardee. All rights reserved.
//

import Foundation

extension NSRange {
    
    /// Produce a string index range from the NSRange instance.
    func stringIndexRange() -> Range<String.Index> {
        return Range<String.Index>(
            start: content.startIndex.advancedBy(location),
            end: content.startIndex.advancedBy(location + length))
    }
}

protocol TokenType {
}

/// A basic lexical scanner, capable of producing tokens for the initialized regular expressions.
class Scanner {
    
    private let tokenDefs: [(TokenType, NSRegularExpression)]
    
    /**
        Produces the first available token from the content passed, at the specified range.
        :param: tokenTypes The full content to produce
        :returns: The token produced from the range passed.
    */
    init(tokenTypes: [(TokenType, String)]) {
        
        self.tokenDefs = tokenTypes.map { (token) -> (TokenType, NSRegularExpression) in
            var regex = NSRegularExpression()
            do {
                let newRegex = try NSRegularExpression(
                    pattern: token.1,
                    options: NSRegularExpressionOptions(rawValue: 0))

                regex = newRegex
            }
            catch {
                // TODO ???
            }

            return (token.0, regex)
        }
    }
    
    /**
        Produces the first available token from the content passed, at the specified range.
        :param: content The full content to produce
        :param: range The specific range of the content to scan.
        :returns: The token produced from the range passed.
    */
    func scan(content: String, range: NSRange) -> (TokenType, String, NSRange)? {
        var tokenOut : (TokenType, String, NSRange)? = nil
        
        for tokenDef in tokenDefs {
            let tokenRegex = tokenDef.1
            
            let options = NSMatchingOptions.Anchored
            let matchedRange = tokenRegex.rangeOfFirstMatchInString(content, options: options, range: range)
            
            if (matchedRange.location != NSNotFound) {
                let newRange = matchedRange.stringIndexRange()
                let matchedString = content.substringWithRange(newRange)
                tokenOut = (tokenDef.0, matchedString, matchedRange)
                break
            }
        }
        
        return tokenOut
    }
}

/// A stateful stream of tokens from a set of source content.
class ScannerStream {
    enum ScannerStreamState {
        case Scanning(Int)
        case End
    }
    
    private let contents: String
    private let scanner: Scanner
    
    /// The current state of
    var state = ScannerStreamState.Scanning(0)
    
    required init(contents contentsVal: String, scanner scannerVal: Scanner) {
        contents = contentsVal
        scanner = scannerVal
    }

//    func next() -> (TokenType, String, NSRange)? {
//        let index = -1
//        switch
//    }

    func peek() -> (TokenType, String, NSRange)? {
        return scanner.scan(content, range: NSRange(location: 0, length: 0))
    }
}

///////////////////////////////////////////////////////////////////////////////////

// TODO: Guard against encoding that isn't UTF8
// TODO: THROWS!
func readFile(filePath: String) -> String {
    guard let fileData = NSData(contentsOfFile: "test2.pbxproj"),
        fileDataStr = NSString(data: fileData, encoding: NSUTF8StringEncoding) as? String else {
            return "";
    }
    
    return fileDataStr
}

let content = readFile("test2.pbxproj")

enum SomeToken : TokenType {
    case Comment
    case Quote
    case OpenBracket
    case CloseBracket
    case Equal
    case Terminator
    case Separator
    case ArrayStart
    case ArrayEnd
    case Ident
    case WhiteSpace
}

let tokens : [(TokenType, String)] = [
    (SomeToken.Comment, "\\/\\/.*?\\n|\\/\\*.*?\\*\\/"),
    (SomeToken.Quote, "\".*\""),
    (SomeToken.OpenBracket, "\\{"),
    (SomeToken.CloseBracket, "\\}"),
    (SomeToken.Equal, "="),
    (SomeToken.Terminator, ";"),
    (SomeToken.Separator, ","),
    (SomeToken.ArrayStart, "\\("),
    (SomeToken.ArrayEnd, "\\)"),
    (SomeToken.Ident, "[a-z|A-Z|0-9|_|\\!|\\$|\\*|~|.|\\-|\\@|\\/]+|\".*?\""), // TODO ???
    (SomeToken.WhiteSpace, "\\s+")
]

let scanner = Scanner(tokenTypes: tokens)
let stream = ScannerStream(contents: content, scanner: scanner)

print("\(stream)")
