//
//  AppDelegate.swift
//  Metaltoy
//
//  Created by Chris Wood on 27/02/2017.
//  Copyright © 2017 Interealtime. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
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
		return false
	}
}

