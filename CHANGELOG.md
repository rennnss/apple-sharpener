# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.2] - 2025-01-17

### Added
- Complete Apple Sharpener functionality with window corner radius modification
- Command-line interface (CLI) tool for controlling sharpener state
- Dynamic library injection system using ZKSwizzle
- Makefile build system with comprehensive targets (build, install, uninstall, clean, help)
- Package installer creation system with version management
- GitHub Funding configuration
- Comprehensive README with installation and usage instructions
- CLI documentation (CLI.md)
- Build artifacts and crash logging
- Preview images showcasing the functionality
- Blacklist system for library injection control

### Changed
- Adopted Semantic Versioning (SemVer) for version management
- Replaced custom `releases` file with standard `VERSION` file
- Created CHANGELOG.md to track version history
- Improved code organization and removed build warnings
- Enhanced window decoration view logic
- Optimized and decluttered codebase
- Reduced CLI tool impact with less logging and resource usage (closes #5)
- Updated CLI from `-s, --show-radius` to `-s, --status` for better clarity
- Changed installer script to show warning instead of blocking when version exists in CHANGELOG

### Fixed
- Fixed `make help` command compatibility with BSD tools on macOS
- Resolved installer version detection issues
- Fixed all build warnings in sharpener.m
- Improved titlebar decoration view logic
- Restored system defaults when sharpener is disabled
- Enhanced CLI/dylib persistent state hydration and status reporting
- Fixed qBittorrent crashes caused by ZKSwizzle method conflicts (closes #15)
- Fixed reopened applications not having sharp corners after system restart/logout (closes #14)
- Fixed CLI tool showing "dev" instead of actual version number

### Security
- Implemented proper system state restoration when disabled
- Added safeguards for window radius caching and restoration

## [0.0.1] - 2024-12-30

### Added
- Initial commit with basic project structure
- Core functionality foundation
- Square window corner radius