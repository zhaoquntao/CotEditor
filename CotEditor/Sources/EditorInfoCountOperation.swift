/*
 
 EditorInfoCountOperation.swift
 
 CotEditor
 https://coteditor.com
 
 Created by 1024jp on 2017-03-05.
 
 ------------------------------------------------------------------------------
 
 © 2014-2017 1024jp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 https://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */

import Foundation

struct EditorInfoTypes: OptionSet {
    
    let rawValue: Int
    
    static let length     = EditorInfoTypes(rawValue: 1 << 0)
    static let characters = EditorInfoTypes(rawValue: 1 << 1)
    static let lines      = EditorInfoTypes(rawValue: 1 << 2)
    static let words      = EditorInfoTypes(rawValue: 1 << 3)
    static let location   = EditorInfoTypes(rawValue: 1 << 4)
    static let line       = EditorInfoTypes(rawValue: 1 << 5)
    static let column     = EditorInfoTypes(rawValue: 1 << 6)
    static let unicode    = EditorInfoTypes(rawValue: 1 << 7)
    
    static let all: EditorInfoTypes = [.length, .characters, .lines, .words, .location, .line, .column, .unicode]
}



// MARK: -

final class EditorInfoCountOperation: AsynchronousOperation {
    
    struct Result {
        
        var length = 0
        var characters = 0
        var lines = 0
        var words = 0
        var location = 0  // caret location from the beginning of document
        var line = 1      // current line
        var column = 0    // caret location from the beginning of line
        var unicode: String?  // Unicode of selected single character (or surrogate-pair)
        
        var selectedLength = 0
        var selectedCharacters = 0
        var selectedLines = 0
        var selectedWords = 0
    }
    
    
    // MARK: Public Properties
    
    private(set) var result = Result()
    
    
    // MARK: Private Properties
    
    private let string: String
    private let lineEnding: LineEnding
    private let selectedRange: NSRange
    
    private let requiredInfo: EditorInfoTypes
    private let countsLineEnding: Bool
    
    
    
    // MARK: -
    // MARK: Lifecycle
    
    init(string: String, lineEnding: LineEnding, selectedRange: NSRange, requiredInfo: EditorInfoTypes = .all, countsLineEnding: Bool) {
        
        self.string = string
        self.lineEnding = lineEnding
        self.selectedRange = selectedRange
        self.requiredInfo = requiredInfo
        self.countsLineEnding = countsLineEnding
        
        super.init()
    }
    
    
    
    // MARK: Operation Methods
    
    override func main() {
        
        defer {
            self.finish()
        }
        
        guard !self.string.isEmpty else { return }
        
        let nsString = self.string as NSString
        let selectedString = nsString.substring(with: self.selectedRange)
        let hasSelection = !selectedString.isEmpty
        
        // count length
        if self.requiredInfo.contains(.length) {
            let isSingleLineEnding = (self.lineEnding.length == 1)
            let stringForCounting = isSingleLineEnding ? self.string : self.string.replacingLineEndings(with: self.lineEnding)
            self.result.length = stringForCounting.utf16.count
            
            if hasSelection {
                let stringForCounting = isSingleLineEnding ? selectedString : selectedString.replacingLineEndings(with: self.lineEnding)
                self.result.selectedLength = stringForCounting.utf16.count
            }
        }
        
        guard !self.isCancelled else { return }
        
        // count characters
        if self.requiredInfo.contains(.characters) {
            let stringForCounting = self.countsLineEnding ? self.string : self.string.removingLineEndings
            self.result.characters = stringForCounting.countComposedCharacters { (stop) in stop = self.isCancelled }
            
            if hasSelection {
                let stringForCounting = self.countsLineEnding ? selectedString : selectedString.removingLineEndings
                self.result.selectedCharacters = stringForCounting.countComposedCharacters { (stop) in stop = self.isCancelled }
            }
        }
        
        guard !self.isCancelled else { return }
        
        // count lines
        if self.requiredInfo.contains(.lines) {
            self.result.lines = self.string.numberOfLines
            if hasSelection {
                self.result.selectedLines = selectedString.numberOfLines
            }
        }
        
        guard !self.isCancelled else { return }
        
        // count words
        if self.requiredInfo.contains(.words) {
            self.result.words = self.string.numberOfWords
            if hasSelection {
                self.result.selectedWords = selectedString.numberOfWords
            }
        }
        
        // calculate current location
        if self.requiredInfo.contains(.location) {
            let locString = nsString.substring(to: selectedRange.location)
            let stringForCounting = self.countsLineEnding ? locString : locString.removingLineEndings
            self.result.location = stringForCounting.numberOfComposedCharacters
        }
        
        guard !self.isCancelled else { return }
        
        // calculate current line
        if self.requiredInfo.contains(.line) {
            self.result.line = self.string.lineNumber(at: self.selectedRange.location)
        }
        
        guard !self.isCancelled else { return }
        
        // calculate current column
        if self.requiredInfo.contains(.column) {
            let lineRange = nsString.lineRange(for: self.selectedRange)
            let columnLength = self.selectedRange.location - lineRange.location  // as length
            self.result.column = nsString.substring(with: NSRange(location: lineRange.location, length: columnLength)).numberOfComposedCharacters
        }
        
        // unicode
        if self.requiredInfo.contains(.unicode) {
            if selectedString.unicodeScalars.count == 1 {
                self.result.unicode = selectedString.unicodeScalars.first?.codePoint
            }
        }
    }
    
}
