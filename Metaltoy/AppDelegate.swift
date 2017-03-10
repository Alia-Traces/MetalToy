//
//  AppDelegate.swift
//  Metaltoy
//
//  Created by Chris Wood on 27/02/2017.
//  Copyright © 2017 Interealtime. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSAlertDelegate {



	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
		
		// Test to ensure a metal device is available...
		if MTLCreateSystemDefaultDevice() == nil {
			// The app has an "oh shit" moment
			let alert = NSAlert.init()
			alert.alertStyle = .critical
			alert.messageText = "No Metal capable GPU available"
			alert.informativeText = "Time to upgrade your Mac?"
			
			alert.addButton(withTitle: "Quit")
			alert.addButton(withTitle: "Fix this error")
			
			let okButton = alert.buttons[0]
			okButton.target = self
			okButton.action = #selector(AppDelegate.killApp)
			let fixButton = alert.buttons[1]
			fixButton.target = self
			fixButton.action = #selector(AppDelegate.fixError)
			
			alert.delegate = self
			
			alert.runModal()
		}
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	@IBAction func compileActiveShader(_ sender: Any) {
		guard let vc = getEditorVC() else { return }
		vc.compileShader(sender)
	}

	@IBAction func showPreviewWindow(_ sender: Any) {
		guard let vc = getEditorVC() else { return }
		vc.showPreview()
	}
	
	fileprivate func getEditorVC() -> EditorViewController? {
		guard let window = NSApplication.shared().keyWindow else {
			return nil
		}
		if let vc = window.contentViewController as? EditorViewController {
			return vc
		}
		return nil
		
	}
	
	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		// Prevents opening a blank document at launch
		return false
	}
	
	// Alert button methods
	
	func killApp() {
		exit(EXIT_FAILURE)
	}
	
	func fixError() {
		guard let url = URL(string: "http://www.apple.com/mac/") else {
			exit(EXIT_FAILURE)
		}
		
		NSWorkspace.shared().open(url)
		exit(EXIT_FAILURE)
	}
	
}

