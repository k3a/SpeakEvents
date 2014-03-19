##
##  Created by K3A on 5/20/12.
##  Copyright (c) 2012 K3A.
##  Released under GNU GPL
##

GO_EASY_ON_ME = 1

export PATH := bin:$(PATH)
export TARGET=iphone:latest:5.0
export ARCHS = armv7 arm64

include theos/makefiles/common.mk

SUBPROJECTS = SEPrefs speakevent setoggle speakeventssupport #DV
DEBUG = 1

CLD_SOURCES=cld/encodings/compact_lang_det/cldutil.cc \
        cld/encodings/compact_lang_det/cldutil_dbg_empty.cc \
        cld/encodings/compact_lang_det/compact_lang_det.cc \
        cld/encodings/compact_lang_det/compact_lang_det_impl.cc \
        cld/encodings/compact_lang_det/ext_lang_enc.cc \
        cld/encodings/compact_lang_det/getonescriptspan.cc \
        cld/encodings/compact_lang_det/letterscript_enum.cc \
        cld/encodings/compact_lang_det/tote.cc \
        cld/encodings/compact_lang_det/generated/cld_generated_score_quadchrome_0406.cc \
        cld/encodings/compact_lang_det/generated/compact_lang_det_generated_cjkbis_0.cc \
        cld/encodings/compact_lang_det/generated/compact_lang_det_generated_ctjkvz.cc \
        cld/encodings/compact_lang_det/generated/compact_lang_det_generated_deltaoctachrome.cc \
        cld/encodings/compact_lang_det/generated/compact_lang_det_generated_quadschrome.cc \
        cld/encodings/compact_lang_det/win/cld_htmlutils_windows.cc \
        cld/encodings/compact_lang_det/win/cld_unilib_windows.cc \
        cld/encodings/compact_lang_det/win/cld_utf8statetable.cc \
        cld/encodings/compact_lang_det/win/cld_utf8utils_windows.cc \
        cld/encodings/internal/encodings.cc \
        cld/languages/internal/languages.cc

TWEAK_NAME = SpeakEvents
SpeakEvents_FILES = main.mm log.mm KStringAdditions.mm SEActivatorSupport.mm K3AStringFormatter.mm  $(CLD_SOURCES) LibDisplay.m
SpeakEvents_FRAMEWORKS = Foundation CoreFoundation QuartzCore AddressBook UIKit IOKit CoreTelephony AVFoundation Celestial AudioToolbox
SpeakEvents_PRIVATE_FRAMEWORKS = VoiceServices AppSupport BulletinBoard 
SpeakEvents_LDFLAGS  = -v -Llib -lactivator -lsubstrate -Flib  #lcld
#SpeakEvents_LDFLAGS += -Xlinker -x -Xlinker -exported_symbol -Xlinker _Initialize
SpeakEvents_LDFLAGS += -ObjC++ -fobjc-exceptions -fobjc-call-cxx-cdtors
SpeakEvents_CFLAGS = -g -Os -funroll-loops -gdwarf-2 -DCLD_WINDOWS -fno-exceptions -fobjc-exceptions -fobjc-call-cxx-cdtors -Iinclude -Icld

include $(THEOS_MAKE_PATH)/tweak.mk
include $(FW_MAKEDIR)/aggregate.mk

before-package:: $(THEOS_PACKAGE_DIR)
	
distclean:
	rm -rf *.deb | true

test: distclean package install
	ssh ufoxy "killall SpringBoard"
