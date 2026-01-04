package com.example.HelpBot.utils;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkInfo;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * 网络诊断工具（SDK 内部使用）
 *
 * 设计目标：
 * - 不抛异常：所有系统调用 try-catch 包裹，避免影响宿主稳定性
 * - 兼容 Android 5.0+（minSdk=21）
 * - 在“无网/网络受限/被策略拦截导致初始化超时”的场景给出更可行动的提示
 */
public final class NetworkUtils {
    private NetworkUtils() {
        throw new AssertionError("NetworkUtils 不能被实例化");
    }

    /**
     * 网络诊断结果（只做提示用，非强一致网络判定）。
     */
    public static final class NetworkDiagnosis {
        public final boolean hasAccessNetworkStatePermission;
        public final boolean networkConnected;
        public final boolean hasInternetCapability;
        public final boolean validated; // API 23+ 可能可用；低版本恒 false
        @Nullable
        public final String transport; // WIFI / CELLULAR / ETHERNET / VPN / UNKNOWN

        private NetworkDiagnosis(
                final boolean hasPermission,
                final boolean connected,
                final boolean hasInternet,
                final boolean validated,
                @Nullable final String transport) {
            this.hasAccessNetworkStatePermission = hasPermission;
            this.networkConnected = connected;
            this.hasInternetCapability = hasInternet;
            this.validated = validated;
            this.transport = transport;
        }

        /**
         * 生成面向宿主的提示语（用于 install/login 超时/失败时的错误 message）。
         */
        @NonNull
        public String buildUserHint() {
            if (!hasAccessNetworkStatePermission) {
                // 仍可提示“可能网络问题”，但不强判
                return "无法读取网络状态（缺少 ACCESS_NETWORK_STATE 权限），请确认设备网络可用且未被防火墙/代理策略拦截。";
            }
            if (!networkConnected) {
                return "当前设备无可用网络连接（可能飞行模式/系统网络关闭/宿主禁用网络）。";
            }
            if (!hasInternetCapability) {
                return "当前网络不具备互联网能力（可能为局域网/受限网络），请切换到可访问互联网的网络环境。";
            }
            if (validated) {
                return "当前网络已连接且可访问互联网。若仍初始化失败，请检查域名是否被企业防火墙/DNS/代理策略拦截。";
            }
            return "当前网络已连接但互联网可用性未验证（可能需要认证/受限网络/被策略拦截）。若初始化超时，请检查防火墙/DNS/代理/VPN。";
        }
    }

    @NonNull
    public static NetworkDiagnosis diagnose(@NonNull final Context context) {
        boolean hasPermission = false;
        try {
            hasPermission = context.checkCallingOrSelfPermission(Manifest.permission.ACCESS_NETWORK_STATE)
                    == PackageManager.PERMISSION_GRANTED;
        } catch (final Exception ignored) {
            hasPermission = false;
        }

        if (!hasPermission) {
            // 无权限时不做强判，避免误报
            return new NetworkDiagnosis(false, false, false, false, null);
        }

        try {
            final ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) {
                return new NetworkDiagnosis(true, false, false, false, null);
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                final Network network = cm.getActiveNetwork();
                if (network == null) {
                    return new NetworkDiagnosis(true, false, false, false, null);
                }
                final NetworkCapabilities caps = cm.getNetworkCapabilities(network);
                if (caps == null) {
                    return new NetworkDiagnosis(true, false, false, false, null);
                }

                final boolean hasInternet = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
                final boolean validated = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED);
                final boolean connected = hasInternet || caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED);

                return new NetworkDiagnosis(true, connected, hasInternet, validated, getTransportName(caps));
            }

            // API 21-22：降级使用 NetworkInfo（已废弃但兼容）
            final NetworkInfo info = cm.getActiveNetworkInfo();
            if (info == null) {
                return new NetworkDiagnosis(true, false, false, false, null);
            }
            final boolean connected = info.isConnected();
            final boolean hasInternet = connected; // 低版本无法判断“互联网能力/验证”，保守处理
            return new NetworkDiagnosis(true, connected, hasInternet, false, info.getTypeName());
        } catch (final Exception ignored) {
            return new NetworkDiagnosis(true, false, false, false, null);
        }
    }

    @Nullable
    private static String getTransportName(@NonNull final NetworkCapabilities caps) {
        try {
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                return "WIFI";
            }
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                return "CELLULAR";
            }
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
                return "ETHERNET";
            }
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                return "VPN";
            }
            return "UNKNOWN";
        } catch (final Exception ignored) {
            return null;
        }
    }
}

