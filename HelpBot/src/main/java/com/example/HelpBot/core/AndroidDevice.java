package com.example.HelpBot.core;

import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.utils.ApplicationUtils;
import com.example.HelpBot.utils.ValuePair;
import com.example.HelpBot.utils.Utils;
import com.example.HelpBot.storage.HBPersistentStorage;

import android.app.LocaleManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Build;
import android.os.Environment;
import android.os.LocaleList;
import android.os.StatFs;
import android.telephony.TelephonyManager;
import android.util.Base64;

import java.util.Locale;
import java.util.UUID;

/**
 * Android 设备信息实现类。
 * 提供获取 SDK 版本、应用信息、设备模型、电池状态、磁盘空间、网络类型及语言等功能。
 */
public class AndroidDevice implements Device {
    private static final String TAG = "AndroidDevice";
    public static final String LITE_SDK_VERSION = "10.4.0";
    private static final String OS_TYPE = "android";
    private final Context context;
    private final HBPersistentStorage persistentStorage;

    public AndroidDevice(final Context context, final HBPersistentStorage persistentStorage) {
        super();
        this.context = context;
        this.persistentStorage = persistentStorage;
    }

    @Override
    public String getSDKVersion() {
        return LITE_SDK_VERSION;
    }

    @Override
    public String getAppVersion() {
        String appVersion = null;
        try {
            final String packageName = this.getAppIdentifier();
            final PackageInfo p = this.context.getPackageManager().getPackageInfo(packageName, 0);
            appVersion = p.versionName;
        } catch (final Exception e) {
            HBlogger.d(TAG, "获取应用版本号异常", (Throwable) e);
        }
        return appVersion;
    }

    @Override
    public String getAppName() {
        String appName = null;
        try {
            final PackageManager pm = this.context.getPackageManager();
            final ApplicationInfo ai = this.context.getApplicationInfo();
            appName = pm.getApplicationLabel(ai).toString();
        } catch (final Exception e) {
            HBlogger.d(TAG, "获取应用程序名称异常", (Throwable) e);
        }
        if (appName == null) {
            return "Support";
        }
        return appName;
    }

    @Override
    public String getAppIdentifier() {
        return this.context.getPackageName();
    }

    @Override
    public String getDeviceModel() {
        return Build.MODEL;
    }

    @Override
    public String getBatteryLevel() {
        final IntentFilter filter = new IntentFilter("android.intent.action.BATTERY_CHANGED");
        final Intent batteryStatus = this.context.registerReceiver((BroadcastReceiver) null, filter);
        if (batteryStatus == null) {
            return "";
        }
        final int level = batteryStatus.getIntExtra("level", -1);
        final int scale = batteryStatus.getIntExtra("scale", -1);
        if (level < 0 || scale <= 0) {
            return "";
        }
        final int batteryPct = (int) (level / (float) scale * 100.0f);
        return batteryPct + "%";
    }

    @Override
    public String getBatteryStatus() {
        final IntentFilter filter = new IntentFilter("android.intent.action.BATTERY_CHANGED");
        final Intent batteryStatus = this.context.registerReceiver((BroadcastReceiver) null, filter);
        if (batteryStatus == null) {
            return "Not charging";
        }
        final int status = batteryStatus.getIntExtra("status", -1);
        final boolean isCharging = status == 2 || status == 5;
        return isCharging ? "Charging" : "Not charging";
    }

    @Override
    public ValuePair<String, String> getDiskSpace() {
        final double bytesInOneGB = 1.073741824E9;
        final StatFs phoneStat = new StatFs(Environment.getDataDirectory().getPath());
        double freePhoneMemory;
        double totalPhoneMemory;
        if (Build.VERSION.SDK_INT >= 18) {
            freePhoneMemory = phoneStat.getAvailableBlocksLong() * (double) phoneStat.getBlockSizeLong()
                    / bytesInOneGB;
            freePhoneMemory = Math.round(freePhoneMemory * 100.0) / 100.0;
            totalPhoneMemory = phoneStat.getBlockCountLong() * (double) phoneStat.getBlockSizeLong() / bytesInOneGB;
            totalPhoneMemory = Math.round(totalPhoneMemory * 100.0) / 100.0;
        } else {
            freePhoneMemory = phoneStat.getAvailableBlocks() * (double) phoneStat.getBlockSize() / bytesInOneGB;
            freePhoneMemory = Math.round(freePhoneMemory * 100.0) / 100.0;
            totalPhoneMemory = phoneStat.getBlockCount() * (double) phoneStat.getBlockSize() / bytesInOneGB;
            totalPhoneMemory = Math.round(totalPhoneMemory * 100.0) / 100.0;
        }
        return ValuePair.from(totalPhoneMemory + " GB", freePhoneMemory + " GB");
    }

    @Override
    public String getOsType() {
        return OS_TYPE;
    }

    @Override
    public String getOSVersion() {
        return Build.VERSION.RELEASE;
    }

    @Override
    public String getCarrierName() {
        final TelephonyManager tm = (TelephonyManager) this.context.getSystemService(Context.TELEPHONY_SERVICE);
        return (tm == null) ? "" : tm.getNetworkOperatorName();
    }

    @Override
    public String getNetworkType() {
        String type = null;
        try {
            final ConnectivityManager cm = (ConnectivityManager) this.context
                    .getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) {
                return "Unknown";
            }

            // Android 6.0 (API 23) 及以上版本使用新 API
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    final android.net.Network network = cm.getActiveNetwork();
                    if (network != null) {
                        final android.net.NetworkCapabilities capabilities = cm.getNetworkCapabilities(network);
                        if (capabilities != null) {
                            if (capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                                type = "WIFI";
                            } else if (capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR)) {
                                type = "MOBILE";
                            } else if (capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_ETHERNET)) {
                                type = "ETHERNET";
                            } else {
                                type = "UNKNOWN";
                            }
                        }
                    }
                } catch (final Exception e) {
                    HBlogger.w(TAG, "获取网络类型异常 (新 API)", e);
                }
            }

            // Android 6.0 以下版本使用旧 API
            if (type == null) {
                try {
                    final NetworkInfo ani = cm.getActiveNetworkInfo();
                    if (ani != null) {
                        type = ani.getTypeName();
                    }
                } catch (final Exception e) {
                    HBlogger.w(TAG, "获取网络类型异常 (旧 API)", e);
                }
            }
        } catch (final SecurityException e) {
            HBlogger.w(TAG, "获取网络类型权限不足", e);
        } catch (final Exception e) {
            HBlogger.e(TAG, "获取网络类型异常", (Throwable) e);
        }
        if (type == null) {
            type = "Unknown";
        }
        return type;
    }

    @Override
    public String getCountryCode() {
        final TelephonyManager tm = (TelephonyManager) this.context.getSystemService(Context.TELEPHONY_SERVICE);
        return (tm == null) ? "" : tm.getSimCountryIso();
    }

    @Override
    public String getRom() {
        return System.getProperty("os.version") + ":" + Build.FINGERPRINT;
    }

    @Override
    public String getLanguage() {
        String locale = "unknown";
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                final LocaleManager localeManager = this.context.getSystemService(LocaleManager.class);
                final LocaleList localeList = (localeManager == null) ? null : localeManager.getApplicationLocales();
                locale = ApplicationUtils.isLocaleListNotEmpty(localeList)
                        ? localeList.get(0).toLanguageTag()
                        : Locale.getDefault().toLanguageTag();
            } else if (Build.VERSION.SDK_INT >= 21) {
                locale = Locale.getDefault().toLanguageTag();
            } else {
                locale = Locale.getDefault().getLanguage();
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "获取应用语言异常", (Throwable) e);
        }
        return locale;
    }

    @Override
    public boolean isOnline() {
        boolean isOnline = false;
        try {
            final ConnectivityManager connectivityManager = (ConnectivityManager) this.context
                    .getSystemService(Context.CONNECTIVITY_SERVICE);
            if (connectivityManager == null) {
                return false;
            }

            // Android 6.0 (API 23) 及以上版本使用新 API
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    final android.net.Network network = connectivityManager.getActiveNetwork();
                    if (network != null) {
                        final android.net.NetworkCapabilities capabilities = connectivityManager
                                .getNetworkCapabilities(network);
                        isOnline = (capabilities != null &&
                                (capabilities.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                                        capabilities.hasCapability(
                                                android.net.NetworkCapabilities.NET_CAPABILITY_VALIDATED)));
                    }
                } catch (final Exception e) {
                    HBlogger.w(TAG, "检查网络在线状态异常 (新 API)", e);
                }
            }

            // Android 6.0 以下版本使用旧 API
            if (!isOnline) {
                try {
                    final NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
                    isOnline = (activeNetworkInfo != null && activeNetworkInfo.isConnected());
                } catch (final Exception e) {
                    HBlogger.w(TAG, "检查网络在线状态异常 (旧 API)", e);
                }
            }
        } catch (final SecurityException e) {
            HBlogger.w(TAG, "检查网络在线状态权限不足", e);
        } catch (final Exception e) {
            HBlogger.e(TAG, "获取系统连接服务异常", (Throwable) e);
        }
        return isOnline;
    }

    @Override
    public String encodeBase64(final String value) {
        return Base64.encodeToString(value.getBytes(), 2);
    }

    @Override
    public String getDeviceId() {
        String deviceId = this.persistentStorage.getHsDeviceId();
        if (Utils.isEmpty(deviceId)) {
            deviceId = UUID.randomUUID().toString();
            this.persistentStorage.setHsDeviceId(deviceId);
        }
        return deviceId;
    }

    @Override
    public String decodeBase64(final String encodedString) {
        try {
            final byte[] decodedBytes = Base64.decode(encodedString, 8);
            return new String(decodedBytes);
        } catch (final Exception e) {
            HBlogger.d(TAG, "Base64 解码异常", (Throwable) e);
            return "";
        }
    }
}
