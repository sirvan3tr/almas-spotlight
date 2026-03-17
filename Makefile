XCODE_DEV_DIR = /Applications/Xcode.app/Contents/Developer
BINARY     = AlmasSpotlight
CLI        = almas-search
APP        = $(BINARY).app
INSTALL    = $(HOME)/Applications
BUILD_REL  = .build/release/$(BINARY)
BUILD_DBG  = .build/debug/$(BINARY)
CLI_REL    = .build/release/$(CLI)
CLI_DBG    = .build/debug/$(CLI)

ifneq ("$(wildcard $(XCODE_DEV_DIR))","")
export DEVELOPER_DIR ?= $(XCODE_DEV_DIR)
endif

export CLANG_MODULE_CACHE_PATH ?= /tmp/clang-module-cache
export SWIFTPM_MODULECACHE_OVERRIDE ?= /tmp/swiftpm-module-cache

.PHONY: all build app install run search kill restart clean

all: build

## Build all targets (release)
build:
	swift build -c release

## Wrap release binary in a .app bundle (local)
app: build
	@rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BUILD_REL) $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	@echo "Built $(APP)"

## Install .app into ~/Applications
install: app
	@mkdir -p $(INSTALL)
	@rm -rf $(INSTALL)/$(APP)
	cp -r $(APP) $(INSTALL)/
	@echo "Installed → $(INSTALL)/$(APP)"
	@echo "Open with: open $(INSTALL)/$(APP)"

## Debug run (no .app bundle needed)
run:
	swift build 2>&1 && $(BUILD_DBG)

## Interactive fuzzy-search tester: make search q="spotify"
search:
	swift build --product $(CLI) 2>&1 && $(CLI_DBG) $(q)

## Kill any running instance
kill:
	pkill -x $(BINARY) || true

## Reinstall and restart
restart: install kill
	open $(INSTALL)/$(APP)

## Remove build artefacts and local .app
clean:
	swift package clean
	rm -rf $(APP)
