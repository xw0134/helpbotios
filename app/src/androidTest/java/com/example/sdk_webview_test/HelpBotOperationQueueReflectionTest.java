package com.example.sdk_webview_test;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.example.HelpBot.HelpBot;
import com.example.HelpBot.core.HelpBotCallback;
import com.example.HelpBot.core.HelpBotContext;
import com.example.HelpBot.core.HelpBotErrorCode;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.junit.Assert.*;

/**
 * HelpBot install/login/showConversation 排队与门禁行为测试（反射版，避免依赖真实网络/WebView）。
 *
 * 设计说明：
 * - 需求要求的关键是“状态机 + 排队 + 失败中止”，这一层可以通过反射直接驱动状态来做确定性验证；
 * - 避免引入真实 WebSDK/网络环境导致测试不稳定。
 */
@RunWith(AndroidJUnit4.class)
public class HelpBotOperationQueueReflectionTest {
    private Context context;

    @Before
    public void setUp() {
        context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        resetInternalStates();
    }

    @After
    public void tearDown() {
        resetInternalStates();
    }

    @Test
    public void testLoginQueuedWhenInstalling_andCanceledOnInstallFailure() throws Exception {
        setInstallState("INSTALLING");
        setLoginState("NOT_LOGGED_IN");

        final CountDownLatch loginFailureLatch = new CountDownLatch(1);
        final HelpBotErrorCode[] codeHolder = new HelpBotErrorCode[1];
        final String[] msgHolder = new String[1];

        HelpBot.login("dummy_token", null, new HelpBotCallback<Void>() {
            @Override
            public void onSuccess(final Void result) {
                // 不应在 install 进行中立刻成功
            }

            @Override
            public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                codeHolder[0] = errorCode;
                msgHolder[0] = errorMessage;
                loginFailureLatch.countDown();
            }
        });

        // 断言：login 已入队
        assertEquals("LOGIN_PENDING", getLoginStateName());
        assertNotNull("pendingLoginRequest 不能为空", getStaticField(HelpBot.class, "pendingLoginRequest"));

        // 驱动：install 失败 -> 必须中止 login 并回调失败
        invokePrivateStaticMethod(HelpBot.class, "onInstallFinished",
                new Class<?>[] { boolean.class, HelpBotErrorCode.class, String.class },
                new Object[] { false, HelpBotErrorCode.NETWORK_UNAVAILABLE, "mock_fail" });

        final boolean failureCalled = loginFailureLatch.await(3, TimeUnit.SECONDS);
        assertTrue("install 失败后应回调 login 失败", failureCalled);
        assertEquals("错误码应透传 install 失败原因", HelpBotErrorCode.NETWORK_UNAVAILABLE, codeHolder[0]);
        assertNotNull("错误消息不能为空", msgHolder[0]);
        assertTrue("错误消息应包含中止提示", msgHolder[0].contains("中止"));

        assertNull("install 失败后 pendingLoginRequest 必须清空", getStaticField(HelpBot.class, "pendingLoginRequest"));
        assertNull("install 失败后 pendingShowConversationRequest 必须清空",
                getStaticField(HelpBot.class, "pendingShowConversationRequest"));
    }

    @Test
    public void testShowConversationQueuedWhenInstalling_andClearedOnInstallFailure() throws Exception {
        setInstallState("INSTALLING");
        setLoginState("NOT_LOGGED_IN");

        assertTrue("install 进行中调用 showConversation 应返回 success(表示已入队)",
                HelpBot.showConversation(context).isSuccess());

        assertNotNull("pendingShowConversationRequest 不能为空",
                getStaticField(HelpBot.class, "pendingShowConversationRequest"));

        invokePrivateStaticMethod(HelpBot.class, "onInstallFinished",
                new Class<?>[] { boolean.class, HelpBotErrorCode.class, String.class },
                new Object[] { false, HelpBotErrorCode.WEBVIEW_UNAVAILABLE, "mock_fail" });

        assertNull("install 失败后 pendingShowConversationRequest 必须清空",
                getStaticField(HelpBot.class, "pendingShowConversationRequest"));
    }

    @Test
    public void testMultipleLoginCallsDuringInstall_secondRejected() throws Exception {
        setInstallState("INSTALLING");
        setLoginState("NOT_LOGGED_IN");

        // 第一次：入队（不应立即回调失败）
        HelpBot.login("token_1", null, (HelpBotCallback<Void>) null);
        assertEquals("LOGIN_PENDING", getLoginStateName());

        // 第二次：应立即失败 OPERATION_IN_PROGRESS
        final CountDownLatch latch = new CountDownLatch(1);
        final HelpBotErrorCode[] codeHolder = new HelpBotErrorCode[1];

        HelpBot.login("token_2", null, new HelpBotCallback<Void>() {
            @Override
            public void onSuccess(final Void result) {
            }

            @Override
            public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                codeHolder[0] = errorCode;
                latch.countDown();
            }
        });

        assertTrue("第二次 login 应立即失败回调", latch.await(2, TimeUnit.SECONDS));
        assertEquals("第二次 login 错误码应为 OPERATION_IN_PROGRESS",
                HelpBotErrorCode.OPERATION_IN_PROGRESS, codeHolder[0]);
    }

    @Test
    public void testLoginRejectedWhenAlreadyLoggedIn() throws Exception {
        // 伪造已安装
        HelpBotContext.installCallSuccessful.set(true);
        setInstallState("INSTALLED");

        // 伪造已登录（通过公开方法同步内部标记）
        HelpBot.markLoginConfirmedFromWeb();

        final CountDownLatch latch = new CountDownLatch(1);
        final HelpBotErrorCode[] codeHolder = new HelpBotErrorCode[1];

        HelpBot.login("token_any", null, new HelpBotCallback<Void>() {
            @Override
            public void onSuccess(final Void result) {
            }

            @Override
            public void onFailure(@NonNull final HelpBotErrorCode errorCode, @NonNull final String errorMessage) {
                codeHolder[0] = errorCode;
                latch.countDown();
            }
        });

        assertTrue("重复 login 应立即失败回调", latch.await(2, TimeUnit.SECONDS));
        assertEquals("重复 login 错误码应为 ALREADY_LOGGED_IN", HelpBotErrorCode.ALREADY_LOGGED_IN, codeHolder[0]);
    }

    // ==================== 反射工具与状态复位 ====================

    private void resetInternalStates() {
        try {
            HelpBotContext.installCallSuccessful.set(false);
        } catch (final Exception ignored) {
        }
        try {
            HelpBotContext.setInstallInProgress(false);
        } catch (final Exception ignored) {
        }
        try {
            setInstallState("NOT_INSTALLED");
            setLoginState("NOT_LOGGED_IN");
            setStaticField(HelpBot.class, "pendingLoginRequest", null);
            setStaticField(HelpBot.class, "pendingShowConversationRequest", null);
        } catch (final Exception ignored) {
        }
        try {
            final Object loginConfirmed = getStaticField(HelpBot.class, "loginConfirmed");
            if (loginConfirmed instanceof java.util.concurrent.atomic.AtomicBoolean) {
                ((java.util.concurrent.atomic.AtomicBoolean) loginConfirmed).set(false);
            }
        } catch (final Exception ignored) {
        }
    }

    private void setInstallState(@NonNull final String enumName) throws Exception {
        setPrivateEnumField(HelpBot.class, "installState", "com.example.HelpBot.HelpBot$InstallState", enumName);
    }

    private void setLoginState(@NonNull final String enumName) throws Exception {
        setPrivateEnumField(HelpBot.class, "loginState", "com.example.HelpBot.HelpBot$LoginState", enumName);
    }

    @NonNull
    private String getLoginStateName() throws Exception {
        final Object v = getStaticField(HelpBot.class, "loginState");
        return v == null ? "null" : String.valueOf(v);
    }

    private static void setPrivateEnumField(@NonNull final Class<?> targetClass,
            @NonNull final String fieldName,
            @NonNull final String enumClassName,
            @NonNull final String enumConstName) throws Exception {
        final Class<?> enumClazz = Class.forName(enumClassName);
        @SuppressWarnings("unchecked")
        final Object enumValue = Enum.valueOf((Class<? extends Enum>) enumClazz, enumConstName);
        setStaticField(targetClass, fieldName, enumValue);
    }

    private static void setStaticField(@NonNull final Class<?> clazz,
            @NonNull final String fieldName,
            final Object value) throws Exception {
        final Field f = clazz.getDeclaredField(fieldName);
        f.setAccessible(true);
        f.set(null, value);
    }

    private static Object getStaticField(@NonNull final Class<?> clazz,
            @NonNull final String fieldName) throws Exception {
        final Field f = clazz.getDeclaredField(fieldName);
        f.setAccessible(true);
        return f.get(null);
    }

    private static Object invokePrivateStaticMethod(@NonNull final Class<?> clazz,
            @NonNull final String methodName,
            @NonNull final Class<?>[] paramTypes,
            @NonNull final Object[] args) throws Exception {
        final Method m = clazz.getDeclaredMethod(methodName, paramTypes);
        m.setAccessible(true);
        return m.invoke(null, args);
    }
}


