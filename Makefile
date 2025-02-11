# Dynamic compiler detection
XCODE_PATH := $(shell xcode-select -p)
XCODE_TOOLCHAIN := $(XCODE_PATH)/Toolchains/XcodeDefault.xctoolchain
CC := $(shell xcrun -find clang)
CXX := $(shell xcrun -find clang++)

# SDK paths
SDKROOT ?= $(shell xcrun --show-sdk-path)
ISYSROOT := $(shell xcrun -sdk macosx --show-sdk-path)
INCLUDE_PATH := $(shell xcrun -sdk macosx --show-sdk-platform-path)/Developer/SDKs/MacOSX.sdk/usr/include

# Compiler and flags
CFLAGS = -Wall -Wextra -O2 \
    -fobjc-arc \
    -isysroot $(SDKROOT) \
    -iframework $(SDKROOT)/System/Library/Frameworks \
    -F/System/Library/PrivateFrameworks \
    -IZKSwizzle
ARCHS = -arch x86_64 -arch arm64 -arch arm64e
FRAMEWORK_PATH = $(SDKROOT)/System/Library/Frameworks
PRIVATE_FRAMEWORK_PATH = $(SDKROOT)/System/Library/PrivateFrameworks
PUBLIC_FRAMEWORKS = -framework Foundation -framework AppKit -framework QuartzCore -framework Cocoa \
    -framework CoreFoundation

# Project name and paths
PROJECT = apple_sharpener
DYLIB_NAME = lib$(PROJECT).dylib
CLI_NAME = sharpener
BUILD_DIR = build
SOURCE_DIR = src
INSTALL_DIR = /usr/local/bin/ammonia/tweaks
CLI_INSTALL_DIR = /usr/local/bin

# Source files
DYLIB_SOURCES = $(SOURCE_DIR)/sharpener/sharpener.m ZKSwizzle/ZKSwizzle.m
DYLIB_OBJECTS = $(DYLIB_SOURCES:%.m=$(BUILD_DIR)/%.o)

# CLI tool source and object
CLI_SOURCE = $(SOURCE_DIR)/sharpener/clitool.m
CLI_OBJECT = $(BUILD_DIR)/sharpener/clitool.o

# Installation targets
INSTALL_PATH = $(INSTALL_DIR)/$(DYLIB_NAME)
CLI_INSTALL_PATH = $(CLI_INSTALL_DIR)/$(CLI_NAME)
BLACKLIST_SOURCE = lib$(PROJECT).dylib.blacklist
BLACKLIST_DEST = $(INSTALL_DIR)/lib$(PROJECT).dylib.blacklist

# Dylib settings
DYLIB_FLAGS = -dynamiclib \
              -install_name @rpath/$(DYLIB_NAME) \
              -compatibility_version 1.0.0 \
              -current_version 1.0.0

# Default target
all: clean $(BUILD_DIR)/$(DYLIB_NAME) $(BUILD_DIR)/$(CLI_NAME)

# Create build directory and subdirectories
$(BUILD_DIR):
	@rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/ZKSwizzle
	@mkdir -p $(BUILD_DIR)/src/sharpener

# Compile source files
$(BUILD_DIR)/%.o: %.m | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(ARCHS) -c $< -o $@

# Link dylib
$(BUILD_DIR)/$(DYLIB_NAME): $(DYLIB_OBJECTS)
	$(CC) $(DYLIB_FLAGS) $(ARCHS) $(DYLIB_OBJECTS) -o $@ \
	-F$(FRAMEWORK_PATH) \
	-F$(PRIVATE_FRAMEWORK_PATH) \
	$(PUBLIC_FRAMEWORKS) \
	-L$(SDKROOT)/usr/lib

# Build CLI tool
$(BUILD_DIR)/$(CLI_NAME): $(CLI_SOURCE) $(BUILD_DIR)/$(DYLIB_NAME)
	@rm -f $(BUILD_DIR)/$(CLI_NAME)
	$(CC) $(CFLAGS) $(ARCHS) \
	$(CLI_SOURCE) $(BUILD_DIR)/$(DYLIB_NAME) \
	$(PUBLIC_FRAMEWORKS) \
	-Wl,-rpath,$(INSTALL_DIR) \
	-o $@

# Install both dylib and CLI tool
install: $(BUILD_DIR)/$(DYLIB_NAME) $(BUILD_DIR)/$(CLI_NAME)
	@sudo mkdir -p $(INSTALL_DIR)
	@sudo cp $(BUILD_DIR)/$(DYLIB_NAME) $(INSTALL_PATH)
	@sudo chmod 755 $(INSTALL_PATH)
	@sudo cp $(BUILD_DIR)/$(CLI_NAME) $(CLI_INSTALL_PATH)
	@sudo chmod 755 $(CLI_INSTALL_PATH)
	@if [ -f $(BLACKLIST_SOURCE) ]; then \
		sudo cp $(BLACKLIST_SOURCE) $(BLACKLIST_DEST); \
		sudo chmod 644 $(BLACKLIST_DEST); \
		echo "Installed $(DYLIB_NAME), $(CLI_NAME), and blacklist"; \
	else \
		echo "Warning: $(BLACKLIST_SOURCE) not found"; \
		echo "Installed $(DYLIB_NAME) and $(CLI_NAME)"; \
	fi

# Test target that builds, installs, and relaunches test applications
test: install
	@echo "Clearing previous logs..."
	@sudo log erase --all
	@echo "Force quitting test applications..."
	@pkill -9 "Spotify" 2>/dev/null || true
	@pkill -9 "System Settings" 2>/dev/null || true
	@pkill -9 "Chess" 2>/dev/null || true
	@pkill -9 "soffice" 2>/dev/null || true
	@pkill -9 "Brave Browser" 2>/dev/null || true
	@pkill -9 "Beeper" 2>/dev/null || true
	@pkill -9 "Safari" 2>/dev/null || true
	@pkill -9 "Finder" 2>/dev/null && sleep 2 && open -a "Finder" || true
	@echo "Restarting ammonia injector..."
	@sudo pkill -9 ammonia || true
	@sleep 2
	@sudo launchctl bootout system /Library/LaunchDaemons/com.bedtime.ammonia.plist 2>/dev/null || true
	@sleep 2
	@sudo launchctl bootstrap system /Library/LaunchDaemons/com.bedtime.ammonia.plist
	@sleep 2
	@echo "Ammonia injector restarted"
	@echo "Waiting for system to stabilize..."
	@sleep 5
	@echo "Launching test applications..."
	@open -a "Spotify" || echo "Failed to open Spotify"
	@sleep 1
	@open -a "System Settings" || echo "Failed to open System Settings"
	@sleep 1
	@open -a "Chess" || echo "Failed to open Chess"
	@sleep 1
	@open -a "LibreOffice" || echo "Failed to open LibreOffice"
	@sleep 1
	@open -a "Brave Browser" || echo "Failed to open Brave Browser"
	@sleep 1
	@open -a "Beeper" || echo "Failed to open Beeper"
	@sleep 1
	@open -a "Safari" || echo "Failed to open Safari"
	@sleep 1
	@echo "Test applications launched"
	@echo "Checking logs..."
	@log show --predicate 'subsystem == "com.aspauldingcode.$(PROJECT)"' --debug --last 5m > test_output.log || true
	@echo "Checking log for specific entries..."
	@grep "Loaded" test_output.log || echo "No relevant log entries found."

# Clean build files
clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"

# Delete installed files
delete:
	@echo "Force quitting test applications..."
	@pkill -9 "Spotify" 2>/dev/null || true
	@pkill -9 "System Settings" 2>/dev/null || true
	@pkill -9 "Chess" 2>/dev/null || true
	@pkill -9 "soffice" 2>/dev/null || true
	@pkill -9 "Brave Browser" 2>/dev/null || true
	@pkill -9 "Beeper" 2>/dev/null || true
	@pkill -9 "Safari" 2>/dev/null || true
	@pkill -9 "Finder" 2>/dev/null && sleep 2 && open -a "Finder" || true
	@sudo rm -f $(INSTALL_PATH)
	@sudo rm -f $(CLI_INSTALL_PATH)
	@sudo rm -f $(BLACKLIST_DEST)
	@echo "Deleted $(DYLIB_NAME), $(CLI_NAME), and blacklist from $(INSTALL_DIR)"

# Uninstall
uninstall:
	@sudo rm -f $(INSTALL_PATH)
	@sudo rm -f $(CLI_INSTALL_PATH)
	@sudo rm -f $(BLACKLIST_DEST)
	@echo "Uninstalled $(DYLIB_NAME), $(CLI_NAME), and blacklist"

.PHONY: all clean install test delete uninstall 