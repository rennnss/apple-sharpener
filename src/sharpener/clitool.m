#import <Foundation/Foundation.h>

void printUsage() {
    printf("Usage: sharpener [command] [options]\n\n");
    printf("Commands:\n");
    printf("  on             Enable window sharpening\n");
    printf("  off            Disable window sharpening\n");
    printf("  toggle         Toggle window sharpening\n");
    printf("\nOptions:\n");
    printf("  --radius=<value>, -r <value>  Set the sharpening radius\n");
    printf("  --show-radius, -s             Show current radius setting\n");
    printf("  --help, -h                    Show this help message\n");
    printf("\nExamples:\n");
    printf("  sharpener --radius=40         Set radius to 40\n");
    printf("  sharpener -r 40               Set radius to 40\n");
    printf("  sharpener on                  Enable sharpening\n");
    printf("  sharpener off                 Disable sharpening\n");
    printf("  sharpener -s                  Show current radius\n");
}

@interface RadiusResponseHandler : NSObject
+ (void)handleRadiusResponse:(NSNotification *)notification;
@end

@implementation RadiusResponseHandler
+ (void)handleRadiusResponse:(NSNotification *)notification {
    float radius = [notification.userInfo[@"radius"] floatValue];
    printf("Current radius: %.1f\n", radius);
    exit(0);
}
@end

@interface StatusHandler : NSObject
+ (void)handleStatus:(NSNotification *)notification;
@end

@implementation StatusHandler
+ (void)handleStatus:(NSNotification *)notification {
    BOOL enabled = [notification.userInfo[@"enabled"] boolValue];
    printf("Sharpener is now %s\n", enabled ? "enabled" : "disabled");
    exit(0);
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            printUsage();
            return 1;
        }

        NSString *firstArg = [NSString stringWithUTF8String:argv[1]];
        
        // Handle help
        if ([firstArg isEqualToString:@"--help"] || [firstArg isEqualToString:@"-h"]) {
            printUsage();
            return 0;
        }
        
        // Handle show radius
        if ([firstArg isEqualToString:@"--show-radius"] || [firstArg isEqualToString:@"-s"]) {
            [[NSDistributedNotificationCenter defaultCenter] 
                addObserver:[RadiusResponseHandler class]
                selector:@selector(handleRadiusResponse:)
                name:@"com.aspauldingcode.apple_sharpener.radius_response"
                object:nil];
                
            [[NSDistributedNotificationCenter defaultCenter] 
                postNotificationName:@"com.aspauldingcode.apple_sharpener.get_radius"
                object:nil
                userInfo:nil];
                
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
            printf("No response received\n");
            return 1;
        }

        // Handle radius setting
        float radius = 0.0;
        BOOL hasRadius = NO;
        
        if ([firstArg hasPrefix:@"--radius="]) {
            radius = [[firstArg substringFromIndex:9] floatValue];
            hasRadius = YES;
        } else if ([firstArg isEqualToString:@"-r"] && argc > 2) {
            radius = [[NSString stringWithUTF8String:argv[2]] floatValue];
            hasRadius = YES;
        }

        if (hasRadius) {
            NSLog(@"Setting radius to: %.1f", radius);
            [[NSDistributedNotificationCenter defaultCenter] 
                postNotificationName:@"com.aspauldingcode.apple_sharpener.set_radius"
                object:nil
                userInfo:@{@"radius": @(radius)}];
            printf("Radius set to %.1f\n", radius);
            return 0;
        }

        // Handle on/off/toggle commands
        if ([firstArg isEqualToString:@"on"]) {
            NSLog(@"Sending enable notification");
            [[NSDistributedNotificationCenter defaultCenter] 
                addObserver:[StatusHandler class]
                selector:@selector(handleStatus:)
                name:@"com.aspauldingcode.apple_sharpener.status"
                object:nil
                suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
                
            [[NSDistributedNotificationCenter defaultCenter] 
                postNotificationName:@"com.aspauldingcode.apple_sharpener.enable"
                object:nil
                userInfo:nil
                deliverImmediately:YES];
                
            NSLog(@"Waiting for response...");
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
            NSLog(@"No response received");
            printf("No response received\n");
            return 1;
        } else if ([firstArg isEqualToString:@"off"]) {
            NSLog(@"Sending disable notification");
            [[NSDistributedNotificationCenter defaultCenter] 
                addObserver:[StatusHandler class]
                selector:@selector(handleStatus:)
                name:@"com.aspauldingcode.apple_sharpener.status"
                object:nil
                suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
                
            [[NSDistributedNotificationCenter defaultCenter] 
                postNotificationName:@"com.aspauldingcode.apple_sharpener.disable"
                object:nil
                userInfo:nil
                deliverImmediately:YES];
                
            NSLog(@"Waiting for response...");
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
            NSLog(@"No response received");
            printf("No response received\n");
            return 1;
        } else if ([firstArg isEqualToString:@"toggle"]) {
            [[NSDistributedNotificationCenter defaultCenter] 
                addObserver:[StatusHandler class]
                selector:@selector(handleStatus:)
                name:@"com.aspauldingcode.apple_sharpener.status"
                object:nil
                suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
                
            NSDictionary *userInfo = nil;
            [[NSDistributedNotificationCenter defaultCenter] 
                postNotificationName:@"com.aspauldingcode.apple_sharpener.toggle"
                object:nil
                userInfo:userInfo
                deliverImmediately:YES];
                
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
            printf("No response received\n");
            return 1;
        } else {
            printf("Unknown command: %s\n", [firstArg UTF8String]);
            printUsage();
            return 1;
        }
    }
    return 0;
}
