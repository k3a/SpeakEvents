GO_EASY_ON_ME = 1
DEBUG = 1
export TARGET=iphone:latest:5.1.1
export ARCHS = armv7 arm64

include theos/makefiles/common.mk

BUNDLE_NAME = SEPrefs
SEPrefs_FILES = SEPrefs.mm SEPrefsAppToggleController.mm SEHourController.mm SELangPrefs.mm
SEPrefs_INSTALL_PATH = /Library/PreferenceBundles
SEPrefs_FRAMEWORKS = UIKit Accounts Twitter MessageUI
SEPrefs_PRIVATE_FRAMEWORKS = Preferences AppSupport
SEPrefs_CFLAGS = -I../include
SEPrefs_LDFLAGS = -L../lib -lapplist

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SEPrefs.plist$(ECHO_END)

test: all stage
	ssh root@ufoxy "rm -rf /Library/PreferenceBundles/SEPrefs.bundle ; killall Preferences || true"
	scp -r $(THEOS_STAGING_DIR)/* root@ufoxy:/
	ssh root@ufoxy "sbopenurl 'prefs:root=SpeakEvents'"
