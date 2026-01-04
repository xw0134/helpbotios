package com.example.HelpBot.core;
import com.example.HelpBot.utils.ValuePair;

public interface Device
{
    String getSDKVersion();

    String getAppVersion();

    String getAppName();

    String getAppIdentifier();

    String getDeviceModel();

    String getBatteryLevel();

    String getBatteryStatus();

    ValuePair<String, String> getDiskSpace();

    String getOsType();

    String getOSVersion();

    String getCarrierName();

    String getNetworkType();

    String getCountryCode();

    String getRom();

    String getLanguage();

    boolean isOnline();

    String encodeBase64(final String p0);

    String getDeviceId();

    String decodeBase64(final String p0);
}

