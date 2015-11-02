import Foundation

extension String {
    
    /// The character count for the string.
    func length() -> Int {
        return self.characters.count
    }
    
    func rangeFromNSRange(range : NSRange) -> Range<String.Index>? {
        let from16 = utf16.startIndex.advancedBy(range.location, limit: utf16.endIndex)
        let to16 = from16.advancedBy(range.length, limit: utf16.endIndex)
        if let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self) {
                return from ..< to
        }
        return nil
    }
}

// Load the content from the test project file.
let content = { Void -> String in
    guard let fileData = NSData(contentsOfFile: "testProj.pbxproj"),
        fileDataStr = NSString(data: fileData, encoding: NSUTF8StringEncoding) as? String else {
            return "";
    }
    return fileDataStr
}()

// Create the scanner, with the pbxProj token types.
let scanner = Scanner(tokenTypes: PbxToken.tokenDefs())

// Create a token stream from.
let stream = ScannerStream(content: content, scanner: scanner)

// Parse the project file.
let project = ObjectNode.fromStream(stream)

// Dump the content from the AST produced, proving we can parse and dump something identical.
if let dumpString = project?.dump() {
    print("\(dumpString)")
}

