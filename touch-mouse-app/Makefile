# 一键编译和运行 SiriRemoteTouchMouse。

APP_NAME := SiriRemoteHIDProbe
SOURCE := SiriRemoteTouchMouse.m
BUILD_DIR := build
PRODUCT := $(BUILD_DIR)/$(APP_NAME)
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_CONTENTS)/MacOS

.PHONY: all app test run run-app clean

all: $(PRODUCT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(PRODUCT): $(SOURCE) | $(BUILD_DIR)
	clang -fobjc-arc -Wall -Wextra -Werror \
		-framework AppKit \
		-framework ApplicationServices \
		-framework CoreFoundation \
		-framework IOKit \
		-F/System/Library/PrivateFrameworks \
		-framework MultitouchSupport \
		$(SOURCE) \
		-o $(PRODUCT)
	codesign --force --sign - $(PRODUCT)

app: $(PRODUCT)
	mkdir -p $(APP_MACOS)
	cp Info.plist $(APP_CONTENTS)/Info.plist
	cp $(PRODUCT) $(APP_MACOS)/$(APP_NAME)
	codesign --force --deep --sign - $(APP_BUNDLE)

test: $(PRODUCT)
	$(PRODUCT) --self-test

run: $(PRODUCT)
	$(PRODUCT)

run-app: app
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR)
