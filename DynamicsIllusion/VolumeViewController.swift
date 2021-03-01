//
//  ViewController.swift
//  DynamicsIllusion
//
//  Created by rlxone on 02.04.17.
//  Copyright © 2017 rlxone. All rights reserved.
//

import Cocoa
import AudioToolbox
import MediaKeyTap

class VolumeViewController: NSViewController, NSTableViewDataSource {
    @IBOutlet var volumeSlider: NSSlider!
    @IBOutlet var balanceSlider: NSSlider!

    @IBOutlet var balanceView: NSView!

    var selectedDevices: [AudioDeviceID]?
    var muted: Bool = false
    var balance: Float = 50.0
    
    func deviceChangeVolume(value: Float) {
        if selectedDevices != nil {
            let balanceMax = (balance < 50.0) ? 100.0 - balance : balance,
                balanceLeft = (100.0 - balance) / balanceMax,
                balanceRight = balance / balanceMax,
                deviceCount = selectedDevices!.count,
                count = (deviceCount == 1) ? 1 : deviceCount - 1,
                balanceDelta = balanceRight - balanceLeft

            for (index, device) in selectedDevices!.enumerated() {
                let bal = balanceLeft + balanceDelta * Float(index) / Float(count)
                Audio.setDeviceVolume(deviceID: device, leftChannelLevel: bal * value, rightChannelLevel: bal * value)
            }
        }
    }

    func toggleMute() {
        muted = !muted
        let volume: Float = (muted) ? 0.0 : volumeSlider.floatValue / 100
        deviceChangeVolume(value: volume)
    }

    func changeStatusItemImage(value: Float) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        if value < 1 {
            appDelegate.statusItem.button?.image = NSImage(named: "StatusBar1Image")
        } else if value > 1 && value < 100 / 3 {
            appDelegate.statusItem.button?.image = NSImage(named: "StatusBar2Image")
        } else if value > 100 / 3 && value < 100 / 3 * 2 {
            appDelegate.statusItem.button?.image = NSImage(named: "StatusBar3Image")
        } else if value > 100 / 3 * 2 && value <= 100 {
            appDelegate.statusItem.button?.image = NSImage(named: "StatusBar4Image")
        }
    }

    @discardableResult
    func updateVolume(volume: Float) -> Float {
        if (volume > 0.0) { muted = false }
        volumeSlider.floatValue = max(min(100, volume), 0)
        deviceChangeVolume(value: volumeSlider.floatValue / 100)
        changeStatusItemImage(value: volumeSlider.floatValue)
        return volumeSlider.floatValue
    }

    func getVolume() -> Float {
        return volumeSlider.floatValue
    }
    
    func updateBalance(bal: Float) {
        balanceSlider.floatValue = bal
        balance = bal
    }

    @IBAction func volumeSliderAction(_ sender: Any) {
        updateVolume(volume: volumeSlider.floatValue)
    }

    @IBAction func balanceSliderAction(_ sender: Any) {
        balance = balanceSlider.floatValue
        deviceChangeVolume(value: volumeSlider.floatValue / 100)
        UserDefaults.standard.set(balance, forKey: "balance")
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}
