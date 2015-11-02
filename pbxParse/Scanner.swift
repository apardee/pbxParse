//
//  Scanner.swift
//  pbxParse
//
//  Created by Anthony Pardee on 11/1/15.
//  Copyright © 2015 Anthony Pardee. All rights reserved.
//

import Foundation

/// The base protocol for a scanned token.
protocol ScannerTokenType : Equatable {
    
}

/// A token scanned by the scanner.
struct ScannedToken<T : ScannerTokenType> {
    let tokenType : T
    let value : String
    let range : NSRange
}

/// A basic lexical scanner, capable of producing tokens from a body of content.
class Scanner<T : ScannerTokenType> {
    
    private let tokenDefs: [(T, NSRegularExpression)]
    
    /**
     Produces the first available token from the content passed, at the specified range.
     
     :param: tokenTypes The full content to produce tokens. Order implies priority.
     */
    init(tokenTypes: [(T, String)]) {
        self.tokenDefs = tokenTypes.map { (token) -> (T, NSRegularExpression) in
            var regex = NSRegularExpression()
            do {
                let newRegex = try NSRegularExpression(
                    pattern: token.1,
                    options: NSRegularExpressionOptions(rawValue: 0))
                
                regex = newRegex
            }
            catch {
            }
            return (token.0, regex)
        }
    }
    
    /**
     Produces the first available token from a content stream, at the specified range.
     
     :param: content The full content to produce
     
     :param: range The specific range of the content to scan.
     
     :returns: The token produced from the range passed.
     */
    func scanNext(content: String, range: NSRange) -> ScannedToken<T>? {
        var scanned : (T, String, NSRange)? = nil
        let options = NSMatchingOptions.Anchored
        
        for tokenDef in tokenDefs {
            let tokenRegex = tokenDef.1
            
            let matchedRange = tokenRegex.rangeOfFirstMatchInString(content, options: options, range: range)
            
            if (matchedRange.location != NSNotFound) {
                if let newRange = content.rangeFromNSRange(matchedRange) {
                    let matchedString = content.substringWithRange(newRange)
                    scanned = (tokenDef.0, matchedString, matchedRange)
                }
                break
            }
        }
        
        var tokenOut : ScannedToken<T>? = nil
        if let finalToken = scanned {
            tokenOut = ScannedToken(tokenType: finalToken.0, value: finalToken.1, range: finalToken.2)
        }
        return tokenOut
    }
}
