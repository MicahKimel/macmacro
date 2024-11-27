//
//  CaptureScreenshot.swift
//  MacMacroCli
//
//  Created by Micah Kimel on 11/27/24.
//

import Foundation
import ScreenCaptureKit
import AppKit

@objc class UserDefaultFactory: NSObject {
    @objc func screenshot(rect: CGRect, toFilePath: NSString) async {
        do{
            print("SCREENSHOT")
            // Get content that is currently available for capture.
            let availableContent = try await SCShareableContent.current
            
            // Create instance of SCContentFilter to record entire display.
            guard let display = availableContent.displays.first else {
                print("display Error")
                return
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            // Create a configuration using preset for HDR stream canonical display.
            let config = SCStreamConfiguration(preset: .captureHDRStreamCanonicalDisplay)
            
            // Call the screenshot API to get CMSampleBuffer representation
            let screenshotBuffer = try await SCScreenshotManager.captureSampleBuffer(contentFilter: filter, configuration:config)
            
            // Call the screenshot API to get CGImage representation.
            let screenshotImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration:config)
            let size = NSSize(width: screenshotImage.width, height: screenshotImage.height)
            let nsImage = NSImage(cgImage: screenshotImage, size: size)
            let myData = nsImage.tiffRepresentation?.base64EncodedString()
            
            print((toFilePath as String) + ".png")
            let myImageString: String = myData!
            let myFilePath: String = (toFilePath as String) + ".png"
            //print(myData)
            do {
                try myImageString.write(toFile: myFilePath, atomically: true, encoding: .utf8)
                print("Text written to file successfully!")
            } catch {
                print("Error writing to file: \(error)")
            }
            
            print("SAVE")
            return
            
        } catch {
            
            print("ERRORS")
            return 
        }
    }
}
