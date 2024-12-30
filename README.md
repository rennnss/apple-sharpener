# Apple Sharpener

A macOS tweak that programmatically removes window corner radius to achieve clean, square corners on all application windows. This tweak is designed to work with the [Ammonia](https://github.com/CoreBedtime/ammonia) injection system.

![License](https://img.shields.io/badge/license-MIT-blue.svg)

![preview](./preview.png)

## Features

- Removes rounded corners from application windows
- Preserves rounded corners for context menus and system UI elements
- Compatible with both Intel and Apple Silicon Macs
- Early injection ensures consistent window appearance

## Requirements

- macOS Ventura or later
- [Ammonia](https://github.com/CoreBedtime/ammonia) injection system installed

### System Security Settings

The following security features must be disabled for Ammonia injection to work:

- System Integrity Protection (SIP)
- Library Validation

To disable these features, you'll need to:

1. Boot into Recovery Mode:
   - For Apple Silicon Macs: Hold the power button until "Loading startup options" appears, then click "Options" and select a user/enter password
   - For Intel Macs: Hold Command-R during startup
2. Open Terminal (from Utilities menu) and run:
   ```bash
   csrutil disable
   ```
3. Restart your Mac:
4. After restart, run in Terminal:
   ```bash
   sudo defaults write /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation -bool true
   ```
5. For Apple Silicon Macs, enable the preview ABI by running:
   ```bash
   sudo nvram boot-args="-arm64e_preview_abi"
   ```

## Installation

### Pre-built Release
Download the latest release from the [releases page](../../releases).

### Building from Source

1. First, ensure you have the Ammonia injector installed:
   ```bash
   git clone https://github.com/CoreBedtime/ammonia
   cd ammonia
   ./install.sh
   ```

2. Then build and install Apple Sharpener:
   ```bash
   git clone https://github.com/yourusername/apple-sharpener
   cd apple-sharpener
   make
   sudo make install
   ```

## How It Works

Apple Sharpener uses method swizzling to modify the window corner mask and titlebar decoration view behavior of macOS applications. It specifically targets application windows while preserving the native appearance of menus, popovers, and other system UI elements.

## Contributing

Contributions are welcome! Feel free to:

- Open issues for bugs or feature requests
- Submit pull requests for improvements
- Share your ideas and suggestions

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Ammonia](https://github.com/CoreBedtime/ammonia) for the injection framework
- [ZKSwizzle](https://github.com/alexzielenski/ZKSwizzle) for the swizzling implementation

## Support

If you encounter any issues or have questions:

1. Check the [Issues](../../issues) page for existing reports
2. Open a new issue if needed
3. Include your macOS version and device type when reporting problems

## ⚠️ Security Notice

This tweak requires disabling several macOS security features. Only proceed if you understand the implications of running your system with reduced security. Always download tweaks from trusted sources.
