LOCAL_PATH := $(call my-dir)

# HelpBot SDK 静态库
include $(CLEAR_VARS)

LOCAL_MODULE := helpbot_static

LOCAL_MODULE_FILENAME := libhelpbot

LOCAL_SRC_FILES := \
    ../../src/HBLogger.cpp \
    ../../src/HelpBot.cpp \
    HelpBotJNI.cpp \
    HelpBotAndroid.cpp

LOCAL_C_INCLUDES := \
    $(LOCAL_PATH)/../../include \
    $(LOCAL_PATH)

LOCAL_EXPORT_C_INCLUDES := \
    $(LOCAL_PATH)/../../include

LOCAL_CPPFLAGS := -std=c++11 -frtti -fexceptions -DANDROID

LOCAL_LDLIBS := -llog -landroid

include $(BUILD_STATIC_LIBRARY)
