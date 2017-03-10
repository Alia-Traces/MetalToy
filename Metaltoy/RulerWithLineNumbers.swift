//
//  RulerWithLineNumbers.swift
//  Metaltoy
//
//  Created by Chris Wood on 27/02/2017.
//  Copyright © 2017 Interealtime. All rights reserved.
//

import Cocoa

/// An NSRuler subclass. Provides line numbering for source code, and supports lines that span multiple lines on-screen.
class RulerWithLineNumbers: NSRulerView {

	override init(scrollView: NSScrollView?, orientation: NSRulerOrientation) {
		super.init(scrollView: scrollView, orientation: orientation)
		
		ruleThickness = 40.0
	}
	
	required init(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)
	}
	
	override func drawMarkers(in rect: NSRect) {
		super.drawMarkers(in: rect)
	}
	
	override func drawHashMarksAndLabels(in rect: NSRect) {
		// Exit if no client set
		guard let view = clientView as! NSTextView? else { return }
		
		// Exit if there's no text
		if view.string?.characters.count == 0 { return }
		
		let textString = view.string! as NSString
		
		// Handle insets
		let insetHeight = view.textContainerInset.height
		
		// Everything is relative to the text container
		let relativePoint = self.convert(NSZeroPoint, from: view)
		
		// Preserve the attributes, because we want to match font etc. to the text editor
		let lineNumberAttributes = view.textStorage!.attributes(at: 0, effectiveRange: nil)
		
		// Get the range of visible glyphs in the client text view
		let visibleGlyphRange = view.layoutManager?.glyphRange(forBoundingRect: view.visibleRect, in: view.textContainer!)
		
		let firstVisibleGlyphCharacterIndex = view.layoutManager?.characterIndexForGlyph(at: (visibleGlyphRange?.location)!)
		
		// The number of the first line
		var lineNumber = countNewLinesIn(string: textString, location: 0, length: firstVisibleGlyphCharacterIndex!)
		
		var glyphIndexForStringLine = visibleGlyphRange?.location;
		
		// iterate through the lines and draw
		while (glyphIndexForStringLine! < NSMaxRange(visibleGlyphRange!)) {
			// range of current line in the string
			let characterRangeForStringLine = textString.lineRange(for: NSRange(location: (view.layoutManager?.characterIndexForGlyph(at: glyphIndexForStringLine!))!, length: 0))
			
			let glyphRangeForStringLine = view.layoutManager?.glyphRange(forCharacterRange: characterRangeForStringLine, actualCharacterRange: nil)
			
			var glyphIndexForGlyphLine = glyphIndexForStringLine;
			var glyphLineCount = 0;
			
			// Iterate through the line glyphs to check for multi-line statements
			while (glyphIndexForGlyphLine! < NSMaxRange(glyphRangeForStringLine!)) {
				// check if the current line in the string spread across several lines of glyphs
				var effectiveRange = NSMakeRange(0, 0);
				
				// range of current "line of glyphs". If a line is wrapped then it will have more than one "line of glyphs"
				var lineRect = view.layoutManager?.lineFragmentRect(forGlyphAt: glyphIndexForGlyphLine!, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
				
				// compute Y for line number
				let y = ceil(NSMinY(lineRect!) + relativePoint.y + insetHeight);
				lineRect?.origin.y = y;
				
				// draw line number only if string does not spread across several lines
				if (glyphLineCount == 0) {
					drawLineNumberInRect(lineNumber: lineNumber, lineRect: lineRect!, attributes: lineNumberAttributes, ruleThickness: ruleThickness)
				}
				
				// move to next glyph line
				glyphLineCount += 1
				glyphIndexForGlyphLine = NSMaxRange(effectiveRange);
			}
			
			// Next line
			glyphIndexForStringLine = NSMaxRange(glyphRangeForStringLine!);
			lineNumber += 1
		}
	}
	
	// Just gets the line count
	func countNewLinesIn(string: NSString, location: Int, length: Int) -> Int {
		return string.substring(to: length).components(separatedBy: .newlines).count
	}
	
	// Draws the line number text
	func drawLineNumberInRect(lineNumber: Int, lineRect: NSRect, attributes: [String: Any], ruleThickness: CGFloat) {
		let string = String(lineNumber)
		let attString = NSAttributedString(string: string, attributes: attributes)
		let x = ruleThickness - 5.0 - attString.size().width
		
		let font = attributes[NSFontAttributeName] as! NSFont
		
		var lr = lineRect
		lr.origin.x = x;
		lr.origin.y += font.ascender
		
		attString.draw(with: lr, options: NSStringDrawingOptions())
	}
}
