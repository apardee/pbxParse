//
//  main.swift
//  pbxParse
//
//  Created by Anthony Pardee on 6/30/15.
//  Copyright © 2015 Anthony Pardee. All rights reserved.
//

import Foundation

// Producer of Token objects.
class Scanner<TokenType> {
    private let tokenDefs: [(TokenType, NSRegularExpression)]
    
    init(tokenTypes: [(TokenType, String)]) {
        var tokenDefBuilder = [(TokenType, NSRegularExpression)]()
        
        do {
            // TODO: map??
            for (type, regexStr) in tokenTypes {
                
                let regex = try NSRegularExpression(
                    pattern: regexStr,
                    options: NSRegularExpressionOptions(rawValue: 0))
            
                tokenDefBuilder.append((type, regex))
            }
        }
        catch {
            // TODO: Dump this and re-throw, somehow working in the assignment?
            print("test...")
        }
        
        tokenDefs = tokenDefBuilder
    }
    
    // Produce a new token.
//    func scanNext(stream: ScannerStream) -> (TokenType, String, NSRange) {
//        return (TokenType(), "Nope!", NSRange(0, 0))
//    }
}

class ScannerStream {
    
    init(contents: String) {
        
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

enum SomeToken : Int {
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
    
    let tokens : [(SomeToken, String)] = [
        (.Comment, "\\/\\/.*?\\n|\\/\\*.*?\\*\\/"),
        (.Quote, "\".*\""),
        (.OpenBracket, "\\{"),
        (.CloseBracket, "\\}"),
        (.Equal, "="),
        (.Terminator, ";"),
        (.Separator, ","),
        (.ArrayStart, "\\("),
        (.ArrayEnd, "\\)"),
        (.Ident, "[a-z|A-Z|0-9|_|\\!|\\$|\\*|~|.|\\-|\\@|\\/]+|\".*?\""),
        (.WhiteSpace, "\\s+")
    ]
    
    let scanner = Scanner<SomeToken>(tokenTypes: tokens)
    print("\(scanner)")
    
//    let testStatement = "/* test */"
//    let matchCount = regex.numberOfMatchesInString(content,
//        options: NSMatchingOptions(),
//        range: NSRange(location: 0, length: content.characters.count))
//    
//    print("\(matchCount)")
}

let content = readFile("test2.pbxproj")
try tokenize(content)
print("\(content)")

