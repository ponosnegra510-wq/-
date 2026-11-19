include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FakePass13Prefs

FakePass13Prefs_FILES = FakePass13RootListController.m
FakePass13Prefs_FRAMEWORKS = UIKit
FakePass13Prefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
# Preferences.framework есть только на устройстве, в SDK нет .tbd —
# поэтому не линкуемся с ним, классы PSListController/PSSpecifier
# подхватываются в рантайме из процесса Preferences.
FakePass13Prefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
FakePass13Prefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
