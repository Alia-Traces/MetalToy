//
//  ViewController.swift
//  Metaltoy
//
//  Created by Chris Wood on 27/02/2017.
//  Copyright © 2017 Interealtime. All rights reserved.
//

import Cocoa

enum ShaderType: Int {
	case Compute = 0
	case Fragment = 1
//	case Vertex = 2
}

struct Shader {
	var type: ShaderType
	var activeVertexFunction: String
	var activeFragmentFunction: String
	var activeComputeFunction: String
	var source: String
	
	var library: MTLLibrary?
	
	func asDict() -> NSDictionary {
		let dict = NSDictionary(
			objects: [NSNumber.init(integerLiteral: type.rawValue), activeVertexFunction, activeFragmentFunction, activeComputeFunction, source],
			forKeys: ["ShaderType" as NSCopying, "VertexFunction" as NSCopying, "FragmentFunction" as NSCopying, "ComputeFunction" as NSCopying, "Source" as NSCopying])
		return dict
	}
}

struct ShaderFunctionList {
	let vertex: [String]
	let fragment: [String]
	let compute: [String]
}

class EditorViewController: NSViewController, NSTextViewDelegate {

	@IBOutlet var editView: NSTextView!
	@IBOutlet var logView: NSTextView!
	@IBOutlet weak var editScrollView: NSScrollView!
	@IBOutlet weak var typeSelectorPopup: NSPopUpButton!
	
	@IBOutlet weak var functionSelector1: NSPopUpButton!
	@IBOutlet weak var functionSelector2: NSPopUpButton!
	
	
	var ruler: NSRulerView!
	
	var previewWC: NSWindowController!
	var previewVC: PreviewViewController!
	
	var shader = Shader(type: .Compute,
	                    activeVertexFunction: "",
	                    activeFragmentFunction: "",
	                    activeComputeFunction: "",
	                    source: "",
	                    library: nil)
	var functionList: ShaderFunctionList!
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Do any additional setup after loading the view.
		editView.isContinuousSpellCheckingEnabled = false
		editView.isAutomaticSpellingCorrectionEnabled = false
		let font = NSFont.userFixedPitchFont(ofSize: 0.0)
		editView.font = font
		logView.font = font
		
		editView.delegate = self
		
		//		Add a ruler. This is actually the line count view.
		editScrollView.hasVerticalRuler = true
		ruler = RulerWithLineNumbers(scrollView: editScrollView, orientation: NSRulerOrientation.verticalRuler)
		ruler.clientView = editView
		editScrollView.verticalRulerView = ruler
		editScrollView.rulersVisible = true
	}
	
	public func setShader(_ newShader: Shader) {
		shader = newShader
		editView.string = shader.source
		typeSelectorPopup.selectItem(at: shader.type.rawValue)
	}
	
	override func viewWillAppear() {
		
		// Load preview from storyboard
		previewWC = self.storyboard!.instantiateController(withIdentifier: "Preview") as! NSWindowController
		
		showPreview()
		
		self.previewVC = previewWC.window!.contentViewController! as! PreviewViewController
		let view = previewVC.view.subviews[0]
		view.wantsLayer = true
		view.makeBackingLayer()
		view.layer!.backgroundColor = CGColor.black
		
		// Set shader type
		typeSelectorPopup.selectItem(at: shader.type.rawValue)
		
		// Do an initial compile
		compileShader(self)
	}
	
	
	
	@IBAction func selectShaderType(_ sender: NSPopUpButton) {
		guard let type = ShaderType.init(rawValue: sender.indexOfSelectedItem) else {
			print("Unsupported type!")
			return
		}
		self.shader.type = type
		typeSelectorPopup.selectItem(at: shader.type.rawValue)
		updateFunctionLists()
//		entryPointTF.stringValue = shader.entryPoint
	}
	
	@IBAction func selectFunction(_ sender: NSPopUpButton) {
		let idx = sender.indexOfSelectedItem
		
		if shader.type == .Compute {
			// Set the compute function name
			shader.activeComputeFunction = functionList.compute[idx]
		} else {
			// Set vertex or fragment, determined by sender tag
			if sender.tag == 0 {
				shader.activeVertexFunction = functionList.vertex[idx]
			} else {
				shader.activeFragmentFunction = functionList.fragment[idx]
			}
		}
		previewVC.updateShader(shader)
	}
	
	public func showPreview() {
		if previewWC.window!.isVisible {
			previewWC.close()
		} else {
			previewWC.showWindow(nil)
		}
	}
	
	func textDidChange(_ notification: Notification) {
		//		print("Text changed!")
		ruler.setNeedsDisplay(ruler.visibleRect)
		guard let src = editView.string else { return }
		shader.source = src.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	@IBAction func showWindow(_ sender: NSMenuItem) {
		
	}
	
	@IBAction func compileShader(_ sender: Any) {
		// Attempt to compile a shader
		logView.string = ""
		guard let s = editView.string else {
			return
		}
		
		let src = s as NSString
		let rect = editScrollView.visibleRect
		editView.setTextColor(NSColor.black, range: NSRange.init(location: 0, length: src.length))
		editScrollView.scrollToVisible(rect)
		
		let lib: MTLLibrary
		shader.library = nil
		
		do {
			lib = try mtlDev.makeLibrary(source: s, options: nil)
		} catch (let error as MTLLibraryError)  {
			print(error)
			switch error.code {
			case .compileFailure:
				let errorString = error.errorUserInfo[NSLocalizedDescriptionKey]! as! String
				logView.string = errorString
				
				// Separate into errors
				let errors = errorString.components(separatedBy: "<program source>")
				
				for err in errors {
					let offsets = err.components(separatedBy: ":")
					if offsets.count < 3 { continue }
					let lineNo = Int(offsets[1])!
//					let charNo = Int(offsets[2])!
					
					// get line
					let line = src.components(separatedBy: CharacterSet.newlines)[lineNo - 1]
					let range = src.range(of: line)
					
					editView.setTextColor(NSColor.red, range: range)
					
				}
			default:
				print("unhandled")
			}
			return
		} catch {
			print ("unhandle")
			return
		}
		
		shader.library = lib
		findFunctions()
		previewVC.updateShader(shader)
	}
	
	private func findFunctions() {
		var vertexFunctions = [String]()
		var fragmentFunctions = [String]()
		var computeFunctions = [String]()
		
		for line in shader.source.components(separatedBy: "\n") {
			if line.characters.count < 10 { continue }
			let char7 = line.substring(to: shader.source.index(shader.source.startIndex, offsetBy: 7))
			let char9 = line.substring(to: shader.source.index(shader.source.startIndex, offsetBy: 9))
			if char7 == "vertex " {
				if let name = line.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").last {
					vertexFunctions.append(name)
				}
			} else if char7 == "kernel " {
				if let name = line.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").last {
					computeFunctions.append(name)
				}
			} else if char9 == "fragment " {
				if let name = line.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").last {
					fragmentFunctions.append(name)
				}
			}
		}
		
		self.functionList = ShaderFunctionList(vertex: vertexFunctions, fragment: fragmentFunctions, compute: computeFunctions)
		
		// Set default function names
		if shader.activeVertexFunction == "" && vertexFunctions.count > 0 {
			shader.activeVertexFunction = vertexFunctions[0]
		}
		if shader.activeFragmentFunction == "" && fragmentFunctions.count > 0 {
			shader.activeFragmentFunction = fragmentFunctions[0]
		}
		if shader.activeComputeFunction == "" && computeFunctions.count > 0 {
			shader.activeComputeFunction = computeFunctions[0]
		}
		updateFunctionLists()
	}
	
	private func updateFunctionLists() {
		// clear lists
		functionSelector1.removeAllItems()
		functionSelector2.removeAllItems()
		
		var selectedIdx1 = 0
		var selectedIdx2 = 0
		
		if shader.type == .Compute {
			// hide 2nd list
			functionSelector2.isHidden = true
			
			// Add functions
			for i in 0..<functionList.compute.count {
				let name = functionList.compute[i]
				functionSelector1.addItem(withTitle: name)
				if name == shader.activeComputeFunction { selectedIdx1 = i }
			}
		} else {
			// Use both selectors
			functionSelector2.isHidden = false
			
			// Add functions
			for i in 0..<functionList.vertex.count {
				let name = functionList.vertex[i]
				functionSelector1.addItem(withTitle: name)
				if name == shader.activeVertexFunction { selectedIdx1 = i }
			}
			
			for i in 0..<functionList.fragment.count {
				let name = functionList.fragment[i]
				functionSelector2.addItem(withTitle: name)
				if name == shader.activeFragmentFunction { selectedIdx2 = i }
			}
		}
		
		// Select correct index
		functionSelector1.selectItem(at: selectedIdx1)
		functionSelector2.selectItem(at: selectedIdx2)
	}
	
	override var representedObject: Any? {
		didSet {
			// Update the view, if already loaded.
		}
	}
	
	
}

