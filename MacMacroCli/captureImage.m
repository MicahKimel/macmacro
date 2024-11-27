//
//  captureImage.m
//  MacMacroCli
//
//  Created by Micah Kimel on 11/26/24.
//

#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>

@interface CaptureImage : NSObject <SCStreamDelegate>

@property (nonatomic, strong) SCStream *stream;

@end

@implementation CaptureImage

NSString *savePath = @"output.sh";

- (void) captureScreenshotFromRect:(CGRect) rect toFilePath:(NSString*)output {
    //set output
    savePath = output;
    // Request screen recording permission
    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent * _Nullable content, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        // Use the first available display
        if (content.displays.count == 0) {
            NSError *noDisplayError = [NSError errorWithDomain:@"ScreenshotCaptureDomain"
                                                          code:-1
                                                      userInfo:@{NSLocalizedDescriptionKey: @"No displays available"}];
            return;
        }
        
        SCDisplay *display = content.displays.firstObject;
        
        // Assuming SCStream is initialized with a configuration object only
        SCStreamConfiguration *configuration = [[SCStreamConfiguration alloc] init];
        configuration.width = rect.size.width;
        configuration.height = rect.size.height;
        configuration.sourceRect = rect;

        //init windows
        CFArrayRef windowList = CGWindowListCopyWindowInfo((kCGWindowListOptionOnScreenOnly | kCGWindowListOptionIncludingWindow), 0);
        NSArray *includedWindows = (__bridge NSArray *)windowList;
                                     
        //create filter
        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay: display includingWindows: includedWindows];
        
        // create stream
        SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:configuration delegate:nil];
        // Add a stream output
        NSError *addStreamError = nil;
        CFRelease(windowList);
    }];
}

- (void)stopCapture {
    self.stream = nil;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);


    // Create a CGImageRef from the pixel buffer
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGBitmapContextCreate(baseAddress, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer), 8, CVPixelBufferGetBytesPerRow(imageBuffer), colorSpace,
    kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

    // Create a NSImage from the CGImageRef
    NSImage *image = [[NSImage alloc] initWithCGImage:imageRef size:NSZeroSize];
    CGImageRelease(imageRef);

    // Save the image to a file
    NSData *imageData = [image TIFFRepresentation];
    NSString *path = [NSString stringWithFormat:@"%@%@", savePath, @".tiff"];
    [imageData writeToFile:path atomically:YES];
}

@end
