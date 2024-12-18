#import <GoogleGenerativeAI/GoogleGenerativeAI.h>
#import <UIKit/UIKit.h>

@interface MyImageAnalyzer : NSObject

- (void)analyzeImageWithBase64:(NSString *)base64String apiKey:(NSString *)apiKey;

@end

@implementation MyImageAnalyzer

- (void)analyzeImageWithBase64:(NSString *)base64String apiKey:(NSString *)apiKey {
    // 1. Initialize the Gemini API Model
    GEMGenerativeModel *model = [[GEMGenerativeModel alloc] initWithName:@"gemini-pro-vision" apiKey:apiKey];

    // 2. Convert the Base64 String to a UIImage
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
    UIImage *image = [UIImage imageWithData:imageData];

    // 3. Create a GEMPart with the image
    GEMPart *imagePart = [[GEMPart alloc] initWithImage:image];
    
    // 4. Create a prompt instructing Gemini to find input boxes
    NSString *promptText = @"Identify the pixel coordinates (top-left x, top-left y, width, height) of all the input boxes in this image. Format the results as a JSON array of objects, where each object represents a box with 'x', 'y', 'width', and 'height' keys.";
    GEMPart *promptPart = [[GEMPart alloc] initWithText: promptText];

    // 5. Build the content array for the request
    NSArray *content = @[promptPart, imagePart];
    
    // 6. Create a generation config
    GEMGenerateContentConfiguration *config = [GEMGenerateContentConfiguration new];
    config.temperature = @(0.2); // You can modify the temperature if needed

    // 7. Generate content with streaming response
    __block NSString *fullResponse = @"";
    [[model generateContentStreamWithParts:content configuration:config]
         subscribeNext:^(GEMGenerateContentResponse *response) {
            if (response.candidates.count > 0) {
                GEMCandidate *candidate = response.candidates[0];
                if (candidate.content.parts.count > 0) {
                    GEMPart *part = candidate.content.parts[0];
                    fullResponse = [fullResponse stringByAppendingString: part.text];
                    NSLog(@"Received partial response: %@", part.text);
                }
            }
        }
         error:^(NSError *error) {
            NSLog(@"Error generating content: %@", error);
        }
         completed:^{
            NSLog(@"Full response received: %@", fullResponse);
            [self processResponse: fullResponse];
        }];
}

- (void) processResponse: (NSString *) fullResponse {
    // 8. Parse the JSON Response
    NSError *jsonError;
    NSData *jsonData = [fullResponse dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&jsonError];

    if (jsonError) {
        NSLog(@"Error parsing JSON: %@", jsonError);
        return;
    }

    // 9. Extract and Process the Input Box Coordinates
    NSMutableArray *boundingBoxes = [NSMutableArray array];
    for (NSDictionary *boxDict in jsonArray) {
        NSNumber *x = boxDict[@"x"];
        NSNumber *y = boxDict[@"y"];
        NSNumber *width = boxDict[@"width"];
        NSNumber *height = boxDict[@"height"];

        if (x && y && width && height) {
            CGRect boxRect = CGRectMake([x floatValue], [y floatValue], [width floatValue], [height floatValue]);
            [boundingBoxes addObject:[NSValue valueWithCGRect:boxRect]];
            NSLog(@"Found input box at: %@", NSStringFromCGRect(boxRect));
        } else {
            NSLog(@"Invalid box data: %@", boxDict);
        }
    }

    // 10. Use the Bounding Boxes (e.g., Draw on the Image)
    // ... (Code to use the boundingBoxes array, see example below) ...
}

@end
