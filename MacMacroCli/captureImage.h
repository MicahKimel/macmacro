//
//  captureImage.h
//  MacMacroCli
//
//  Created by Micah Kimel on 11/26/24.
//

#ifndef CaptureImage_h
#define CaptureImage_h

#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <AppKit/AppKit.h> // for NSImage and CGImage

@class CaptureImage;

@protocol CaptureImage <NSObject>

- (void)captureDidFinishWithError:(nullable NSError *)error;
- (void)captureDidCaptureImage:(NSImage *)image;

@end

@interface CaptureImage : NSObject <SCStreamDelegate>

- (void)captureScreenshotFromRect:(CGRect)rect toFilePath:(NSString*_Nonnull)output;

@property (nonatomic, weak) id<CaptureImage> delegate; // Optional, if your delegate needs to be informed

- (void)stopCapture;

@end

#endif
