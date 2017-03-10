//
//  MetalGlobals.swift
//  Metaltoy
//
//  Created by Chris Wood on 27/02/2017.
//  Copyright © 2017 Interealtime. All rights reserved.
//

import Foundation
import MetalKit

// The GPU device is used everywhere so just make it a global...
let mtlDev = MTLCreateSystemDefaultDevice()
