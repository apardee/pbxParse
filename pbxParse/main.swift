import Foundation

extension String {
    func rangeFromNSRange(nsRange : NSRange) -> Range<String.Index>? {
        let from16 = utf16.startIndex.advancedBy(nsRange.location, limit: utf16.endIndex)
        let to16 = from16.advancedBy(nsRange.length, limit: utf16.endIndex)
        if let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self) {
                return from ..< to
        }
        return nil
    }
}

extension String {
    
    /// The character count for the string.
    func length() -> Int {
        return self.characters.count
    }
}

/// The base protocol for a scanned token, usually an enumerated type.
protocol ScannerTokenType : Equatable {

}

/// A token scanned by the scanner.
struct ScannedToken<T : ScannerTokenType> {
    let tokenType : T
    let value : String
    let range : NSRange
}

/// A basic lexical scanner, capable of producing tokens for the initialized regular expressions.
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

internal enum ScannerStreamState {
    case Scanning(Int)
    case Finished
}

/// A stateful stream of tokens from a set of source content.
class ScannerStream<T : ScannerTokenType> {
    
    private var content: String
    private let scanner: Scanner<T>
    
    private var contentLength: Int = 0
    
    /// The current state of scanning.
    var state = ScannerStreamState.Scanning(0)
    
    required init(content contentsVal: String, scanner scannerVal: Scanner<T>) {
        content = contentsVal
        contentLength = contentsVal.length()
        scanner = scannerVal
        
        if content.length() == 0 {
            state = ScannerStreamState.Finished
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
    
    func nextOfType(expected : T) -> ScannedToken<T>? {
        guard let nextToken = peek() where
            nextToken.tokenType == expected else { return nil }
        
        return next()
    }

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

///////////////////////////////////////////////////////////////////////////////////

enum SomeToken : ScannerTokenType {
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
}

let tokens = [
    (SomeToken.Comment, "\\/\\/.*?\\n|\\/\\*.*?\\*\\/"),
    (SomeToken.OpenBracket, "\\{"),
    (SomeToken.CloseBracket, "\\}"),
    (SomeToken.Equal, "="),
    (SomeToken.Terminator, ";"),
    (SomeToken.Separator, ","),
    (SomeToken.ArrayStart, "\\("),
    (SomeToken.ArrayEnd, "\\)"),
    (SomeToken.Identifier, "(\".+?\")+|([^(\\s|\\{|\\}|=|;|,|\\(|\\)|\\*)]+)"),
    (SomeToken.WhiteSpace, "\\s+")
]

///////////////////////////////////////////////////////////////////////////////////

//// !$*UTF8*$!
//{
//    files = (
//        8226E19716EFBFFA00FB6107 /* QuartzCore.framework in Frameworks */,
//        8281D007169C7CC400C8BFF5 /* CoreImage.framework in Frameworks */,
//        50C189C915BE3E74005EAFB7 /* CoreData.framework in Frameworks */,
//        504F06281586E09B00812C54 /* CoreAudio.framework in Frameworks */,
//        50F5A84A156C9209007CAC0C /* CoreMedia.framework in Frameworks */,
//        50F5A848156C91FF007CAC0C /* AVFoundation.framework in Frameworks */,
//        50F5A827156B268B007CAC0C /* UIKit.framework in Frameworks */,
//        50F5A829156B268B007CAC0C /* Foundation.framework in Frameworks */,
//        50F5A82B156B268B007CAC0C /* CoreGraphics.framework in Frameworks */,
//        827D3C22171D8DC7000521F1 /* HockeySDK.framework in Frameworks */,
//    );
//}

class ParsedNode<T : ScannerTokenType> {
    required init?(stream: ScannerStream<T>) {
    }
    
    func dump() -> String {
        return String()
    }
}

// Wraps a token, also consumes comment and
class TokenNode : ParsedNode<SomeToken> {
    var primaryToken : ScannedToken<SomeToken>! = nil
    var allTokens : [ScannedToken<SomeToken>]! = [ScannedToken<SomeToken>]()
    
    required init?(stream: ScannerStream<SomeToken>, type: SomeToken) {
        guard let next = stream.peekExcluding([ .Comment, .WhiteSpace ]) where next.tokenType == type else {
            super.init(stream: stream)
            return nil
        }
        
        while let previewNext = stream.peek() where
            previewNext.tokenType == .Comment ||
            previewNext.tokenType == .WhiteSpace {
                
            allTokens.append(previewNext)
            stream.next()
        }
        
        if let finalToken = stream.next() {
            primaryToken = finalToken
            allTokens.append(finalToken)
        }
        
        super.init(stream: stream)
    }
    
    override func dump() -> String {
        var valueString = ""
        for token in allTokens {
            valueString += token.value
        }
        return valueString
    }
}

/// Object -> { ObjectEntry+ };
class ObjectNode : ParsedNode<SomeToken> {
    var openBracket : TokenNode! = nil
    var content : [ObjectEntryNode]! = nil
    var closeBracket : TokenNode! = nil
    var terminator : TokenNode? = nil
    
    required init?(stream: ScannerStream<SomeToken>) {
        let openBracket = TokenNode(stream: stream, type: .OpenBracket)
        if openBracket == nil {
            super.init(stream: stream)
            return nil
        }
        
        var content = [ObjectEntryNode]()
        while let objectEntry = ObjectEntryNode(stream: stream) {
            content.append(objectEntry)
        }
        
        let closeBracket = TokenNode(stream: stream, type: .CloseBracket)
        if closeBracket == nil {
            super.init(stream: stream)
            return nil
        }
        
        self.openBracket = openBracket
        self.content = content
        self.closeBracket = closeBracket
        self.terminator = TokenNode(stream: stream, type: .Terminator)
        
        super.init(stream: stream)
    }
    
    override func dump() -> String {
        var fullValue = openBracket.dump()
        for node in content {
            fullValue += node.dump()
        }
        fullValue += closeBracket.dump()
        if let terminatorValue = terminator {
            fullValue += terminatorValue.dump()
        }
        return fullValue
    }
}

/// ObjectEntry -> Ident = ObjectValue
class ObjectEntryNode : ParsedNode<SomeToken> {
    var identifier : TokenNode! = nil
    var equal : TokenNode! = nil
    var objectValue : ObjectValueNode! = nil
    var comma : TokenNode? = nil
    
    required init?(stream: ScannerStream<SomeToken>) {
        guard let identifier = TokenNode(stream: stream, type: .Identifier),
            let equal = TokenNode(stream: stream, type: .Equal),
            let objectValue = ObjectValueNode(stream: stream) else {
                super.init(stream: stream)
                return nil
        }
        
        self.identifier = identifier
        self.equal = equal
        self.objectValue = objectValue
        self.comma = TokenNode(stream: stream, type: .Separator)
        
        super.init(stream: stream)
    }
    
    override func dump() -> String {
        var fullValue = identifier.dump() + equal.dump() + objectValue.dump()
        if let comma = comma {
            fullValue += comma.dump()
        }
        return fullValue
    }
}

/// ObjectValue -> (Object | Array | Ident);
class ObjectValueNode : ParsedNode<SomeToken> {
    var value : ParsedNode<SomeToken>! = nil
    var terminator : TokenNode?
    
    required init?(stream: ScannerStream<SomeToken>) {
        if let nextToken = stream.peekExcluding([ .Comment, .WhiteSpace ]) {
            switch nextToken.tokenType {
            case .ArrayStart:
                value = ArrayNode(stream: stream)
            case .OpenBracket:
                value = ObjectNode(stream: stream)
            case .Identifier:
                value = TokenNode(stream: stream, type: .Identifier)
            default:
                break
            }
        }
        
        if let nextToken = stream.peekExcluding([ .Comment, .WhiteSpace ])
            where nextToken.tokenType == .Terminator || nextToken.tokenType == .Separator {
            
            self.terminator = TokenNode(stream: stream, type: nextToken.tokenType)
        }
        
        super.init(stream: stream)
        if value == nil {
            return nil
        }
    }
    
    override func dump() -> String {
        var fullValue = value.dump()
        if let terminator = terminator {
            fullValue += terminator.dump()
        }
        return fullValue
    }
}

/// Array -> ( ObjectValue+ );
class ArrayNode : ParsedNode<SomeToken> {
    var openParen : TokenNode! = nil
    var elements : [ObjectValueNode]! = nil
    var closeParen : TokenNode! = nil
    var terminator : TokenNode?
    
    required init?(stream: ScannerStream<SomeToken>) {
        let openParen = TokenNode(stream: stream, type: .ArrayStart)
        if openParen == nil {
            super.init(stream: stream)
            return nil
        }
        
        var elements = [ObjectValueNode]()
        while let element = ObjectValueNode(stream: stream) {
            elements.append(element)
        }
        
        let closeParen = TokenNode(stream: stream, type: .ArrayEnd)
        if closeParen == nil {
            super.init(stream: stream)
            return nil
        }
        
        self.openParen = openParen
        self.elements = elements
        self.closeParen = closeParen
        self.terminator = TokenNode(stream: stream, type: .Terminator)
        
        super.init(stream: stream)
    }
    
    override func dump() -> String {
        var fullValue = openParen.dump()
        for node in elements {
            fullValue += node.dump()
        }
        fullValue += closeParen.dump()
        if let terminatorValue = terminator {
            fullValue += terminatorValue.dump()
        }
        return fullValue
    }
}

///////////////////////////////////////////////////////////////////////////////////

let content = { Void -> String in
    guard let fileData = NSData(contentsOfFile: "testProj.pbxproj"),
        fileDataStr = NSString(data: fileData, encoding: NSUTF8StringEncoding) as? String else {
            return "";
    }
    return fileDataStr
}()

let scanner = Scanner(tokenTypes: tokens)
let stream = ScannerStream(content: content, scanner: scanner)

let project = ObjectNode(stream: stream)
if let dumpString = project?.dump() {
    print("\(dumpString)")
}

///////////////////////////////////////////////////////////////////////////////////
