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
	// Seperate vertex shader is not supported: Fragment type includes both vs/fs
//	case Vertex = 2
}

struct Shader {
	
	var type: ShaderType
	var activeVertexFunction: String
	var activeFragmentFunction: String
	var activeComputeFunction: String
	var source: String
	
	var library: MTLLibrary?
	
	/// Returns a dictionary representation of the shader.
	///
	/// - Returns: An NSDictionary representing the shader.
	func asDict() -> NSDictionary {
		let dict = NSDictionary(
			objects: [NSNumber.init(integerLiteral: type.rawValue), activeVertexFunction, activeFragmentFunction, activeComputeFunction, source],
			forKeys: ["ShaderType" as NSCopying, "VertexFunction" as NSCopying, "FragmentFunction" as NSCopying, "ComputeFunction" as NSCopying, "Source" as NSCopying])
		return dict
	}
}

/// Contains a list of the functions in the shader
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
	
	@IBOutlet weak var pragmaSelector: NSPopUpButton!
	var pragmas: [(String, Int)] = []
	
	@IBOutlet weak var functionSelector1: NSPopUpButton!
	@IBOutlet weak var functionSelector2: NSPopUpButton!
	
	// The line numbers are handled by an NSRulerView
	var ruler: NSRulerView!
	
	// The preview window
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
	
	/// Sets the shader after loading from file
	///
	/// - Parameter newShader: THe loaded Shader value
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
	
	
	/// Switch between Fragment and Compute output
	///
	/// - Parameter sender: Shader type is set by an NSPopupButton's selected index
	@IBAction func selectShaderType(_ sender: NSPopUpButton) {
		guard let type = ShaderType.init(rawValue: sender.indexOfSelectedItem) else {
			print("Unsupported type!")
			return
		}
		self.shader.type = type
		typeSelectorPopup.selectItem(at: shader.type.rawValue)
		updateFunctionLists()
	}
	
	/// Selects between multiple functions in a file
	///
	/// - Parameter sender: Selected from NSPopupButton's selected index
	@IBAction func selectFunction(_ sender: NSPopUpButton) {
		let idx = sender.indexOfSelectedItem
		
		if shader.type == .Compute {
			// Set the compute function name
			shader.activeComputeFunction = functionList.compute[idx]
		} else {
			// Set vertex or fragment, determined by sender tag as there are two NSPopupButtons
			if sender.tag == 0 {
				shader.activeVertexFunction = functionList.vertex[idx]
			} else {
				shader.activeFragmentFunction = functionList.fragment[idx]
			}
		}
		previewVC.updateShader(shader)
	}
	
	/// Shows or hides the preview window
	public func showPreview() {
		if previewWC.window!.isVisible {
			previewWC.close()
		} else {
			previewWC.showWindow(nil)
		}
	}
	
	/// Called when the user selects an item from the jump list. 
	/// Determines where that item is, scrolls to it.
	///
	/// - Parameter sender: NSPopupButton's selected index selects the item.
	@IBAction func jumpTo(_ sender: NSPopUpButton) {
		guard sender.indexOfSelectedItem < pragmas.count else { return }
		
		// Get the line number of this item
		let lineNo = pragmas[sender.indexOfSelectedItem].1
		
		// get visible rect
		let src = editView.string! as NSString
		let line = src.components(separatedBy: .newlines)[lineNo]
		let range = src.range(of: line)
		
		// Find the visible rect for the line
		let manager = editView.layoutManager
		let container = editView.textContainer
		let rect = manager!.boundingRect(forGlyphRange: range, in: container!)
		
		// we want this at the top, so change the size
		let showRect = NSRect(
			x: 0.0,
			y: rect.origin.y,
			width: editScrollView.frame.size.width,
			height: editScrollView.frame.size.height
		)
		
		editView.scrollToVisible(showRect)
	}
	
	func textDidChange(_ notification: Notification) {
		// Update the ruler when the text changes, or it stays blank when new lines are created!
		ruler.setNeedsDisplay(ruler.visibleRect)
		
		// Update the shader's source variable
		guard let src = editView.string else { return }
		shader.source = src.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	@IBAction func showWindow(_ sender: NSMenuItem) {
		
	}
	
	/// Compiles the shader and handles view updates etc.
	///
	/// - Parameter sender: A button or menu or keyboard shortcut, ignored.
	@IBAction func compileShader(_ sender: Any) {
		// Attempt to compile a shader
		
		// Clear the log view's text
		logView.string = ""
		
		guard let dev = mtlDev, let s = editView.string else {
			return
		}
		
		let src = s as NSString
		
		// Find the visible text area, because reseting the colour causes it to lose place
		let rect = editScrollView.visibleRect
		
		// Reset the text to black, reset the scroll position
		editView.setTextColor(NSColor.black, range: NSRange.init(location: 0, length: src.length))
		editScrollView.scrollToVisible(rect)
		
		// Attempt to compile the shader
		let lib: MTLLibrary
		shader.library = nil
		
		do {
			lib = try dev.makeLibrary(source: s, options: nil)
			
		} catch (let error as MTLLibraryError)  {
			// Compilation failed. Update the log view, highlight errors
//			print(error)
			
			switch error.code {
			case .compileFailure:
				// Get the error message, parse it
				let errorString = error.errorUserInfo[NSLocalizedDescriptionKey]! as! String
				
				// The log view just gets the raw message:
				logView.string = errorString
				
				// Separate into errors
				
				// Errors are in the format:
				// <program source>:40:1: error: unknown type name 'faewa'
				
				let errors = errorString.components(separatedBy: "<program source>")
				
				for err in errors {
					let offsets = err.components(separatedBy: ":")
					
					// Safety check:
					if offsets.count < 3 { continue }
					
					// Find line / character offsets
					let lineNo = Int(offsets[1])!
					//					let charNo = Int(offsets[2])! // Not used at present
					
					// get line, then find it's range
					let line = src.components(separatedBy: CharacterSet.newlines)[lineNo - 1]
					let range = src.range(of: line)
					
					// Mark this range in red
					editView.setTextColor(NSColor.red, range: range)
					
				}
			default:
				// TODO: Handle "compiled with warnings" case
				print("unhandled")
			}
			return
		} catch {
			print ("unhandled")
			return
		}
		
		// Update the shader library, the function list, and update the preview with the new libary
		shader.library = lib
		findFunctions()
		previewVC.updateShader(shader)
	}
	
	/// Gets the list of functions from the libary
	private func findFunctions() {
		var vertexFunctions = [String]()
		var fragmentFunctions = [String]()
		var computeFunctions = [String]()
		
		// Parse the source, look for lines beginning 'vertex', 'fragment' or 'kernel'
		for line in shader.source.components(separatedBy: .newlines) {
			// There's a minimum line length, skip if below that:
			if line.characters.count < 10 { continue }
			
			// Get the first section of the line
			let char7 = line.substring(to: shader.source.index(shader.source.startIndex, offsetBy: 7))
			let char9 = line.substring(to: shader.source.index(shader.source.startIndex, offsetBy: 9))
			
			// Check to see if it matches, if so append it to the relevant list:
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
		
		// Update the function list
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
		
		// Update the displayed lists and the jump list
		updateFunctionLists()
		updateJumpList()
	}
	
	
	private func updateJumpList() {
		// TODO: Search for all functions
		// Just search for "#pragma mark" for now
		
		let lines = shader.source.components(separatedBy: .newlines)
		for i in 0..<lines.count {
			let line = lines[i]
			
			// Skip short lines that can't be what we need
			if line.characters.count < 13 { continue }
			
			// Search the start of the line for #pragma
			let startChars = line.substring(to: shader.source.index(shader.source.startIndex, offsetBy: 13))
			
			if startChars == "#pragma mark " {
				// We have a mark line
				let restOfLine = line.substring(from: shader.source.index(shader.source.startIndex, offsetBy: 13)).trimmingCharacters(in: .whitespacesAndNewlines)
				pragmas.append((restOfLine, i))
			}
		}

		// Update the on-screen list
		pragmaSelector.removeAllItems()
		for pragma in pragmas {
			pragmaSelector.addItem(withTitle: pragma.0)
		}
	}
	
	/// Updates the on-screen function lists
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

