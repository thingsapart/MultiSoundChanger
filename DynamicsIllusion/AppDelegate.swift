//
//  AppDelegate.swift
//  DynamicsIllusion
//
//  Created by rlxone on 02.04.17.
//  Copyright © 2017 rlxone. All rights reserved.
//

import Cocoa
import AudioToolbox
import ScriptingBridge
import MediaKeyTap

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let devices = Audio.getOutputDevices()
    let selectedDevices = [AudioDeviceID]()
    var volumeViewController: VolumeViewController?
    var mediaKeyTap: MediaKeyTap?
    
    let volumeStep: Float = 100.0 / 16.0

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: ["balance" : 50.0])
        setupApp()
    }
    
    func setupApp() {
        volumeViewController = loadViewFromStoryboard(named: "Main", identifier: "VolumeViewControllerId") as? VolumeViewController
        createMenu()
        
        //Media keys listener
        self.startMediaKeyOnAccessibiltiyApiChange()
        self.startMediaKeyTap()
        
        // Load last balance setting.
        volumeViewController?.updateBalance(bal: UserDefaults.standard.float(forKey: "balance"))
    }
    
    func loadViewFromStoryboard(named: String, identifier: String) -> Any {
        let storyboard = NSStoryboard(name: named, bundle: nil)
        return storyboard.instantiateController(withIdentifier: identifier)
    }
    
    func createMenu() {
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBar1Image")
            button.action = #selector(self.statusBarAction)
        }
        
        let menu = NSMenu()

        // Volume Slider.
        var item = NSMenuItem(title: "Volume:", action: #selector(self.menuItemAction), keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        
        item = NSMenuItem(title: "", action: #selector(self.menuItemAction), keyEquivalent: "")
        item.view = volumeViewController?.view
        menu.addItem(item)
        
        // Balance Slider.
        item = NSMenuItem(title: "Balance:", action: #selector(self.menuItemAction), keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        
        item = NSMenuItem(title: "", action: #selector(self.menuItemAction), keyEquivalent: "")
        item.view = volumeViewController?.balanceView
        menu.addItem(item)
        
        // Devices Section.
        item = NSMenuItem(title: "Output Devices:", action: #selector(self.menuItemAction), keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        
        let defaultDevice = Audio.getDefaultOutputDevice()
        
        for device in devices! {
            let item = NSMenuItem(title: device.value.truncate(length: 25, trailing: "..."), action: #selector(self.menuItemAction), keyEquivalent: "")
            item.tag = Int(device.key)
            if device.key == defaultDevice {
                item.state = NSControl.StateValue.on
                if Audio.isAggregateDevice(deviceID: defaultDevice) {
                    volumeViewController?.selectedDevices = Audio.getAggregateDeviceSubDeviceList(deviceID: defaultDevice)
                    var volume: Float = 0
                    for device in (volumeViewController?.selectedDevices!)! {
                        if Audio.isOutputDevice(deviceID: device) {
                            volume = max(volume, Audio.getDeviceVolume(deviceID: device).first! * 100)
                        }
                    }
                    volumeViewController?.volumeSlider.floatValue = volume
                    volumeViewController?.changeStatusItemImage(value: volume)
                } else {
                    volumeViewController?.selectedDevices = [defaultDevice]
                    let volume = Audio.getDeviceVolume(deviceID: defaultDevice).first! * 100
                    volumeViewController?.volumeSlider.floatValue = volume
                    volumeViewController?.changeStatusItemImage(value: volume)
                }
            }
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        item = NSMenuItem(title: "Quit", action: #selector(self.menuQuitAction), keyEquivalent: "q")
        menu.addItem(item)
        
        statusItem.menu = menu
    }
    
    @objc func menuQuitAction() {
        NSApplication.shared.terminate(self)
    }

    @objc func menuItemAction(sender: NSMenuItem) {
        for item in (statusItem.menu?.items)! {
            if item == sender {
                if item.state == NSControl.StateValue.off {
                    item.state = NSControl.StateValue.on
                }
                let deviceID = AudioDeviceID(item.tag)
                if Audio.isAggregateDevice(deviceID: deviceID) {
                    volumeViewController?.selectedDevices = Audio.getAggregateDeviceSubDeviceList(deviceID: deviceID)
                } else {
                    volumeViewController?.selectedDevices = [deviceID]
                }
                Audio.setOutputDevice(newDeviceID: deviceID)
            } else {
                item.state = NSControl.StateValue.off
            }
        }
    }

    @objc func statusBarAction(sender: AnyObject) {
        print("you can update")
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return menuItem.isEnabled
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        
    }

    //If accessibility api changes, try to start media key listener
    private func startMediaKeyOnAccessibiltiyApiChange() {
        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(rawValue: "com.apple.accessibility.api"), object: nil, queue: nil) { _ in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(100)) {
                self.startMediaKeyTap()
            }
        }
    }
}

//Extend AppDelegate with Media Key Tap functions
extension AppDelegate: MediaKeyTapDelegate {
    func acquirePrivileges() {
        let trusted = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let privOptions = [trusted: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(privOptions)

        if accessEnabled == true {
            print("OK, access enabled.")
        } else {
            print("Failed, access denied.")
        }
    }
    
    //Try to start the media key tap listeners for brightness down and up
    private func startMediaKeyTap() {
        acquirePrivileges()

        var keys: [MediaKey]
        keys = [.volumeUp, .volumeDown, .mute]
        
        self.mediaKeyTap?.stop()
        self.mediaKeyTap = MediaKeyTap(delegate: self, for: keys, observeBuiltIn: true)
        self.mediaKeyTap?.start()
        
        let environment = ProcessInfo.processInfo.environment
        print(environment["APP_SANDBOX_CONTAINER_ID"] == nil ? "Not sanboxed" : "Sandboxed")
    }

    //Handle the media key taps
    func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
        if let volumeCtrl = volumeViewController {
            // Round to nearest multiple of volumeStep.
            var volume: Float = (volumeCtrl.getVolume() / volumeStep).rounded() * volumeStep
            switch mediaKey {
                case .volumeUp:
                    volume = volumeCtrl.updateVolume(volume: volume + volumeStep)
                case .volumeDown:
                    volume = volumeCtrl.updateVolume(volume: volume - volumeStep)
                case .mute:
                    volumeCtrl.toggleMute()
                    volume = (volumeCtrl.muted) ? 0.0 : volume
                default: break
            }
            showOSD(volume: volume)
        }
    }
    
    func showOSD(volume: Float) {
        guard let manager = OSDManager.sharedManager() as? OSDManager else {
          return
        }
        let mouseloc: NSPoint = NSEvent.mouseLocation
        var displayForPoint: CGDirectDisplayID = 0, count: UInt32 = 0
        if (CGGetDisplaysWithPoint(mouseloc, 1, &displayForPoint, &count) != CGError.success) {
            print("Error getting display under cursor.")
            displayForPoint = CGMainDisplayID()
        }
        let image = (volume == 0.0) ? OSDGraphicSpeakerMuted.rawValue : OSDGraphicSpeaker.rawValue
        manager.showImage(Int64(image), onDisplayID: displayForPoint, priority: 0x1F4, msecUntilFade: 1000, filledChiclets: UInt32(volume / volumeStep), totalChiclets: UInt32(100.0 / volumeStep), locked: false)
    }
}
