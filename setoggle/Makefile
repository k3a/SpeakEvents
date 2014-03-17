include theos/makefiles/common.mk

LIBRARY_NAME = Toggle
Toggle_FILES = Toggle.mm
Toggle_INSTALL_PATH = /var/mobile/Library/SBSettings/Toggles/SE

include $(THEOS_MAKE_PATH)/library.mk

test: distclean package install

distclean:
	rm *.deb || true
