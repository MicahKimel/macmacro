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
            //let myData = nsImage.tiffRepresentation?.base64EncodedString()
            
            //crop image
            guard let cropedImage = nsImage.crop(cropRect: rect) else {
                return
            }
            
            // Ensure we have a valid representation
            guard let tiffRepresentation = cropedImage.tiffRepresentation,
                let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
                return
            }
            
            // Prepare compression properties
            let compressionProps = [NSBitmapImageRep.PropertyKey.compressionFactor: 0.8]
            
            // Convert to JPEG
            let myimage = bitmapImage.representation(using: .jpeg, properties: compressionProps)
            
            let myData = myimage?.base64EncodedString()
            
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

extension NSImage {
    /// Crop the image to a specific rectangular region
    /// - Parameters:
    ///   - x1: Starting x-coordinate
    ///   - y1: Starting y-coordinate
    ///   - x2: Ending x-coordinate
    ///   - y2: Ending y-coordinate
    /// - Returns: Cropped NSImage or nil if cropping fails
    func crop(cropRect: CGRect) -> NSImage? {
        // Double CGRect to match full screen
        let newWidth = cropRect.width
        let newHeight = cropRect.height
        let newOriginX = cropRect.origin.x
        let newOriginY = cropRect.origin.y
        let rect = CGRect(x: newOriginX, y: newOriginY, width: newWidth, height: newHeight)
        // Ensure we have a valid bitmap representation
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        
        // Get the actual image size
        let imageWidth = CGFloat(bitmapImage.pixelsWide)
        let imageHeight = CGFloat(bitmapImage.pixelsHigh)
        
        // Clip the crop rect to image bounds
        let clippedCropRect = rect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        
        // Create a new bitmap representation for the cropped image
        guard let cgImage = bitmapImage.cgImage?.cropping(to: clippedCropRect) else {
            return nil
        }
        
        // Create and return the cropped NSImage
        let croppedImage = NSImage(cgImage: cgImage, size: clippedCropRect.size)
        return croppedImage
    }
}
