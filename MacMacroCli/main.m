//
//  main.m
//  MacMacroCli
//
//  Created by Micah Kimel on 11/25/24.
//

#import <Foundation/Foundation.h>
#include <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <Accessibility/Accessibility.h>
#import "captureImage.h"
#import "MacMacroCli-Swift.h"
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

double compareImages(CGImageRef image1, CGImageRef image2, CGSize targetSize);
CGImageRef resizeImage(CGImageRef image, CGSize targetSize);
double similarity = 0.0;

@interface MyAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) CaptureImage *captureDelegate;

@end

BOOL shouldContinue = YES;
BOOL captureImage = NO;
BOOL captureImagePartTwo = NO;
CGRect imageRect = (CGRect){.size = 0};
NSString *outputPath = @"output.sh";
NSString *currentDir = @"output.sh";
NSArray *toRunPath = {};


void compareImageSubMethod(void){
    
    NSString *Imagepath1 = [NSString stringWithFormat:@"%@%@", outputPath, @"two.png"];
    NSString *Imagepath2 = [NSString stringWithFormat:@"%@%@", outputPath, @".png"];

    // Read Base64 strings from files
    NSString *base64Image1 = [NSString stringWithContentsOfFile:Imagepath1 encoding:NSUTF8StringEncoding error:nil];
    NSString *base64Image2 = [NSString stringWithContentsOfFile:Imagepath2 encoding:NSUTF8StringEncoding error:nil];

    if (!base64Image1 || !base64Image2) {
        NSLog(@"Failed to read Base64 images from files.");
        return;
    }

    // Decode Base64 strings
    NSData *imageData1 = [[NSData alloc] initWithBase64EncodedString:base64Image1 options:0];
    NSData *imageData2 = [[NSData alloc] initWithBase64EncodedString:base64Image2 options:0];

    if (!imageData1 || !imageData2) {
        NSLog(@"Failed to decode Base64 strings.");
        return;
    }

    // Create CGImage from NSData
    CGImageSourceRef source1 = CGImageSourceCreateWithData((__bridge CFDataRef)imageData1, NULL);
    CGImageSourceRef source2 = CGImageSourceCreateWithData((__bridge CFDataRef)imageData2, NULL);
    CGImageRef image1 = CGImageSourceCreateImageAtIndex(source1, 0, NULL);
    CGImageRef image2 = CGImageSourceCreateImageAtIndex(source2, 0, NULL);

    if (!image1 || !image2) {
        NSLog(@"Failed to create CGImage objects.");
        if (source1) CFRelease(source1);
        if (source2) CFRelease(source2);
        return;
    }

    // Compare images
    CGSize targetSize = CGSizeMake(100, 100); // Resize to standard resolution
    similarity = compareImages(image1, image2, targetSize);

    NSLog(@"The images are %.2f%% similar.", similarity);

    // Clean up
    CFRelease(image1);
    CFRelease(image2);
    CFRelease(source1);
    CFRelease(source2);

    return;
}

void compareImageOutputs(void){
    NSLog(@"Compare Outputs Called!");
    NSString *ImagepathTwo = [NSString stringWithFormat:@"%@%@", outputPath, @"two"];
    NSError *error;
    NSString *fileContent = [NSString stringWithContentsOfFile:outputPath encoding:NSUTF8StringEncoding error:&error];
    if (error){
        NSLog(@"failed to read file");
        shouldContinue = NO;
        return;
    }
    NSArray *components = [fileContent componentsSeparatedByString:@","];
    
    NSRange range = NSMakeRange([components count] - 4, 4);
    NSArray *lastFour = [components subarrayWithRange:range];
    
    
    imageRect.origin.x = [lastFour[0] floatValue];
    imageRect.origin.y = [lastFour[1] floatValue];
    imageRect.size.width = [lastFour[2] floatValue];
    imageRect.size.height = [lastFour[3] floatValue];
    UserDefaultFactory *udf = [[UserDefaultFactory alloc] init];
    NSLog(@"calling screenshot %@", ImagepathTwo);
    [udf screenshotWithRect:imageRect toFilePath:ImagepathTwo completionHandler:^{
        NSLog(@"Screenshot saved successfully!");
        compareImageSubMethod();
        
        CFRelease(CFBridgingRetain(udf));
        shouldContinue = NO;
    }];
    NSLog(@"over?");
    
    while (shouldContinue) {
       // NSLog(@"wait");
    }
}


// Function to compare two CGImages and calculate similarity percentage
double compareImages(CGImageRef image1, CGImageRef image2, CGSize targetSize) {

    CFDataRef data1 = CGDataProviderCopyData(CGImageGetDataProvider(image1));
    CFDataRef data2 = CGDataProviderCopyData(CGImageGetDataProvider(image2));

    const UInt8 *pixels1 = CFDataGetBytePtr(data1);
    const UInt8 *pixels2 = CFDataGetBytePtr(data2);

    NSUInteger length = CFDataGetLength(data1);
    NSUInteger similarPixelCount = 0;

    for (NSUInteger i = 0; i < length; i++) {
        if (pixels1[i] == pixels2[i]) {
            similarPixelCount++;
        }
    }

    CFRelease(data1);
    CFRelease(data2);

    double similarity = ((double)similarPixelCount / (double)length) * 100.0;
    return similarity;
}

// Function to resize a CGImage to a target size
CGImageRef resizeImage(CGImageRef image, CGSize targetSize) {
    size_t width = (size_t)targetSize.width;
    size_t height = (size_t)targetSize.height;

    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);

    if (!context) {
        return NULL;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGImageRef resizedImage = CGBitmapContextCreateImage(context);

    CGContextRelease(context);
    return resizedImage;
}

void runScript(void) {
    @autoreleasepool {
        // Path to your script file
        for (id item in toRunPath){
            if ([item isKindOfClass:[NSString class]]){
                NSString *scriptPath = (NSString *)item;
                // Get the file manager
                NSFileManager *fileManager = [NSFileManager defaultManager];
                
                // Set the executable flag for the script
                NSError *error = nil;
                BOOL success = [fileManager setAttributes:@{NSFilePosixPermissions: @(0755)} ofItemAtPath:scriptPath error:&error];
                
                if (success) {
                    NSLog(scriptPath);
                    // Create a task to run the script
                    NSTask *task = [[NSTask alloc] init];
                    [task setLaunchPath:@"/bin/zsh"];
                    [task setArguments:@[@"-c", scriptPath]];
                    NSDictionary *environment = @{
                        @"PATH": @"/opt/homebrew/bin:/opt/homebrew/sbin:/Users/micahkimel/go/bin:/opt/homebrew/opt/go/libexec/bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/usr/local/opt:/usr/local/bin"
                    };
                    [task setEnvironment:environment];
                    [task launch];
                    
                    // Wait for the task to finish (optional)
                    [task waitUntilExit];
                } else {
                    NSLog(@"Error setting file permissions: %@", error);
                }
            } else {
                NSLog(@"Item is not a string");
            }
        }
    }
        
    // Then compare outputs
    compareImageOutputs();
}

void listAllWindowPIDs(void) {
    // Create an array to store window list
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionAll,  // Get all windows, including minimized ones
        kCGNullWindowID);
    
    if (windowList) {
        CFIndex count = CFArrayGetCount(windowList);
        
        // Keep track of PIDs we've already seen
        pid_t* seenPIDs = (pid_t*)calloc(count, sizeof(pid_t));
        int seenCount = 0;
        
        printf("Active processes with windows:\n");
        printf("PID\tProcess Name\tWindow Title\n");
        printf("----------------------------------------\n");
        
        // Iterate through all windows
        for (CFIndex i = 0; i < count; i++) {
            CFDictionaryRef window = CFArrayGetValueAtIndex(windowList, i);
            
            // Get PID
            CFNumberRef pidRef = CFDictionaryGetValue(window, kCGWindowOwnerPID);
            if (!pidRef) continue;
            
            pid_t pid;
            CFNumberGetValue(pidRef, kCFNumberIntType, &pid);
            
            // Check if we've already seen this PID
            bool alreadySeen = false;
            for (int j = 0; j < seenCount; j++) {
                if (seenPIDs[j] == pid) {
                    alreadySeen = true;
                    break;
                }
            }
            
            if (!alreadySeen) {
                seenPIDs[seenCount++] = pid;
                
                // Get process name
                CFStringRef processName = CFDictionaryGetValue(window, kCGWindowOwnerName);
                
                // Get window title
                CFStringRef windowTitle = CFDictionaryGetValue(window, kCGWindowName);
                
                // Convert CFString to C string for printing
                char processNameStr[256] = "";
                char windowTitleStr[256] = "";
                
                if (processName) {
                    CFStringGetCString(processName, processNameStr,
                                     sizeof(processNameStr), kCFStringEncodingUTF8);
                }
                
                if (windowTitle) {
                    CFStringGetCString(windowTitle, windowTitleStr,
                                     sizeof(windowTitleStr), kCFStringEncodingUTF8);
                }
                
                printf("%d\t%s\n", pid, processNameStr);
            }
        }
        
        free(seenPIDs);
        CFRelease(windowList);
    }
}

void FileWrite(NSString *textToWrite){
    @autoreleasepool {
        NSURL *filePath = [NSURL fileURLWithPath:outputPath];

        // Create a file handle
        //NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
        NSError *error = nil;
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:filePath error:&error];

        if (fileHandle) {
            // Seek to the end of the file
            [fileHandle seekToEndOfFile];

            // Write the text to the file
            [fileHandle writeData:[textToWrite dataUsingEncoding:NSUTF8StringEncoding]];

            // Close the file handle
            [fileHandle closeFile];
            NSLog(@"Text written to file successfully.");
        } else {
            NSLog(@"Error creating file handle: %@", error);
        }
    }
}

AXUIElementRef getFocusedWindow(void) {
    // Get the frontmost process ID
    ProcessSerialNumber psn;
    pid_t pid;
    
    GetFrontProcess(&psn);
    GetProcessPID(&psn, &pid);
    
    // Create accessibility element for the focused application
    AXUIElementRef focusedApp = AXUIElementCreateApplication(pid);
    AXUIElementRef focusedWindow = NULL;
    CFTypeRef windowValue;
    
    if (focusedApp) {
        // Get the focused window of the application
        AXError result = AXUIElementCopyAttributeValue(
            focusedApp,
            CFSTR("AXFocusedWindow"),
            &windowValue
        );
        
        if (result == kAXErrorSuccess) {
            focusedWindow = (AXUIElementRef)windowValue;
            
            // Get window title for verification
            CFTypeRef titleValue;
            result = AXUIElementCopyAttributeValue(
                focusedWindow,
                CFSTR("AXTitle"),
                &titleValue
            );
            
            if (result == kAXErrorSuccess) {
                NSString *title = (__bridge NSString *)titleValue;
                NSLog(@"Focused Window Title: %@", title);
                CFRelease(titleValue);
            }
            
            CFTypeRef fullScreenValueTrue = kCFBooleanTrue;
            CFTypeRef fullScreenValueFalse = kCFBooleanFalse;
            
            CFTypeRef fullScreenValue;
            AXError error = AXUIElementCopyAttributeValue(focusedWindow, CFSTR("AXFullScreen"), &fullScreenValue);
            
            if (error == kAXErrorSuccess) {
                if (CFBooleanGetValue(fullScreenValue)) {
                    NSLog(@"Window is in full screen mode");
                    OSStatus result2 = AXUIElementSetAttributeValue(focusedWindow,
                       CFSTR("AXFullScreen"),
                        fullScreenValueFalse);
                    if (result2 == kAXErrorSuccess) {
                        NSLog(@"Window set to full screen");
                    } else {
                        NSLog(@"Failed to set full screen (Error: %d)", result);
                    }
                } else {
                    NSLog(@"Window is not in full screen mode");
                    OSStatus result2 = AXUIElementSetAttributeValue(focusedWindow,
                       CFSTR("AXFullScreen"),
                        fullScreenValueTrue);
                    if (result2 == kAXErrorSuccess) {
                        NSLog(@"Window set to full screen");
                    } else {
                        NSLog(@"Failed to set full screen (Error: %d)", result);
                    }
                }
                CFRelease(fullScreenValue);
            }

        } else {
            NSLog(@"Failed to get focused window (Error: %d)", result);
        }
        
        CFRelease(focusedApp);
    }
    
    return focusedWindow; // Caller is responsible for releasing this
}

const char* getKeyCodeString(CGKeyCode keyCode) {
    static char keyString[2] = {0}; // Static buffer to return
    
    // Use TIS functions to get the current keyboard layout
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    
    if (!layoutData) {
        CFRelease(currentKeyboard);
        return "";
    }
    
    const UCKeyboardLayout *keyboardLayout =
        (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
    
    UInt32 deadKeyState = 0;
    UniCharCount actualStringLength = 0;
    UniChar unicodeString[4]; // Buffer for unicode character
    
    // Try to get the character for the keycode
    OSStatus status = UCKeyTranslate(
        keyboardLayout,
        keyCode,
        kUCKeyActionDown,
        0, // No modifier
        LMGetKbdType(),
        kUCKeyTranslateNoDeadKeysBit,
        &deadKeyState,
        sizeof(unicodeString) / sizeof(UniChar),
        &actualStringLength,
        unicodeString
    );
    
    CFRelease(currentKeyboard);
    
    if (status == noErr && actualStringLength > 0) {
        // Convert to UTF-8
        keyString[0] = (char)unicodeString[0];
        keyString[1] = '\0';
        return keyString;
    }
    
    return "";
}

void saveImage(NSImage* image) {
    // Convert NSImage to PNG data
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
    NSData *pngData = [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    
    // Write to file
    [pngData writeToFile:outputPath atomically:YES];
}

CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    NSLog(@"Event Callback");
    if (type == kCGEventKeyDown) {
        // Get the keycodefseasefs
        CGKeyCode keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

        // Handle the keycode as needed
        printf("Key pressed: %d\n", keyCode);
        NSLog(@"Key Press: %d\n", keyCode);
        
        // Convert keycode to character
        const char* keyChar = getKeyCodeString(keyCode);
        if (keyCode == 96) {
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kd:ctrl kd:cmd t:f ku:ctrl ku:cmd \n sleep 1.0\n"];
            FileWrite(formattedString);
            CFTypeRef fullScreenValue = kCFBooleanTrue;
            getFocusedWindow();
            
        } else if (keyCode == 98) {
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kd:cmd kd:shift t:4 \n sleep 1.0\n"];
            FileWrite(formattedString);
            
        } else if (keyCode == 100) {
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kd:cmd kp:space \n sleep 1.0\n"];
            FileWrite(formattedString);
            
        } else if (keyCode == 97){
            // Capture two more inputs which are the pixel points in which to screenshot
            // Screenshot will then be compared when running for confidence interval
            //@autoreleasepool {
            captureImage = YES;
            //}
//            shouldContinue = NO;
            //NSLog(@"File Exported, thank you for using!");
            //abort();
        } else if (keyCode == 49) {
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kp:space \n sleep 1.0\n"];
            FileWrite(formattedString);
            
        }
        else {
            NSString *formattedString = [NSString stringWithFormat:@"cliclick t:%s \n sleep 0.2\n", keyChar];
            FileWrite(formattedString);
        }
        
        //listAllWindowPIDs();
        //CFStringRef title = CFStringCreateWithCString(NULL, "iPad Pro 11-inch (M4) – iOS 17.4", kCFStringEncodingUTF8);
        //printf("pid: %i", findProcessByWindowTitle(title));a
    } else if (type == kCGEventLeftMouseUp) {
        NSLog(@"Click");
        if (captureImage) {
            CGPoint point = CGEventGetLocation(event);
            printf("Mouse up at: (%f, %f)\n", point.x, point.y);
            int pointX = point.x;
            int pointY = point.y;
            if (captureImagePartTwo) {
                NSLog(@"Screenshot Set Width/Height!");
                NSString *ImagepathTwo = [NSString stringWithFormat:@"%@%@", outputPath, @"two"];
                NSError *error;
                NSString *fileContent = [NSString stringWithContentsOfFile:outputPath encoding:NSUTF8StringEncoding error:&error];
                if (error){
                    NSLog(@"failed to read file");
                    shouldContinue = NO;
                }
                NSArray *components = [fileContent componentsSeparatedByString:@","];
                
                NSRange range = NSMakeRange([components count] - 4, 4);
                NSArray *lastFour = [components subarrayWithRange:range];
                
                
                imageRect.origin.x = [lastFour[0] floatValue];
                imageRect.origin.y = [lastFour[1] floatValue];
                imageRect.size.width = [lastFour[2] floatValue];
                imageRect.size.height = [lastFour[3] floatValue];
                UserDefaultFactory *udf = [[UserDefaultFactory alloc] init];
                [udf screenshotWithRect:imageRect toFilePath:outputPath completionHandler:^{
                    NSLog(@"Screenshot saved successfully!");
                    abort();
                }];
            }
            captureImagePartTwo = YES;
            
            // Accessing the points
            imageRect.origin.x = pointX;
            imageRect.origin.y = pointY;
            NSLog(@"Screenshot Set Origin Points!");
            
        } else {
            CGPoint point = CGEventGetLocation(event);
            printf("Mouse up at: (%f, %f)\n", point.x, point.y);
            int pointX = point.x;
            int pointY = point.y;
            NSString *formattedString = [NSString stringWithFormat:@" du:%i,%i \n sleep 1.5\n", pointX, pointY];
            FileWrite(formattedString);
        }
//        AXUIElementRef focusedWindow = getFocusedWindow();
//        if (focusedWindow) {
//            // Use the focused window
//            // ... your code here ...
//
//            // Remember to release when done
//            CFRelease(focusedWindow);
//        } else {
//            NSLog(@"No focused window found");
//        }
    } else if (type == kCGEventLeftMouseDown) {
        if (!captureImage) {
            CGPoint point = CGEventGetLocation(event);
            printf("Mouse down at: (%f, %f)\n", point.x, point.y);
            int pointX = point.x;
            int pointY = point.y;
            NSString *formattedString = [NSString stringWithFormat:@"cliclick dd:%i,%i ", pointX, pointY];
            FileWrite(formattedString);
        } else {
            CGPoint point = CGEventGetLocation(event);
            printf("Mouse down at: (%f, %f)\n", point.x, point.y);
            int pointX = point.x;
            int pointY = point.y;
            NSString *formattedString = [NSString stringWithFormat:@"\n ,%i,%i", pointX, pointY];
            FileWrite(formattedString);
        }
    } else if (type == kCGEventRightMouseDown) {
        CGPoint point = CGEventGetLocation(event);
        printf("Right Mouse down at: (%f, %f)\n", point.x, point.y);
        int pointX = point.x;
        int pointY = point.y;
        NSString *formattedString = [NSString stringWithFormat:@"cliclick rc:%i,%i \n sleep 1.5 \n", pointX, pointY];
        FileWrite(formattedString);
    } else if (type == kCGEventFlagsChanged) {
        // flag can be used to know if key down or key up
        CGEventFlags flag = CGEventGetFlags(event);
        
        if (flag & kCGEventFlagMaskCommand){
            //cmd key pressed
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kd:cmd \n sleep 0.2\n"];
            FileWrite(formattedString);
        } else if (kCGEventFlagMaskCommand){
            //cmd key up
            NSString *formattedString = [NSString stringWithFormat:@"cliclick ku:cmd \n sleep 0.2\n"];
            FileWrite(formattedString);
        }
        
        if (flag & kCGEventFlagMaskAlternate){
            //option key pressed
        } else if (kCGEventFlagMaskAlternate){
            //option key up
        }
        
        if (flag & kCGEventFlagMaskControl){
            //control key pressed
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kd:ctrl \n sleep 0.2\n"];
            FileWrite(formattedString);
        } else if (kCGEventFlagMaskControl){
            //control key up
            NSString *formattedString = [NSString stringWithFormat:@"cliclick ku:ctrl \n sleep 0.2\n"];
            FileWrite(formattedString);
        }
        
        if (flag & kCGEventFlagMaskShift){
            //shift key pressed
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kd:shift \n sleep 0.2\n"];
            FileWrite(formattedString);
        } else if (kCGEventFlagMaskShift){
            //shift key up
            NSString *formattedString = [NSString stringWithFormat:@"cliclick ku:shift \n sleep 0.2\n"];
            FileWrite(formattedString);
        }
    }

    return event;
}

void createFile(void){
    @autoreleasepool {
        // leave empty
        NSString *textToWrite = @"";

        // Create a file manager
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSString *Imagepath = [NSString stringWithFormat:@"%@%@", outputPath, @".png"];
        NSString *Imagepath2 = [NSString stringWithFormat:@"%@%@", outputPath, @"two.png"];

        NSError *error = nil;
        BOOL success = [fileManager createFileAtPath:outputPath contents:nil attributes:nil];

        if (success) {
            NSLog(@"File created successfully.");
        } else {
            NSLog(@"Error creating file: %@", error);
        }
        
        error = nil;
        success = [fileManager createFileAtPath:Imagepath contents:nil attributes:nil];

        if (success) {
            NSLog(@"File created successfully.");
        } else {
            NSLog(@"Error creating file: %@", error);
        }
        
        error = nil;
        success = [fileManager createFileAtPath:Imagepath2 contents:nil attributes:nil];

        if (success) {
            NSLog(@"File created successfully.");
        } else {
            NSLog(@"Error creating file: %@", error);
        }
    }
}

void start(void) {
    createFile();
    while (shouldContinue) {
        NSLog(@"Start");
        CFMachPortRef eventTap = CGEventTapCreate(
          kCGHIDEventTap,
          kCGHeadInsertEventTap,
          kCGEventTapOptionDefault,
          CGEventMaskBit(kCGEventLeftMouseDown) |
          CGEventMaskBit(kCGEventLeftMouseUp) |
          CGEventMaskBit(kCGEventKeyDown) |
          CGEventMaskBit(kCGEventRightMouseDown) |
          CGEventMaskBit(kCGEventFlagsChanged),
          myCGEventCallback, NULL);
        
        if (eventTap) {
            CFRunLoopSourceRef runLoopSourceDown = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSourceDown, kCFRunLoopDefaultMode);
            CFRelease(runLoopSourceDown);
            
            CGEventTapEnable(eventTap, true);
            CFRunLoopRun();
            
            CGEventTapEnable(eventTap, false);
            CFRelease(eventTap);
        }
    }
}


void help(){
    NSString *help = @"macmacrocli tool used for recording\n"
    "mouse and text input and playing it back\n"
    "cliclick is a required dependancy for this application\n"
    "\n"
    "USAGE:\n"
    "macmacro -o output.sh\n"
    "This command start recording and sets an output file\n\n"
    "\nf5\n is used while running to make focused window fullscreen in order for clicks to always work \n\n"
    "\nf6\n can used to stop recording\n\n"
    "\nf7\n can used to capture image\n\n"
    "\nf8\n can used to switch application\n\n"
    "\nmacmacro -r /path/script1.sh /path/script2.sh\n"
    "This command runs any scripts togeather to preform complex actions\n\n";
    
    printf("%s", [help UTF8String]);
}

int main(int argc, const char * argv[]){
    int optchar;
    while ((optchar = getopt(argc, (char * const *)argv, "ho:r:")) != 1){
        switch (optchar){
            case 'h':
                help();
                break;
            case 'o':
                outputPath = [NSString stringWithFormat:@"%@%@%@", [[NSFileManager defaultManager] currentDirectoryPath], @"/", [NSString stringWithUTF8String:optarg]];
                start();
                break;
            case 'r':
                outputPath = [NSString stringWithFormat:@"%@%@%@", [[NSFileManager defaultManager] currentDirectoryPath], @"/", [NSString stringWithUTF8String:optarg]];
                toRunPath = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%@%@%@", [[NSFileManager defaultManager] currentDirectoryPath], @"/", [NSString stringWithUTF8String:optarg]], nil];
                runScript();
                break;
            default:
                abort();
        }
    }
}


