# Apple Sharpener - AI Coding Agent Instructions

## Project Overview
Apple Sharpener is a macOS system tweak that removes window corner radius to achieve square corners. It's a **dylib injection project** designed to work with the [Ammonia](https://github.com/CoreBedtime/ammonia) injection framework, not a standalone application.

**Critical Architecture Understanding:**
- **Dylib (`libapple_sharpener.dylib`)**: Injected into applications via Ammonia's `DYLD_INSERT_LIBRARIES`, swizzles AppKit window methods at runtime
- **CLI Tool (`sharpener`)**: Standalone binary (NOT injected) that sends Darwin notifications to control the dylib behavior
- **Blacklist (`libapple_sharpener.dylib.blacklist`)**: Process names where injection should be skipped (system daemons, services)

The tweak uses **ZKSwizzle** for method swizzling and **Darwin notifications** (`notify.h`) for IPC between CLI and injected dylib instances.

## Build System & Workflows

### Universal Binary Building
The project builds **universal binaries** (`x86_64`, `arm64`, `arm64e`) using Xcode's clang:
```bash
make              # Build dylib and CLI tool
sudo make install # Install to /var/ammonia/core/tweaks/ and /usr/local/bin/
make test         # Install, force-quit, and relaunch test apps
make delete       # Uninstall and restart apps
```

**Key Makefile patterns:**
- `ARCHS = -arch x86_64 -arch arm64 -arch arm64e` ensures universal binaries
- Dylib uses `-dynamiclib` with `-install_name @rpath/libapple_sharpener.dylib`
- CLI tool links **only Foundation/CoreFoundation** (no AppKit) to avoid circular injection
- Build directory structure mirrors source: `build/src/sharpener/`, `build/ZKSwizzle/`

### Testing Workflow
The `make test` target is essential for development:
1. Builds and installs both dylib and CLI
2. Force-quits test applications (Spotify, Finder, Safari, etc.)
3. Relaunches them to reload with new dylib
4. **Always test after code changes** - dylib is loaded at app launch, not hot-reloadable

## Code Architecture & Patterns

### Method Swizzling with ZKSwizzle
**Pattern used throughout `sharpener.m`:**
```objectivec
ZKSwizzleInterface(AS_NSWindow_CornerRadius, NSWindow, NSWindow)
@implementation AS_NSWindow_CornerRadius
- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
    ZKOrig(void, frameRect, flag);  // Call original implementation
    // Custom logic here
}
@end
```
- `ZKSwizzleInterface(HookClass, TargetClass, Superclass)` creates the hook class
- `ZKOrig(returnType, ...args)` calls the original implementation
- Swizzles are applied automatically when dylib loads (no manual registration needed)

### Window Filtering Strategy
**Critical pattern in `sharpener.m`:**
```objectivec
static inline BOOL isStandardAppWindow(NSWindow *window) {
    if (!window) return NO;
    NSWindowStyleMask mask = window.styleMask;
    return ((mask & NSWindowStyleMaskTitled) &&
            !(mask & (NSWindowStyleMaskHUDWindow | NSWindowStyleMaskUtilityWindow)));
}
```
Only standard titled windows get modified - **preserves menus, popovers, HUD panels**. This is why the blacklist focuses on system processes, not window types.

### Performance Optimizations
- `static inline` for hot-path functions like `isStandardAppWindow()`
- Cached corner mask: `_cachedSquareCornerMask` (1x1 white image for square corners)
- Radius calculations happen once per frame change, not per draw
- `setValue:forKey:@"cornerRadius"` used instead of try/catch for KVC access

### IPC via Darwin Notifications
**CLI → Dylib communication pattern:**
```objectivec
// CLI sends (clitool.m)
notify_post("com.aspauldingcode.apple_sharpener.enable");

// Dylib receives (sharpener.m would need listener - currently not implemented)
// Future implementation would use notify_register_dispatch()
```
**Current limitation:** CLI sends notifications but dylib doesn't listen yet. `toggleSquareCorners()` is called at init, not dynamically. To add runtime control, implement notification handlers in `sharpener.m`.

## Dependency Management

### ZKSwizzle Integration
**Vendored dependency** in `ZKSwizzle/` directory:
- Included as source files, not a framework
- Header: `ZKSwizzle/ZKSwizzle.h`
- Implementation: `ZKSwizzle/ZKSwizzle.m`
- Build with `-IZKSwizzle` flag
- **Do not update without testing** - uses runtime introspection, macOS version-sensitive

### Framework Linking
**Dylib** requires AppKit, QuartzCore, Cocoa:
```makefile
PUBLIC_FRAMEWORKS = -framework Foundation -framework AppKit -framework QuartzCore -framework Cocoa
```

**CLI tool** uses **only** Foundation/CoreFoundation to avoid DYLD_INSERT_LIBRARIES affecting itself (would cause infinite injection loop).

## Critical File Roles

### `libapple_sharpener.dylib.blacklist`
Process names where injection must be skipped (line-delimited):
- System daemons: `launchd`, `WindowServer`, `loginwindow`
- Security services: `amfid`, `securityd`, `trustd`
- **Add new entries** if a process crashes on injection or causes system instability
- Used by Ammonia to skip injection, not read by sharpener code

### `src/sharpener/sharpener.m` - Core Dylib
**Swizzled classes:**
- `AS_NSWindow_CornerRadius` hooks `NSWindow` for corner radius control
- `AS_TitlebarDecorationView` hooks `_NSTitlebarDecorationView` to hide titlebar decorations

**Global state:**
- `enableSharpener` - master on/off toggle
- `enableCustomRadius` - whether to use custom radius
- `customRadius` - the actual radius value (0 = square corners)

### `src/sharpener/clitool.m` - CLI Interface
Commands:
- `sharpener on/off/toggle` - Control enable state
- `sharpener --radius=N` or `-r N` - Set corner radius
- `sharpener --show-radius` or `-s` - Query current setting

## Common Development Tasks

### Adding New Window Behavior
1. Identify target AppKit class/method (use Hopper/class-dump on AppKit framework)
2. Add new `ZKSwizzleInterface` in `sharpener.m`
3. Implement swizzled method with `ZKOrig()` call for original behavior
4. Test with `make test` on multiple apps

### Debugging Injected Code
**Can't use standard debugger** - dylib runs in every process. Instead:
- `NSLog()` output goes to Console.app (filter by process name)
- Add temporary file logging: `[@"debug" writeToFile:@"/tmp/sharpener.log" atomically:YES]`
- Use `make test` to restart apps and reload modified dylib
- Check `/var/log/system.log` for injection failures

### Creating Installer Packages
```bash
./scripts/create_installer.sh
```
- Increments version in `VERSION` variable (manual edit required)
- Logs to `releases` file
- Creates `.pkg` at repo root
- Includes postinstall script to restart Ammonia service

## Security & Runtime Environment

**Required disabled security features:**
- System Integrity Protection (SIP)
- Library Validation
- Apple Silicon: `-arm64e_preview_abi` boot-arg

**Installation locations:**
- Dylib: `/var/ammonia/core/tweaks/libapple_sharpener.dylib`
- CLI: `/usr/local/bin/sharpener`
- Blacklist: `/var/ammonia/core/tweaks/libapple_sharpener.dylib.blacklist`

Ammonia uses `DYLD_INSERT_LIBRARIES` environment variable - dylib loads before `main()` in every non-blacklisted process.

## Conventions to Follow

- Use `AS_` prefix for swizzled class names (Apple Sharpener)
- Notification names: `com.aspauldingcode.apple_sharpener.*`
- All window modifications check `isStandardAppWindow()` first
- Performance-critical functions use `static inline`
- Clean build required after changing headers: `make clean && make`
- Test on both Intel and Apple Silicon when possible
