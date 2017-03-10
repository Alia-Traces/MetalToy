//
//  PreviewViewController.swift
//  Metaltoy
//
//  Created by Chris Wood on 28/02/2017.
//  Copyright © 2017 Interealtime. All rights reserved.
//

/// A square with vertices and text coords
struct Quad {
	let vertices = [
		float4(-1.0,  -1.0, 0.0, 1.0),
		float4(-1.0,  1.0, 0.0, 1.0),
		float4(1.0,  -1.0, 0.0, 1.0),
		float4(1.0,  1.0, 0.0, 1.0)
	]
	
	let texCoords = [
		float2(0.0, 1.0),
		float2(0.0, 0.0),
		float2(1.0, 1.0),
		float2(1.0, 0.0)
	]
}

import Cocoa
import MetalKit

class PreviewViewController: NSViewController {
	
	@IBOutlet weak var previewView: NSView!
	var mtlView: MTKView!
	var mtlViewDelegate: MetalViewDelegate!
	
	@IBOutlet weak var resLabel: NSTextField!
	@IBOutlet weak var fpsLabel: NSTextField!
	@IBOutlet weak var msLabel: NSTextField!
	
	/// Updates the shader value, and updates the display if rendering is paused
	///
	/// - Parameter shader: A shader.
	public func updateShader(_ shader: Shader) {
		mtlViewDelegate.updateShader(shader)
		if mtlView.isPaused { mtlView.draw() }
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		mtlView = MTKView(frame: previewView.frame, device: mtlDev)
		mtlView.framebufferOnly = false
		mtlView.translatesAutoresizingMaskIntoConstraints = false
		
		// Configure the delegate
		mtlViewDelegate = MetalViewDelegate()
		mtlViewDelegate.fpsLabel = fpsLabel
		mtlViewDelegate.msLabel = msLabel
		mtlView.delegate = mtlViewDelegate
		
		previewView.addSubview(mtlView)
		
		// Add constraints
		let h = NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|",
		                                       options: NSLayoutFormatOptions(),
		                                       metrics: nil,
		                                       views: ["view": mtlView])
		let v = NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|",
		                                       options: NSLayoutFormatOptions(),
		                                       metrics: nil,
		                                       views: ["view": mtlView])
		previewView.addConstraints(h + v)
		
	}
	
	override func viewDidLayout() {
		// Update the rendering size label
		let w = Int(mtlView.drawableSize.width), h = Int(mtlView.drawableSize.height)
		resLabel.stringValue = "\(w) x \(h)"
		if mtlView.isPaused { mtlView.draw() }
	}
	
	@IBAction func playPause(_ sender: NSButton) {
		mtlView.isPaused = sender.state == NSOffState
	}
	
	@IBAction func resetTime(_ sender: Any) {
		mtlViewDelegate.resetTime()
	}
}


class MetalViewDelegate: NSObject, MTKViewDelegate {
	
	private var shader: Shader?
	
	var queue: MTLCommandQueue?
	var computePS: MTLComputePipelineState?
	var fragmentPS: MTLRenderPipelineState?
	var vertPosBuffer: MTLBuffer?
	var vertCoordBuffer: MTLBuffer?
	var timeBuffer: MTLBuffer?
	var resBuffer: MTLBuffer?
	var initialResSet = false
	var startTime: Date
	
	var frameDurations: [Double] = Array.init(repeating: 0.0, count: 10) // Take the average of the last 10 frames
	var fpsUpdateCount = 0
	var fpsCounterStartTime: Date
	
	private var vs: String?
	private var fs: String?
	private var cs: String?
	weak var fpsLabel: NSTextField!
	weak var msLabel: NSTextField!
	
	override public init() {
		if let dev = mtlDev {
			
			queue = dev.makeCommandQueue()
			
			// Set up the buffers to contain time and resolution
			timeBuffer = dev.makeBuffer(length: MemoryLayout<Float>.size, options: [])
			resBuffer = dev.makeBuffer(length: MemoryLayout<float2>.size, options: [])
			
			// A quad to render on
			let quad = Quad()
			
			// Set up the vertex position + coord buffers
			vertPosBuffer = dev.makeBuffer(bytes: quad.vertices, length: MemoryLayout<float4>.size * quad.vertices.count, options: MTLResourceOptions())
			vertCoordBuffer = dev.makeBuffer(bytes: quad.texCoords, length: MemoryLayout<float4>.size * quad.texCoords.count, options: MTLResourceOptions())
		}
		
		// Initialise time to now
		startTime = Date()
		fpsCounterStartTime = Date()
		
		super.init()
		
	}
	
	func updateShader(_ newShader: Shader) {
		self.shader = newShader
		
		guard let dev = mtlDev, let library = shader!.library else {
			return
		}
		
		switch shader!.type {
		case .Compute:
			do {
				guard let mainKernel = library.makeFunction(name: shader!.activeComputeFunction) else { return }
				computePS = try dev.makeComputePipelineState(function: mainKernel)
				
			} catch let error {
				Swift.print(error.localizedDescription)
			}
			
		case .Fragment:
			guard let vert = library.makeFunction(name: shader!.activeVertexFunction),
				let frag = library.makeFunction(name: shader!.activeFragmentFunction) else {
				Swift.print("No vertex or fragment shader set")
				return
			}
			let pipelineDescriptor = MTLRenderPipelineDescriptor()
			pipelineDescriptor.vertexFunction = vert
			pipelineDescriptor.fragmentFunction = frag
			pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
			pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false
			
			do{
				fragmentPS = try dev.makeRenderPipelineState(descriptor: pipelineDescriptor)
			} catch let err {
				// TODO: Handle this better, and somehow get the warning on screen
				Swift.print("Something wrong with pipeline descriptor")
				Swift.print("Error: \(err.localizedDescription)")
				return
			}
		}
	}
	
	/// Updates the time buffer with the current time
	func updateTime() {
		guard let buffer = self.timeBuffer else { return }
		
		var t = Float(Date().timeIntervalSince(startTime) as Double)
		
		let bufferPointer = buffer.contents()
		memcpy(bufferPointer, &t, MemoryLayout<Float>.size)
	}
	
	public func resetTime() {
		startTime = Date()
	}
	
	public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		updateRes(size)
	}
	
	private func updateRes(_ size: CGSize) {
		guard let buffer = resBuffer else { return }
		
		var res = float2(Float(size.width), Float(size.height))
		
		let bufferPointer = buffer.contents()
		memcpy(bufferPointer, &res, MemoryLayout<float2>.size)
	}
	
	public func draw(in view: MTKView) {
		guard let drawable = view.currentDrawable, let shader = self.shader else { return }
		
		// Check initial resolution buffer is set (prevents empty resolution values)
		if !initialResSet { updateRes(view.drawableSize) }
		
		//		Update the time buffer
		if !view.isPaused { updateTime() }
		
		switch  shader.type {
		case .Compute:
			guard let pipe = computePS, let queue = self.queue else { return }
			
			let commandBuffer = queue.makeCommandBuffer()
			let commandEncoder = commandBuffer.makeComputeCommandEncoder()
			commandEncoder.setComputePipelineState(pipe)
			commandEncoder.setTexture(drawable.texture, at: 0)
			commandEncoder.setBuffer(timeBuffer, offset: 0, at: 0)
			
			// TODO: Handle non-factor-of-8 sizes
			let threadGroupCount = MTLSizeMake(8, 8, 1)
			let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width, drawable.texture.height / threadGroupCount.height, 1)
			commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
			commandEncoder.endEncoding()
			commandBuffer.present(drawable)
			commandBuffer.commit()
			
		case .Fragment:
			guard let pipe = fragmentPS, let queue = self.queue else { return }
			
			view.currentRenderPassDescriptor!.colorAttachments[0].clearColor = MTLClearColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
			view.currentRenderPassDescriptor!.colorAttachments[0].texture = drawable.texture
			view.currentRenderPassDescriptor!.colorAttachments[0].loadAction = MTLLoadAction.clear
			view.currentRenderPassDescriptor!.colorAttachments[0].storeAction = MTLStoreAction.store

			// get command queue, buffer, encoder
			let cmdBuffer = queue.makeCommandBuffer()
			let cmdEncoder = cmdBuffer.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)

			// encode the render
			cmdEncoder.setRenderPipelineState(pipe)
			cmdEncoder.setVertexBuffer(vertPosBuffer, offset: 0, at: 0)
			cmdEncoder.setVertexBuffer(vertCoordBuffer, offset: 0, at: 1)
			
			cmdEncoder.setFragmentBuffer(timeBuffer, offset: 0, at: 0)
			cmdEncoder.setFragmentBuffer(resBuffer, offset: 0, at: 1)
			
			// TODO: Texture support
// set the texture
//cmd.encoder.setFragmentTexture(texture!.tex, at: 0)
//cmd.encoder.setFragmentSamplerState(samplerState, at: 0)
			cmdEncoder.drawPrimitives(type: MTLPrimitiveType.triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
			
			cmdEncoder.endEncoding()
			cmdBuffer.present(view.currentDrawable!)
			cmdBuffer.commit()
		}


		// Update FPS display
		fpsUpdateCount += 1
		if fpsUpdateCount == 10 {
			// update the display
			let date = Date()
			let interval = date.timeIntervalSince(fpsCounterStartTime) / 10.0
			fpsCounterStartTime = date
			frameDurations.removeFirst()
			frameDurations.append(interval as Double)
			
			// Get the total
			let totalTime = frameDurations.reduce(0, +) / 10.0
			
			// Millisecond display
			let displayTime = Int(totalTime * 1000.0)
			msLabel.stringValue = String(displayTime) + "ms"
			
			// FPS display
			let fps = Float(Int(10.0 / totalTime)) / 10.0
			fpsLabel.stringValue = String(fps) + "fps"
			
			fpsUpdateCount = 0
		}
	}
	
}
