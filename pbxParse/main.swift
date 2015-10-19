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

protocol ParsedNode {
    
    /// Dump the string representation of the structured nodes
    func dump() -> String
}

extension ParsedNode {
    
    /// Dump the content of all of the contained nodes.
    func dumpWithNodes(nodes : [ParsedNode]) -> String {
        var value = ""
        nodes.forEach{ value += $0.dump() }
        return value
    }
}

// Wraps a token, also consumes comment and
class TokenNode : ParsedNode {
    let primaryToken : ScannedToken<SomeToken>
    let allTokens : [ScannedToken<SomeToken>]
    
    required init(primary : ScannedToken<SomeToken>, otherTokens : [ScannedToken<SomeToken>]) {
        primaryToken = primary
        allTokens = otherTokens
    }
    
    class func fromStream(stream : ScannerStream<SomeToken>, type : SomeToken) -> TokenNode? {
        guard let next = stream.peekExcluding([ .Comment, .WhiteSpace ]) where next.tokenType == type else {
            return nil
        }
        
        var otherTokens = [ScannedToken<SomeToken>]()

        while let previewNext = stream.peek() where
            previewNext.tokenType == .Comment ||
            previewNext.tokenType == .WhiteSpace {

            otherTokens.append(previewNext)
            stream.next()
        }

        let primaryToken = stream.next()!
        otherTokens.append(primaryToken)
        
        return TokenNode(primary: primaryToken, otherTokens: otherTokens)
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
class ObjectNode : ParsedNode {
    let openBracket : TokenNode
    let content : [ObjectEntryNode]
    let closeBracket : TokenNode
    let terminator : TokenNode?
    
    required init(openBracket openBracketVal: TokenNode,
        content contentVal : [ObjectEntryNode],
        closeBracket closeBracketVal : TokenNode,
        terminator terminatorVal : TokenNode?) {
        
        openBracket = openBracketVal
        content = contentVal
        closeBracket = closeBracketVal
        terminator = terminatorVal
    }
    
    class func fromStream(stream : ScannerStream<SomeToken>) -> ObjectNode? {
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
class ObjectEntryNode : ParsedNode {
    let identifier : TokenNode
    let equal : TokenNode
    let objectValue : ObjectValueNode
    let comma : TokenNode?
    
    required init(identifier idval : TokenNode,
        equal eval : TokenNode,
        objectValue objval : ObjectValueNode,
        comma commaval : TokenNode?) {
        
        self.identifier = idval
        self.equal = eval
        self.objectValue = objval
        self.comma = commaval
    }
    
    class func fromStream(stream : ScannerStream<SomeToken>) -> ObjectEntryNode? {
        guard let identifier = TokenNode.fromStream(stream, type: .Identifier),
            let equal = TokenNode.fromStream(stream, type: .Equal),
            let objectValue = ObjectValueNode.fromStream(stream) else {
                return nil
        }
        
        let comma = TokenNode.fromStream(stream, type: .Separator)
        return ObjectEntryNode(identifier: identifier, equal: equal, objectValue: objectValue, comma: comma)
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
class ObjectValueNode : ParsedNode {
    let value : ParsedNode
    let terminator : TokenNode?
    
    required init(value val : ParsedNode, terminator termval : TokenNode?) {
        value = val
        terminator = termval
    }
    
    class func fromStream(stream : ScannerStream<SomeToken>) -> ObjectValueNode? {
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
class ArrayNode : ParsedNode {
    let openParen : TokenNode
    let elements : [ObjectValueNode]
    let closeParen : TokenNode
    let terminator : TokenNode?
    
    init(openParen openval : TokenNode,
        elements eval : [ObjectValueNode],
        closeParen closeval : TokenNode,
        terminator termval : TokenNode?) {
        
        openParen = openval
        elements = eval
        closeParen = closeval
        terminator = termval
    }
    
    class func fromStream(stream : ScannerStream<SomeToken>) -> ArrayNode? {
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

let project = ObjectNode.fromStream(stream)
if let dumpString = project?.dump() {
    print("\(dumpString)")
}

///////////////////////////////////////////////////////////////////////////////////
