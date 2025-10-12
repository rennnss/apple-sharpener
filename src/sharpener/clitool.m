#import <Foundation/Foundation.h>
#import <notify.h>

void printUsage() {
    puts("Usage: sharpener [command] [options]\n"
         "\nCommands:"
         "\n  on             Enable window sharpening"
         "\n  off            Disable window sharpening"
         "\n  toggle         Toggle window sharpening"
         "\n\nOptions:"
         "\n  --radius=<value>, -r <value>  Set the sharpening radius"
         "\n  --show-radius, -s             Query current radius setting"
         "\n  --help, -h                    Show this help message"
         "\n\nExamples:"
         "\n  sharpener --radius=40         Set radius to 40"
         "\n  sharpener -r 40               Set radius to 40"
         "\n  sharpener on                  Enable sharpening"
         "\n  sharpener -s                  Query current radius");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            printUsage();
            return 1;
        }
        
        NSString *firstArg = [NSString stringWithUTF8String:argv[1]];
        
        if ([firstArg isEqualToString:@"--help"] || [firstArg isEqualToString:@"-h"]) {
            printUsage();
            return 0;
        }
        
        if ([firstArg isEqualToString:@"on"]) {
            // Backward-compatible event
            notify_post("com.aspauldingcode.apple_sharpener.enable");
            // Persistent enabled state
            int tokenEnabled = 0;
            if (notify_register_check("com.aspauldingcode.apple_sharpener.enabled", &tokenEnabled) == NOTIFY_STATUS_OK) {
                notify_set_state(tokenEnabled, 1);
                notify_post("com.aspauldingcode.apple_sharpener.enabled");
            }
            printf("Sharpener enabled\n");
        } else if ([firstArg isEqualToString:@"off"]) {
            // Backward-compatible event
            notify_post("com.aspauldingcode.apple_sharpener.disable");
            // Persistent enabled state
            int tokenEnabled = 0;
            if (notify_register_check("com.aspauldingcode.apple_sharpener.enabled", &tokenEnabled) == NOTIFY_STATUS_OK) {
                notify_set_state(tokenEnabled, 0);
                notify_post("com.aspauldingcode.apple_sharpener.enabled");
            }
            printf("Sharpener disabled\n");
        } else if ([firstArg isEqualToString:@"toggle"]) {
            // Backward-compatible event
            notify_post("com.aspauldingcode.apple_sharpener.toggle");
            // Persistent enabled state toggle
            int tokenEnabled = 0;
            if (notify_register_check("com.aspauldingcode.apple_sharpener.enabled", &tokenEnabled) == NOTIFY_STATUS_OK) {
                uint64_t state = 0;
                notify_get_state(tokenEnabled, &state);
                uint64_t newState = (state == 0) ? 1 : 0;
                notify_set_state(tokenEnabled, newState);
                notify_post("com.aspauldingcode.apple_sharpener.enabled");
            }
            printf("Sharpener toggled\n");
        } else if ([firstArg hasPrefix:@"--radius="] || ([firstArg isEqualToString:@"-r"] && argc > 2)) {
            uint64_t radius = 0;
            if ([firstArg hasPrefix:@"--radius="]) {
                radius = strtoull([[firstArg substringFromIndex:9] UTF8String], NULL, 10);
            } else {
                radius = strtoull(argv[2], NULL, 10);
            }
            // Register for the set_radius notification to obtain a token.
            int tokenSetRadius = 0;
            if (notify_register_check("com.aspauldingcode.apple_sharpener.set_radius", &tokenSetRadius) == NOTIFY_STATUS_OK) {
                // Set the state with the token and post the notification.
                notify_set_state(tokenSetRadius, radius);
                notify_post("com.aspauldingcode.apple_sharpener.set_radius");
                printf("Sharpener radius set to %llu\n", radius);
            } else {
                printf("Failed to register set_radius notification\n");
                return 1;
            }
        } else if ([firstArg isEqualToString:@"--show-radius"] || [firstArg isEqualToString:@"-s"]) {
            // Read the current radius from the shared state on the set_radius channel
            int tokenShowRadius = 0;
            uint64_t currentRadius = 0;
            if (notify_register_check("com.aspauldingcode.apple_sharpener.set_radius", &tokenShowRadius) == NOTIFY_STATUS_OK) {
                if (notify_get_state(tokenShowRadius, &currentRadius) != NOTIFY_STATUS_OK) {
                    printf("Failed to read current radius\n");
                    return 1;
                }
            } else {
                printf("Failed to register set_radius notification for reading\n");
                return 1;
            }

            // Read enabled status from persistent state
            int tokenEnabled = 0;
            uint64_t enabledState = 0;
            if (notify_register_check("com.aspauldingcode.apple_sharpener.enabled", &tokenEnabled) == NOTIFY_STATUS_OK) {
                if (notify_get_state(tokenEnabled, &enabledState) != NOTIFY_STATUS_OK) {
                    printf("Failed to read current status\n");
                    return 1;
                }
            } else {
                printf("Failed to register enabled notification for reading\n");
                return 1;
            }

            printf("Current radius: %llu\n", currentRadius);
            printf("Status: %s\n", enabledState ? "on" : "off");
        } else {
            printf("Unknown command: %s\n", [firstArg UTF8String]);
            printUsage();
            return 1;
        }
    }
    return 0;
}
