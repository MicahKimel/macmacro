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

@interface MyAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) CaptureImage *captureDelegate;

@end

BOOL shouldContinue = YES;
NSString *outputPath = @"output.sh";
NSString *currentDir = @"output.sh";
NSArray *toRunPath = {};

void runScript(void) {
    @autoreleasepool {
        // Path to your script file
        //NSString *scriptPath = @"/Users/micahkimel/Library/Containers/micahkimel.MacMacros/Data/test9.sh";
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
            
        } else if (keyCode == 97){
            // Capture two more inputs which are the pixel points in which to screenshot
            // Screenshot will then be compared when running for confidence interval
            @autoreleasepool {
                UserDefaultFactory *udf = [[UserDefaultFactory alloc] init];
                CGRect rect = CGRectMake(100, 100, 500, 500);
                
                [udf screenshotWithRect:rect toFilePath:outputPath completionHandler:^{
                    NSLog(@"Screenshot saved successfully!");
                }];
                // ... other code
            }
//            shouldContinue = NO;
            NSLog(@"File Exported, thank you for using!");
            //abort();
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
        CGPoint point = CGEventGetLocation(event);
        printf("Mouse up at: (%f, %f)\n", point.x, point.y);
        int pointX = point.x;
        int pointY = point.y;
        NSString *formattedString = [NSString stringWithFormat:@" du:%i,%i \n sleep 1.5\n", pointX, pointY];
        FileWrite(formattedString);
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
        CGPoint point = CGEventGetLocation(event);
        printf("Mouse down at: (%f, %f)\n", point.x, point.y);
        int pointX = point.x;
        int pointY = point.y;
        NSString *formattedString = [NSString stringWithFormat:@"cliclick dd:%i,%i", pointX, pointY];
        FileWrite(formattedString);
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
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kd:cmd \n sleep 1.5\n"];
            FileWrite(formattedString);
        } else if (kCGEventFlagMaskCommand){
            //cmd key up
            NSString *formattedString = [NSString stringWithFormat:@"cliclick ku:cmd \n sleep 1.5\n"];
            FileWrite(formattedString);
        }
        
        if (flag & kCGEventFlagMaskAlternate){
            //option key pressed
        } else if (kCGEventFlagMaskAlternate){
            //option key up
        }
        
        if (flag & kCGEventFlagMaskControl){
            //control key pressed
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kd:ctrl \n sleep 1.5\n"];
            FileWrite(formattedString);
        } else if (kCGEventFlagMaskControl){
            //control key up
            NSString *formattedString = [NSString stringWithFormat:@"cliclick ku:ctrl \n sleep 1.5\n"];
            FileWrite(formattedString);
        }
        
        if (flag & kCGEventFlagMaskShift){
            //shift key pressed
            NSString *formattedString = [NSString stringWithFormat:@"cliclick kd:shift \n sleep 1.5\n"];
            FileWrite(formattedString);
        } else if (kCGEventFlagMaskShift){
            //shift key up
            NSString *formattedString = [NSString stringWithFormat:@"cliclick ku:shift \n sleep 1.5\n"];
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
    "This command start recording and sets an output file\n"
    "\nf5 is used while running to make focused window fullscreen in order for clicks to always work \n"
    "\nf6 can used to stop recording\n"
    "\nmacmacro -r /path/script1.sh /path/script2.sh\n"
    "This command runs any scripts togeather to preform complex actions";
    
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
                //NSString *mypath = [NSString stringWithUTF8String:optarg];
                toRunPath = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%@%@%@", [[NSFileManager defaultManager] currentDirectoryPath], @"/", [NSString stringWithUTF8String:optarg]], nil];
                runScript();
                break;
            default:
                abort();
        }
    }
}


