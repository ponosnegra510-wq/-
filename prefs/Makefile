include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FakePass13Prefs

FakePass13Prefs_FILES = FakePass13RootListController.m
FakePass13Prefs_FRAMEWORKS = UIKit
FakePass13Prefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
# Preferences.framework exists on the device only (no .tbd stub in the SDK),
# so we do not link against it: PSListController/PSSpecifier classes are
# resolved at runtime from the Preferences process.
FakePass13Prefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
FakePass13Prefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
