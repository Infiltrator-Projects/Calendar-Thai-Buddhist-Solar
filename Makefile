# SPDX-License-Identifier: GPL-3.0-or-later
# Native C++20 chronology module; Common owns generic C ABI, validation and shared code.
.DEFAULT_GOAL := all
CC ?= cc
CXX ?= g++
PKG_CONFIG ?= pkg-config
BUILD_DIR ?= build
RESOURCE_NAME := Historical Thai Buddhist Solar Calendar
COMMON_DIR := common
COMMON_REVISION := f1788fdfb981524172ddfa65a46ead52c33719c6
COMMON_VERSION := 1.19.80
COMMON_BUILD_DIR := $(abspath $(BUILD_DIR))/common
COMMON_ARCHIVE := $(COMMON_BUILD_DIR)/libinfiltratr-common.a
DEPENDENCIES := glib-2.0
SOURCES := $(shell find src -type f -name '*.cpp' | LC_ALL=C sort)
TARGET := $(BUILD_DIR)/$(RESOURCE_NAME).so
DEP_CFLAGS := $(shell $(PKG_CONFIG) --cflags $(DEPENDENCIES))
DEP_LIBS := $(shell $(PKG_CONFIG) --libs $(DEPENDENCIES))
CPPFLAGS += -I$(COMMON_DIR)/include -Iinclude -Isrc -Isrc/support -Isrc/calendars -Isrc/calendars/engine \
    -include include/provider-config.h -DGETTEXT_PACKAGE=\"infiltrator-temporal-resources\" \
    -DU_DISABLE_RENAMING=1 -DGLIB_VERSION_MIN_REQUIRED=GLIB_VERSION_2_74 \
    -DGLIB_VERSION_MAX_ALLOWED=GLIB_VERSION_2_74
CXXFLAGS ?= -O2 -g
CXXFLAGS += -std=c++20 -fPIC -fvisibility=hidden -ffunction-sections -fdata-sections \
    -Wall -Wextra -Wpedantic -Werror -Wformat=2 -Wshadow -fstack-protector-strong \
    -fno-common -ffile-prefix-map=$(CURDIR)=. -fdebug-prefix-map=$(CURDIR)=.
LDLIBS += $(DEP_LIBS) -lm -ldl -pthread
.PHONY: common-check all check audit-authorities clean release deb native-deb
common-check:
	@test -f "$(COMMON_DIR)/VERSION" || { echo "Common submodule missing" >&2; exit 1; }
	@grep -qx "$(COMMON_VERSION)" "$(COMMON_DIR)/VERSION" || { echo "Common version mismatch" >&2; exit 1; }
	@if test -e "$(COMMON_DIR)/.git"; then \
	   git -C "$(COMMON_DIR)" rev-parse HEAD | grep -qx "$(COMMON_REVISION)" || { echo "Common pin mismatch" >&2; exit 1; }; \
	 fi
	@test ! -d include/infiltratr || { echo "Copied Common headers forbidden" >&2; exit 1; }
$(COMMON_ARCHIVE): common-check
	@mkdir -p "$(COMMON_BUILD_DIR)"
	$(MAKE) -C "$(COMMON_DIR)" CC="$(CC)" BUILD_DIR="$(COMMON_BUILD_DIR)" all
all: $(COMMON_ARCHIVE)
	@mkdir -p "$(BUILD_DIR)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(DEP_CFLAGS) -shared $(SOURCES) $(COMMON_ARCHIVE) \
	  -Wl,--version-script=exports.map -Wl,-z,defs -Wl,--gc-sections \
	  $(LDFLAGS) -o "$(TARGET)" $(LDLIBS)
check: all
	bash common/calendar-tools/check.sh "$(TARGET)"
audit-authorities: all
	bash common/calendar-tools/check.sh "$(TARGET)" --authorities
clean:
	rm -rf "$(BUILD_DIR)"
release:
	bash common/calendar-tools/build.sh release
deb:
	bash common/calendar-tools/build.sh deb --profile portable
native-deb:
	bash common/calendar-tools/build.sh deb --profile aggressive
