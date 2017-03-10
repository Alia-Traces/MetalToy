//
//  Document.swift
//  Metaltoy
//
//  Created by Chris Wood on 27/02/2017.
//  Copyright © 2017 Interealtime. All rights reserved.
//

import Cocoa

class Document: NSDocument {

	var shader: Shader?
	
	override init() {
	    super.init()
		// Add your subclass-specific initialization here.
	}

	override class func autosavesInPlace() -> Bool {
		return true
	}

	override func makeWindowControllers() {
		// Returns the Storyboard that contains your Document window.
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
		self.addWindowController(windowController)
		
		// Once the document window is initialised we can set the loaded shader up.
		if let s = shader {
			let vc = windowControllers[0].window?.contentViewController as! EditorViewController
			
			vc.setShader(s)
		}
	}

	override func data(ofType typeName: String) throws -> Data {
		// Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
		// You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
		
		// We're using write: instead
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
	}

	override func read(from url: URL, ofType typeName: String) throws {
		// Load the file. It's a .plist, so should load in as a dictionary:
		guard let dict = NSDictionary(contentsOf: url) as! Dictionary<String, Any>? else {
			Swift.print("Failed to read from URL: \(url)")
			throw NSError.init(domain: "Reading file", code: 0, userInfo: nil)
		}
		
		// Make sure we can read all the necessary values in:
		if let type: Int = dict["ShaderType"] as! Int?,
			let vf = dict["VertexFunction"] as! String?,
			let ff = dict["FragmentFunction"] as! String?,
			let cf = dict["ComputeFunction"] as! String?,
			let src = dict["Source"] as! String?,
			let shaderType = ShaderType(rawValue: type) {
			
			// Everything is OK, create the Shader value:
			let loadedShader = Shader(type: shaderType, activeVertexFunction: vf, activeFragmentFunction: ff, activeComputeFunction: cf, source: src, library: nil)
			
			self.shader = loadedShader
		}
	}
	
	override func write(to url: URL, ofType typeName: String) throws {
		// Save the shader as a .plist file
		// TODO: Check this supports multiple open documents
		let vc = windowControllers[0].window?.contentViewController as! EditorViewController
		
		// Get the shader as a dictionary we can save as plist
		let shaderDict = vc.shader.asDict()
		
		let success = shaderDict.write(to: url, atomically: false)
		if !success {
			throw NSError(domain: "File Write", code: 0, userInfo: nil)
		}
	}
}

