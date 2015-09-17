//
//  main.swift
//  pbxParse
//
//  Created by Anthony Pardee on 6/30/15.
//  Copyright © 2015 Anthony Pardee. All rights reserved.
//

import Foundation

protocol TokenType {
}

// Producer of Token objects.
class Scanner {
    private let tokenDefs: [(TokenType, NSRegularExpression)]
    
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
    
    // Produce a new token.
    func scan(content: String, range: NSRange) -> (TokenType, String, NSRange)? {
        var tokenOut : (TokenType, String, NSRange)? = nil
        
        for tokenDef in tokenDefs {
            let tokenRegex = tokenDef.1
            
            let options = NSMatchingOptions.Anchored
            let matchedRange = tokenRegex.rangeOfFirstMatchInString(content, options: options, range: range)
            
            if (matchedRange.location != NSNotFound) {
                // NSRange -> Range<String.Index> coercion.
                let newRange = Range<String.Index>(
                    start: content.startIndex.advancedBy(matchedRange.location),
                    end: content.startIndex.advancedBy(matchedRange.location + matchedRange.length))
                
                let matchedString = content.substringWithRange(newRange)
                tokenOut = (tokenDef.0, matchedString, matchedRange)
                break
            }
        }
    
        print("\(tokenOut)")
        return tokenOut
    }
}



class ScannerStream {
    enum ScannerStreamState { // Sad trombone that this isn't part of the class
        case Scanning(Int)
        case End
    }
    
    let contents: String
    let scanner: Scanner
    var state = ScannerStreamState.Scanning(0)
    
    required init(contents contentsVal: String, scanner scannerVal: Scanner) {
        contents = contentsVal
        scanner = scannerVal
    }

//    func next() -> (TokenType, String, NSRange) {
//        let index = -1
//        switch
//    }

    func peek() -> (TokenType, String, NSRange)? {
        return scanner.scan(content, range: NSRange(location: 0, length: 0))
    }
}

// TODO: Guard against encoding that isn't UTF8
// TODO: THROWS!
func readFile(filePath: String) -> String {
    guard let fileData = NSData(contentsOfFile: "test2.pbxproj"),
              fileDataStr = NSString(data: fileData, encoding: NSUTF8StringEncoding) as? String else {
        return "";
    }
    
    return fileDataStr
}

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

func tokenize(content: String) throws {
    
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

    let testStr = "blah"
    scanner.scan(testStr, range: NSRange(location: 0, length: testStr.characters.count))
    print("\(scanner)")
}

let content = readFile("test2.pbxproj")
//let stream = ScannerStream(contents: content)

//print("\(stringIndex)")

try tokenize(content)
print("\(content)")

