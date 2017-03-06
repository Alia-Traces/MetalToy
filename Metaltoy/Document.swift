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
//	var text: String?
	
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
		
		if let s = shader {
			let vc = windowControllers[0].window?.contentViewController as! EditorViewController
			
			vc.setShader(s)
		}
	}

	override func data(ofType typeName: String) throws -> Data {
		// Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
		// You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
	}

	override func read(from url: URL, ofType typeName: String) throws {
		guard let dict = NSDictionary(contentsOf: url) as! Dictionary<String, Any>? else {
			Swift.print("Failed to read from URL: \(url)")
			throw NSError.init(domain: "Reading file", code: 0, userInfo: nil)
		}
		
		if let type: Int = dict["ShaderType"] as! Int?,
			let vf = dict["VertexFunction"] as! String?,
			let ff = dict["FragmentFunction"] as! String?,
			let cf = dict["ComputeFunction"] as! String?,
			let src = dict["Source"] as! String?,
			let shaderType = ShaderType(rawValue: type) {
			
			let loadedShader = Shader(type: shaderType, activeVertexFunction: vf, activeFragmentFunction: ff, activeComputeFunction: cf, source: src, library: nil)
			
			self.shader = loadedShader
//			makeWindowControllers()
		}
	}
	
//	override func read(from data: Data, ofType typeName: String) throws {
//		// Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
//		// You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
//		// If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
//		
//		var format = PropertyListSerialization.PropertyListFormat.xml
//		let readOpts = PropertyListSerialization.ReadOptions.init(rawValue: 0)
//		let dict: Dictionary<String, Any>
//		
//		do {
//			dict = try PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: nil) as! Dictionary<String, Any>
//			
//		} catch {
//			Swift.print("Unable to deserialise property list while loading")
//			return
//		}
//		if let type: Int = dict["ShaderType"], let ep = dict["EntryPoint"], let src = dict["Source"] {
//			let shader = Shader(type: ShaderType.init(rawValue: type), entryPoint: ep, source: src)
//		}
////		self.text = String(bytes: data, encoding: .utf8)
//		
////		makeWindowControllers()
//		
////		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
//	}
	
	override func write(to url: URL, ofType typeName: String) throws {
		
		let vc = windowControllers[0].window?.contentViewController as! EditorViewController
		let shaderDict = vc.shader.asDict()
		
		let success = shaderDict.write(to: url, atomically: false)
		if !success {
			throw NSError(domain: "File Write", code: 0, userInfo: nil)
		}
		
//		do {
//			try string.write(to: url, atomically: true, encoding: .utf8)
//		} catch {
//			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
//		}
	}
}

