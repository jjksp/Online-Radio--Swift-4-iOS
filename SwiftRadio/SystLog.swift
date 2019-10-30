//
//  SysLog.swift
//  SwiftRadio
//
//  Created by dev on 2019/10/30.
//  Copyright © 2019 com. All rights reserved.
//

import os.log
import Foundation
                
// USAGE : SysLog.shi.out(arg:"SR_LOG", value:"launched")

class SysLog: NSObject {
                
    static let shi: SysLog = SysLog()
    let log = OSLog(subsystem: "net.aqv.SampleMobileApp", category: "UI")
                
    private override init() {}
                
    func out(arg: String, value: String) {
        let strWhere = "\(#function) at \(#file) : \(#line)"
        os_log("%@ = %@ at %@", log: self.log, type: .default, arg, value, strWhere)
    }
}
                
                
                
