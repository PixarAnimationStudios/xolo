//
//  AppDelegate.swift
//  d3ExpirationMonitor
//
//  Created by Chris Lasell on 7/18/15.
//  Copyright (c) 2016 Pixar Animation Studios. All rights reserved.
//

//# Copyright 2018 Pixar
//###
//#    Licensed under the Apache License, Version 2.0 (the "Apache License")
//#    with the following modification; you may not use this file except in
//#    compliance with the Apache License and the following modification to it:
//#    Section 6. Trademarks. is deleted and replaced with:
//###
//#    6. Trademarks. This License does not grant permission to use the trade
//#       names, trademarks, service marks, or product names of the Licensor
//#       and its affiliates, except as required to comply with Section 4(c) of
//#       the License and to reproduce the content of the NOTICE file.
//###
//#    You may obtain a copy of the Apache License at
//###
//#        http://www.apache.org/licenses/LICENSE-2.0
//###
//#    Unless required by applicable law or agreed to in writing, software
//#    distributed under the Apache License with the above modification is
//#    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//#    KIND, either express or implied. See the Apache License for the specific
//#    language governing permissions and limitations under the Apache License.
//###
//###


import Cocoa
import CoreFoundation
import Foundation
import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(aNotification: NSNotification) {


    // the current user
    let currentUser = NSUserName()

    // filesystem access...
    let fileManager = NSFileManager.defaultManager()

    // the d3 support folder
    let d3SupportFolder = "/Library/Application Support/d3"

    // The folder where we collect the data per-user
    // this folder needs to exist and be root:wheel, 0733
    let d3UsageFolder = "\(d3SupportFolder)/Usage"

    // the live plist
    let plistPath = "\(d3UsageFolder)/\(currentUser).plist"

    // the usage data
    var monitorPlistData = NSMutableDictionary()

    // if the live plist exists, load it
    if fileManager.fileExistsAtPath(plistPath) {
      monitorPlistData = NSMutableDictionary(contentsOfFile: plistPath)!
    } else {
      monitorPlistData.writeToFile(plistPath, atomically: false)
    } // if fileManager...

    // set the plist to mode 600, (decimal 384)
    try! fileManager.setAttributes(["NSFilePosixPermissions": 384], ofItemAtPath: plistPath)

    // the NSWorksace that will send notifications to us.
    let workspace = NSWorkspace.sharedWorkspace()

    // the notification center in that worksapce
    let notifCtr = workspace.notificationCenter

    // add our observer for when apps come to the foreground
    // the block just adds or updates the plist key for the app with the current
    // timestamp, then writes out the plist.
    notifCtr.addObserverForName( NSWorkspaceDidActivateApplicationNotification,
      object: nil,
      queue: nil,
      usingBlock: {(notification: NSNotification) -> Void  in

        var userInfo = notification.userInfo
        let runningApp: NSRunningApplication = userInfo![NSWorkspaceApplicationKey] as! NSRunningApplication
        let appExecPath = runningApp.executableURL!.path as String!
        let now = NSDate()

        monitorPlistData[appExecPath] = now
        monitorPlistData.writeToFile(plistPath, atomically: false)
      } // usingBlock
    ) // notifCtr.addObserverForName


  } // func applicationDidFinishLaunching
} // class AppDelegate
