ARCHS = arm64 armv7
TARGET = iphone::

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BegoneCIA
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_EXTRA_FRAMEWORKS += Cephei

include $(THEOS_MAKE_PATH)/tweak.mk