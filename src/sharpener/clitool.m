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
            notify_post("com.aspauldingcode.apple_sharpener.enable");
            printf("Sharpener enabled\n");
        } else if ([firstArg isEqualToString:@"off"]) {
            notify_post("com.aspauldingcode.apple_sharpener.disable");
            printf("Sharpener disabled\n");
        } else if ([firstArg isEqualToString:@"toggle"]) {
            notify_post("com.aspauldingcode.apple_sharpener.toggle");
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
            notify_post("com.aspauldingcode.apple_sharpener.get_radius");
            printf("Radius query sent\n");
        } else {
            printf("Unknown command: %s\n", [firstArg UTF8String]);
            printUsage();
            return 1;
        }
    }
    return 0;
}
