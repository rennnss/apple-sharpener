ifeq (,$(filter help completion,$(MAKECMDGOALS)))
  # Dynamic compiler detection
  XCODE_PATH := $(shell xcode-select -p)
  XCODE_TOOLCHAIN := $(XCODE_PATH)/Toolchains/XcodeDefault.xctoolchain
  CC := $(shell xcrun -find clang)
  CXX := $(shell xcrun -find clang++)

  # SDK paths
  SDKROOT ?= $(shell xcrun --show-sdk-path)
  ISYSROOT := $(shell xcrun -sdk macosx --show-sdk-path)
  INCLUDE_PATH := $(shell xcrun -sdk macosx --show-sdk-platform-path)/Developer/SDKs/MacOSX.sdk/usr/include
else
  # Fallbacks for non-build goals to avoid SDK discovery
  CC := clang
  CXX := clang++
  SDKROOT :=
  ISYSROOT :=
  INCLUDE_PATH :=
endif

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
INSTALL_DIR = /var/ammonia/core/tweaks
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
all: clean $(BUILD_DIR)/$(DYLIB_NAME) $(BUILD_DIR)/$(CLI_NAME) ## Build dylib and CLI

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

# Build CLI tool (updated to avoid linking UI frameworks)
$(BUILD_DIR)/$(CLI_NAME): $(CLI_SOURCE)
	@rm -f $(BUILD_DIR)/$(CLI_NAME)
	$(CC) $(CFLAGS) $(ARCHS) $(CLI_SOURCE) \
		-DAPPLE_SHARPENER_VERSION="\"$(shell cat VERSION)\"" \
		-framework Foundation \
		-framework CoreFoundation \
		-o $@

# Install both dylib and CLI tool
install: $(BUILD_DIR)/$(DYLIB_NAME) $(BUILD_DIR)/$(CLI_NAME) ## Install dylib and CLI to system
	@echo "Installing dylib to $(INSTALL_DIR) and CLI tool to $(CLI_INSTALL_DIR)"
	# Create the target directories.
	sudo mkdir -p $(INSTALL_DIR)
	sudo mkdir -p $(CLI_INSTALL_DIR)
	# Install the tweak's dylib where injection takes place.
	sudo install -m 755 $(BUILD_DIR)/$(DYLIB_NAME) $(INSTALL_DIR)
	# Install the CLI tool separately so it will not have DYLD_INSERT_LIBRARIES set.
	sudo install -m 755 $(BUILD_DIR)/$(CLI_NAME) $(CLI_INSTALL_DIR)
	@if [ -f $(BLACKLIST_SOURCE) ]; then \
		sudo cp $(BLACKLIST_SOURCE) $(BLACKLIST_DEST); \
		sudo chmod 644 $(BLACKLIST_DEST); \
		echo "Installed $(DYLIB_NAME), $(CLI_NAME), and blacklist"; \
	else \
		echo "Warning: $(BLACKLIST_SOURCE) not found"; \
		echo "Installed $(DYLIB_NAME) and $(CLI_NAME)"; \
	fi

# Test target that builds, installs, and relaunches test applications
test: install ## Build, install, and restart test applications
	@echo "Force quitting test applications..."
	$(eval TEST_APPS := Spotify "System Settings" Chess soffice "Brave Browser" Beeper Safari Finder)
	@for app in $(TEST_APPS); do \
		pkill -9 "$$app" 2>/dev/null || true; \
	done
	@echo "Relaunching test applications..."
	@for app in $(TEST_APPS); do \
		if [ "$$app" != "soffice" ]; then \
			open -a "$$app" 2>/dev/null || true; \
		fi; \
	done
	@echo "Test applications restarted with new dylib loaded"

# Clean build files
clean: ## Remove build directory and artifacts
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"

# Delete installed files
delete: ## Delete installed files and relaunch Finder
	@echo "Force quitting test applications..."
	$(eval TEST_APPS := Spotify "System Settings" Chess soffice "Brave Browser" Beeper Safari Finder)
	@for app in $(TEST_APPS); do \
		pkill -9 "$$app" 2>/dev/null || true; \
	done
	@sleep 2 && open -a "Finder" || true
	@sudo rm -f $(INSTALL_PATH)
	@sudo rm -f $(CLI_INSTALL_PATH)
	@sudo rm -f $(BLACKLIST_DEST)
	@echo "Deleted $(DYLIB_NAME), $(CLI_NAME), and blacklist from $(INSTALL_DIR)"

# Uninstall
uninstall: ## Uninstall dylib, CLI, and blacklist
	@sudo rm -f $(INSTALL_PATH)
	@sudo rm -f $(CLI_INSTALL_PATH)
	@sudo rm -f $(BLACKLIST_DEST)
	@echo "Uninstalled $(DYLIB_NAME), $(CLI_NAME), and blacklist"

installer: ## Create a .pkg installer
	@echo "Packaging Apple Sharpener into a .pkg installer"
	./scripts/create_installer.sh

help: ## Show this help
	@echo "Available make targets:"
	@grep -E '^[a-zA-Z0-9_.-]+:.*##' $(MAKEFILE_LIST) | sed 's/^\([^:]*\):.*##\s*\(.*\)/  \1|\2/' | awk -F'|' '{printf "  %-20s %s\n", $$1, $$2}'

.PHONY: all clean install test delete uninstall installer help
