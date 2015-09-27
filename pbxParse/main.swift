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

extension String {
    
    /// The character count for the string.
    func length() -> Int {
        return self.characters.count
    }
}

/// The base protocol for a scanned token, usually an enumerated type.
protocol TokenType {}

/// A basic lexical scanner, capable of producing tokens for the initialized regular expressions.
class Scanner {
    
    enum ScannedToken {
        case Token(TokenType, String, NSRange)
        case End
    }
    
    private let tokenDefs: [(TokenType, NSRegularExpression)]
    
    /**
        Produces the first available token from the content passed, at the specified range.
        
        :param: tokenTypes The full content to produce tokens. Order implies priority.
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
    func scan(content: String, range: NSRange) -> ScannedToken {
        var scanned : (TokenType, String, NSRange)? = nil
        let options = NSMatchingOptions.Anchored
        
        for tokenDef in tokenDefs {
            let tokenRegex = tokenDef.1
            
            let matchedRange = tokenRegex.rangeOfFirstMatchInString(content, options: options, range: range)
            
            if (matchedRange.location != NSNotFound) {
                let newRange = matchedRange.stringIndexRange()
                let matchedString = content.substringWithRange(newRange)
                scanned = (tokenDef.0, matchedString, matchedRange)
                break
            }
        }
        
        var tokenOut = ScannedToken.End
        if let finalToken = scanned {
            tokenOut = ScannedToken.Token(finalToken.0, finalToken.1, finalToken.2)
        }
        return tokenOut
    }
}

/// A stateful stream of tokens from a set of source content.
class ScannerStream {
    enum State {
        case Scanning(Int)
        case Finished
    }
    
    private var content: String
    private let scanner: Scanner
    
    private var contentLength: Int = 0
    
    /// The current state of
    var state = State.Scanning(0)
    
    required init(content contentsVal: String, scanner scannerVal: Scanner) {
        content = contentsVal
        contentLength = contentsVal.length()
        scanner = scannerVal
        
        if content.length() == 0 {
            state = State.Finished
        }
    }
    
    /// Helper for returning whether the stream has been exhausted yet.
    func finished() -> Bool {
        var finished : Bool
        switch (state) {
        case .Finished:
            finished = true
        default:
            finished = false
        }
        return finished
    }
    
    func next() -> Scanner.ScannedToken {
        let token = peek()
        switch token {
        case .Token(_, _, let range):
            let newStart = range.location + range.length
            if newStart >= contentLength {
                state = .Finished
            }
            else {
                state = .Scanning(newStart)
            }
        case .End:
            state = .Finished
        }
        
        return token
    }

    func peek() -> Scanner.ScannedToken {
        var tokenOut : Scanner.ScannedToken!
        switch (state) {
        case .Scanning(let position):
            let scanRange = NSRange(location: position, length: contentLength - position)
            tokenOut = scanner.scan(content, range: scanRange)
        case .Finished:
            tokenOut = .End
        }
        return tokenOut
    }
}

///////////////////////////////////////////////////////////////////////////////////

// TODO: Guard against encoding that isn't UTF8
// TODO: THROWS!
func readFile(filePath: String) -> String {
    guard let fileData = NSData(contentsOfFile: "testProj.pbxproj"),
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
    (SomeToken.Ident, "^[\\w|\\{|\\}|=|;|,|\\(|\\)|\"|\\/|\\*]+"),
    (SomeToken.WhiteSpace, "\\s+")
]

let scanner = Scanner(tokenTypes: tokens)
let stream = ScannerStream(content: content, scanner: scanner)


var scannedTokens = Array<Scanner.ScannedToken>()

while (!stream.finished()) {
    let token = stream.next()
    switch (token) {
    case .Token:
        print("\(token)")
    case .End:
        print("end")
        break
    }
}

print("done...")
print("\(stream.peek())")
