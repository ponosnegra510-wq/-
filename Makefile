TARGET := iphone:clang:latest:13.0
ARCHS = arm64

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FakePass13

FakePass13_FILES = Tweak.xm
FakePass13_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
FakePass13_FRAMEWORKS = UIKit QuartzCore AudioToolbox

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
