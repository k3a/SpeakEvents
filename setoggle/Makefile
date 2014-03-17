include theos/makefiles/common.mk

LIBRARY_NAME = Toggle
Toggle_FILES = Toggle.mm
Toggle_INSTALL_PATH = /var/mobile/Library/SBSettings/Toggles/SE

export TARGET=iphone:latest:5.0
export ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/library.mk

test: distclean package install

distclean:
	rm *.deb || true
