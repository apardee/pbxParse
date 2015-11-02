//
//  ScannerStream.swift
//  pbxParse
//
//  Created by Anthony Pardee on 11/1/15.
//  Copyright © 2015 Anthony Pardee. All rights reserved.
//

import Foundation

enum ScannerStreamState {
    case Scanning(Int)
    case Finished
}

/// A stateful stream of tokens taken from a set of source content.
class ScannerStream<T : ScannerTokenType> {
    
    private let content: String
    private let scanner: Scanner<T>
    private let contentLength: Int
    
    /// The current state of scanning.
    var state = ScannerStreamState.Scanning(0)
    
    /**
     Instantiates a scanner stream
     
     :param: content The full content used to produce tokens sequentially.
     
     :param: scanner Lexical scanning rules and token types.
     */
    required init(content contentsVal: String, scanner scannerVal: Scanner<T>) {
        content = contentsVal
        contentLength = contentsVal.length()
        scanner = scannerVal
        
        if content.length() == 0 {
            state = ScannerStreamState.Finished
        }
    }
    
    /// Produce the next token from the stream, advancing the state of the stream to the next token.
    func next() -> ScannedToken<T>? {
        let tokenOut = peek()
        
        var newState = ScannerStreamState.Finished
        if let token = tokenOut {
            let newStart = token.range.location + token.range.length
            if newStart < contentLength {
                newState = .Scanning(newStart)
            }
        }
        state = newState
        
        return tokenOut
    }
    
    /// Produce the next token from the stream if it matches the token type passed. Produces nil if the token is of another type or the stream has already been exhausted.
    func nextOfType(expected : T) -> ScannedToken<T>? {
        guard let nextToken = peek() where
            nextToken.tokenType == expected else { return nil }
        
        return next()
    }
    
    /// Preview the next token type from the stream, while not advancing the stream to the next token.
    func peek() -> ScannedToken<T>? {
        var tokenOut : ScannedToken<T>? = nil
        
        switch (state) {
        case .Scanning(let position):
            let scanRange = NSRange(location: position, length: contentLength - position)
            tokenOut = scanner.scanNext(content, range: scanRange)
        default:
            break
        }
        return tokenOut
    }
    
    /// Preview the next node, exluding those of the types passed.
    func peekExcluding(excludedTypes : [T]) -> ScannedToken<T>? {
        
        var tokenOut : ScannedToken<T>? = nil
        var currentState = state
        var finished = false
        
        while !finished {
            switch (currentState) {
            case .Scanning(let position):
                let scanRange = NSRange(location: position, length: contentLength - position)
                if let scannedToken = scanner.scanNext(content, range: scanRange) {
                    if !excludedTypes.contains(scannedToken.tokenType) {
                        finished = true
                        tokenOut = scannedToken
                    }
                    else {
                        var newState = ScannerStreamState.Finished
                        let newStart = scannedToken.range.location + scannedToken.range.length
                        if newStart < contentLength {
                            newState = .Scanning(newStart)
                        }
                        currentState = newState
                    }
                }
                else {
                    finished = true
                    currentState = ScannerStreamState.Finished
                }
            default:
                finished = true
            }
        }
        
        return tokenOut
    }
}
