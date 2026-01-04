package com.example.sdk_webview_test;

import android.content.Context;
import android.util.Log;

import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;

import com.example.HelpBot.HelpBot;
import com.example.HelpBot.core.HelpBotAuthenticationFailureReason;
import com.example.HelpBot.core.HelpBotContext;
import com.example.HelpBot.core.HelpBotEventsListener;
import com.example.HelpBot.core.HelpBotUserLoginEventsListener;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.junit.Assert.*;

/**
 * HelpBot SDK 自动化测试类
 * 测试所有核心功能：token创建、install、login、更新META、图标更改、获取信息等
 * 
 * @author HelpBot Team
 * @version 1.0.0
 */
@RunWith(AndroidJUnit4.class)
public class HelpBotAutomatedTest {
    private static final String TAG = "HelpBotAutomatedTest";

    // 测试配置
    private static final String TEST_DOMAIN = "dev-bot-server.yuedongcs.com";
    private static final String TEST_CHANNEL = "appc-20251126114209416-ptvea1y414vey36";
    private static final String TEST_TOKEN_URL = "https://dev-bot-server.yuedongcs.com:8123/generate_token";
    private static final String TEST_IDENTIFIER = "uid";
    private static final String TEST_VALUE = "123456789";

    // 日志文件路径
    private static final String LOG_FILE_PATH = InstrumentationRegistry.getInstrumentation().getTargetContext()
            .getFilesDir().getAbsolutePath() + "/helpbot_test.log";

    private Context context;
    private String token;
    private boolean loginSuccess = false;
    private String loginFailureReason = null;

    /**
     * 测试前准备
     */
    @Before
    public void setUp() {
        context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        log("========== 测试开始 ==========");
        log("测试环境: " + context.getPackageName());
    }

    /**
     * 测试后清理
     */
    @After
    public void tearDown() {
        log("========== 测试结束 ==========");
    }

    /**
     * 测试1: 创建Token
     */
    @Test
    public void testCreateToken() throws Exception {
        log("\n[测试1] 开始测试Token创建...");

        final CountDownLatch latch = new CountDownLatch(1);
        final String[] resultToken = new String[1];
        final Exception[] exception = new Exception[1];

        try {
            // 构造请求体
            JSONObject requestBody = new JSONObject();
            JSONArray identitiesArray = new JSONArray();
            JSONObject identity = new JSONObject();
            identity.put("identifier", TEST_IDENTIFIER);
            identity.put("value", TEST_VALUE);
            identitiesArray.put(identity);
            requestBody.put("identities", identitiesArray);

            String jsonString = requestBody.toString();
            log("请求URL: " + TEST_TOKEN_URL);
            log("请求体: " + jsonString);

            // 发送POST请求
            OkHttpUtils.postRequest(TEST_TOKEN_URL, jsonString, new OkHttpUtils.PostCallback() {
                @Override
                public void onSuccess(String response) {
                    log("Token响应: " + response);
                    try {
                        JSONObject jsonResponse = new JSONObject(response);
                        resultToken[0] = jsonResponse.getString("token");
                        log("Token提取成功: " + (resultToken[0] != null ? "是" : "否"));
                    } catch (Exception e) {
                        exception[0] = e;
                        log("Token解析失败: " + e.getMessage());
                    }
                    latch.countDown();
                }

                @Override
                public void onFailure(Exception e) {
                    exception[0] = e;
                    log("Token创建失败: " + e.getMessage());
                    latch.countDown();
                }
            });

            // 等待响应（最多30秒）
            boolean completed = latch.await(30, TimeUnit.SECONDS);
            assertTrue("Token创建超时", completed);
            assertNull("Token创建异常: " + (exception[0] != null ? exception[0].getMessage() : ""), exception[0]);
            assertNotNull("Token为空", resultToken[0]);
            assertFalse("Token为空字符串", resultToken[0].isEmpty());

            token = resultToken[0];
            log("[测试1] ✅ Token创建成功: " + token.substring(0, Math.min(50, token.length())) + "...");

        } catch (Exception e) {
            log("[测试1] ❌ Token创建失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试2: SDK初始化 (Install)
     */
    @Test
    public void testInstall() throws Exception {
        log("\n[测试2] 开始测试SDK初始化...");

        try {
            // 验证SDK未初始化
            boolean beforeInstall = HelpBotContext.verifyInstall();
            log("安装前状态: " + (beforeInstall ? "已安装" : "未安装"));

            // 执行安装（仅异步：SDK 已移除同步 install 接口）
            log("执行installAsync: domain=" + TEST_DOMAIN + ", channel=" + TEST_CHANNEL);
            final CountDownLatch installLatch = new CountDownLatch(1);
            final com.example.HelpBot.core.HelpBotConfig cfg = new com.example.HelpBot.core.HelpBotConfig.Builder()
                    .channelId(TEST_CHANNEL)
                    .domain(TEST_DOMAIN)
                    .fullPrivacyMode(false)
                    .build();
            HelpBot.install(context.getApplicationContext(), cfg, new com.example.HelpBot.core.HelpBotInitCallback() {
                @Override
                public void onInitStart() {
                    log("installAsync: onInitStart");
                }

                @Override
                public void onInitProgress(int progress, @androidx.annotation.NonNull String message) {
                    log("installAsync: onInitProgress " + progress + "% - " + message);
                }

                @Override
                public void onInitSuccess() {
                    log("installAsync: onInitSuccess");
                    installLatch.countDown();
                }

                @Override
                public void onInitFailure(
                        @androidx.annotation.NonNull com.example.HelpBot.core.HelpBotErrorCode errorCode,
                        @androidx.annotation.NonNull String errorMessage) {
                    log("installAsync: onInitFailure " + errorCode + " - " + errorMessage);
                    installLatch.countDown();
                }
            });

            // 等待初始化完成（最多30秒）
            boolean installCompleted = installLatch.await(30, TimeUnit.SECONDS);
            assertTrue("初始化超时", installCompleted);

            // 验证安装状态
            boolean afterInstall = HelpBotContext.verifyInstall();
            assertTrue("SDK安装失败", afterInstall);

            log("[测试2] ✅ SDK初始化成功");

        } catch (Exception e) {
            log("[测试2] ❌ SDK初始化失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试3: 用户登录 (Login)
     */
    @Test
    public void testLogin() throws Exception {
        log("\n[测试3] 开始测试用户登录...");

        // 先确保SDK已安装
        if (!HelpBotContext.verifyInstall()) {
            log("SDK未安装，先执行安装...");
            final CountDownLatch installLatch = new CountDownLatch(1);
            final com.example.HelpBot.core.HelpBotConfig cfg = new com.example.HelpBot.core.HelpBotConfig.Builder()
                    .channelId(TEST_CHANNEL)
                    .domain(TEST_DOMAIN)
                    .fullPrivacyMode(false)
                    .build();
            HelpBot.install(context.getApplicationContext(), cfg, new com.example.HelpBot.core.HelpBotInitCallback() {
                @Override
                public void onInitStart() {
                    log("installAsync: onInitStart");
                }

                @Override
                public void onInitProgress(int progress, @androidx.annotation.NonNull String message) {
                    log("installAsync: onInitProgress " + progress + "% - " + message);
                }

                @Override
                public void onInitSuccess() {
                    log("installAsync: onInitSuccess");
                    installLatch.countDown();
                }

                @Override
                public void onInitFailure(
                        @androidx.annotation.NonNull com.example.HelpBot.core.HelpBotErrorCode errorCode,
                        @androidx.annotation.NonNull String errorMessage) {
                    log("installAsync: onInitFailure " + errorCode + " - " + errorMessage);
                    installLatch.countDown();
                }
            });
            boolean installCompleted = installLatch.await(30, TimeUnit.SECONDS);
            assertTrue("初始化超时", installCompleted);
        }

        // 先创建token
        if (token == null || token.isEmpty()) {
            log("Token为空，先创建Token...");
            testCreateToken();
        }

        final CountDownLatch latch = new CountDownLatch(1);
        loginSuccess = false;
        loginFailureReason = null;

        try {
            Map<String, Object> loginConfig = new HashMap<>();
            loginConfig.put("full_privacy_enabled", false);

            log("执行login: token="
                    + (token != null ? token.substring(0, Math.min(20, token.length())) + "..." : "null"));

            HelpBot.login(token, loginConfig, new com.example.HelpBot.core.HelpBotCallback<Void>() {
                @Override
                public void onSuccess(Void result) {
                    loginSuccess = true;
                    log("登录成功回调触发");
                    latch.countDown();
                }

                @Override
                public void onFailure(@androidx.annotation.NonNull com.example.HelpBot.core.HelpBotErrorCode errorCode,
                        @androidx.annotation.NonNull String errorMessage) {
                    loginSuccess = false;
                    loginFailureReason = errorMessage;
                    log("登录失败回调触发: " + errorCode + " - " + errorMessage);
                    latch.countDown();
                }
            });

            // 等待登录完成（最多15秒）
            boolean completed = latch.await(15, TimeUnit.SECONDS);
            assertTrue("登录超时", completed);
            assertTrue("登录失败: " + loginFailureReason, loginSuccess);

            log("[测试3] ✅ 用户登录成功");

        } catch (Exception e) {
            log("[测试3] ❌ 用户登录失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试4: 更新SDK META
     */
    @Test
    public void testUpdateSDKMeta() throws Exception {
        log("\n[测试4] 开始测试更新SDK META...");

        // 确保SDK已安装
        if (!HelpBotContext.verifyInstall()) {
            testInstall();
        }

        try {
            Map<String, Object> meta = new HashMap<>();
            meta.put("sdk_version", "1.2.11");
            meta.put("os_version", "0.2.6");
            meta.put("test_field", "test_value");
            meta.put("platform", "android");

            log("更新SDK META: " + meta.toString());
            HelpBot.updateSDKMeta(meta);

            // 等待执行完成
            Thread.sleep(1000);

            log("[测试4] ✅ SDK META更新成功");

        } catch (Exception e) {
            log("[测试4] ❌ SDK META更新失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试5: 更新User META
     */
    @Test
    public void testUpdateCustomMeta() throws Exception {
        log("\n[测试5] 开始测试更新User META...");

        // 确保SDK已安装
        if (!HelpBotContext.verifyInstall()) {
            testInstall();
        }

        try {
            Map<String, Object> customMeta = new HashMap<>();
            customMeta.put("userid", "112233");
            customMeta.put("level", "99");
            customMeta.put("serverid", "30012");
            customMeta.put("vip_status", "true");

            log("更新User META: " + customMeta.toString());
            HelpBot.updateCustomMeta(customMeta);

            // 等待执行完成
            Thread.sleep(1000);

            log("[测试5] ✅ User META更新成功");

        } catch (Exception e) {
            log("[测试5] ❌ User META更新失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试6: 打开聊天页面
     */
    @Test
    public void testShowConversation() throws Exception {
        log("\n[测试6] 开始测试打开聊天页面...");

        // 确保SDK已安装
        if (!HelpBotContext.verifyInstall()) {
            testInstall();
        }

        try {
            log("执行showConversation");
            HelpBot.showConversation(context);

            // 等待执行完成
            Thread.sleep(1000);

            log("[测试6] ✅ 聊天页面打开成功");

        } catch (Exception e) {
            log("[测试6] ❌ 聊天页面打开失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试7: 配置相关接口（兼容当前 SDK 实现）
     */
    @Test
    public void testConfigurationApis() throws Exception {
        log("\n[测试7] 开始测试配置接口...");

        try {
            // 确保SDK已安装（部分配置会写入持久化存储）
            if (!HelpBotContext.verifyInstall()) {
                testInstall();
            }

            // SSE 开关（运行时覆盖）
            HelpBot.enableSseNotification(true);
            assertTrue("SSE 开关应为 true", HelpBot.isSseNotificationEnabled());
            HelpBot.enableSseNotification(false);
            assertFalse("SSE 开关应为 false", HelpBot.isSseNotificationEnabled());

            // 通知配置（不做强断言：SDK 可能在不同 ROM 上有差异）
            HelpBot.setNotificationSmallIconResId(android.R.drawable.ic_dialog_info);
            HelpBot.setNotificationChannelId("helpbot_test_channel");

            log("[测试7] ✅ 配置接口测试成功");

        } catch (Exception e) {
            log("[测试7] ❌ 配置接口测试失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试8: 获取 WebSDK 健康快照（替代旧版 getDeviceInfo）
     */
    @Test
    public void testGetWebSdkHealthSnapshot() throws Exception {
        log("\n[测试8] 开始测试获取 WebSDK 健康快照...");

        // 确保SDK已安装
        if (!HelpBotContext.verifyInstall()) {
            testInstall();
        }

        try {
            final Map<String, Object> snapshot = HelpBot.getWebSdkHealthSnapshot();
            assertNotNull("健康快照为 null", snapshot);
            log("WebSDK健康快照: " + snapshot);
            log("[测试8] ✅ WebSDK 健康快照获取成功");

        } catch (Exception e) {
            log("[测试8] ❌ WebSDK 健康快照获取失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试9: 完整工作流程测试（按流程图顺序）
     */
    @Test
    public void testCompleteWorkflow() throws Exception {
        log("\n[测试9] 开始完整工作流程测试...");

        try {
            // 步骤1: SDK初始化
            log("步骤1: SDK初始化");
            testInstall();

            // 步骤2: 创建Token
            log("步骤2: 创建Token");
            testCreateToken();

            // 步骤3: 用户登录
            log("步骤3: 用户登录");
            testLogin();

            // 步骤4: 登录成功后更新SDK META
            log("步骤4: 更新SDK META");
            testUpdateSDKMeta();

            // 步骤5: 登录成功后更新User META
            log("步骤5: 更新User META");
            testUpdateCustomMeta();

            // 步骤6: 打开聊天页面
            log("步骤6: 打开聊天页面");
            testShowConversation();

            log("[测试9] ✅ 完整工作流程测试成功");

        } catch (Exception e) {
            log("[测试9] ❌ 完整工作流程测试失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试10: 事件监听器测试
     */
    @Test
    public void testEventListeners() throws Exception {
        log("\n[测试10] 开始测试事件监听器...");

        // 确保SDK已安装
        if (!HelpBotContext.verifyInstall()) {
            testInstall();
        }

        final CountDownLatch eventLatch = new CountDownLatch(1);
        final boolean[] eventReceived = { false };

        try {
            HelpBot.setHelpBotEventsListener(new HelpBotEventsListener() {
                @Override
                public void onEventOccurred(String eventName, Map<String, Object> data) {
                    eventReceived[0] = true;
                    log("事件触发: " + eventName + ", 数据: " + (data != null ? data.toString() : "null"));
                    eventLatch.countDown();
                }

                @Override
                public void onUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason) {
                    log("认证失败: " + reason);
                }
            });

            log("事件监听器设置完成");

            // 等待一段时间看是否有事件触发
            boolean completed = eventLatch.await(5, TimeUnit.SECONDS);
            if (completed) {
                log("收到事件");
            } else {
                log("等待事件超时（这是正常的，如果没有事件触发）");
            }

            log("[测试10] ✅ 事件监听器测试完成");

        } catch (Exception e) {
            log("[测试10] ❌ 事件监听器测试失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试11: Issue标签管理
     */
    @Test
    public void testIssueTags() throws Exception {
        log("\n[测试11] 开始测试Issue标签管理...");

        // 确保SDK已安装
        if (!HelpBotContext.verifyInstall()) {
            testInstall();
        }

        try {
            // 添加标签
            ArrayList<String> tags = new ArrayList<>();
            tags.add("vip");
            tags.add("test");
            tags.add("automated");

            log("添加标签: " + tags.toString());
            HelpBot.addIssueTags(tags);
            Thread.sleep(1000);

            // 移除标签
            ArrayList<String> removeTags = new ArrayList<>();
            removeTags.add("test");

            log("移除标签: " + removeTags.toString());
            HelpBot.removeIssueTags(removeTags);
            Thread.sleep(1000);

            log("[测试11] ✅ Issue标签管理测试成功");

        } catch (Exception e) {
            log("[测试11] ❌ Issue标签管理测试失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 测试12: 会话/窗口相关接口（兼容当前 SDK 实现）
     */
    @Test
    public void testSessionAndUiControls() throws Exception {
        log("\n[测试12] 开始测试会话/窗口相关接口...");

        // 确保SDK已安装
        if (!HelpBotContext.verifyInstall()) {
            testInstall();
        }

        try {
            // hideConversation：即使没有 Activity 也应安全返回（不崩溃）
            assertTrue("hideConversation 应返回 success", HelpBot.hideConversation().isSuccess());

            // closeSession：应安全清理 WebView 会话（不做强断言，主要验证不崩溃）
            assertTrue("closeSession 应返回 success", HelpBot.closeSession().isSuccess());

            // 健康快照：可用于诊断/埋点
            assertNotNull("健康快照不应为 null", HelpBot.getWebSdkHealthSnapshot());

            log("[测试12] ✅ 会话/窗口相关接口测试成功");

        } catch (Exception e) {
            log("[测试12] ❌ 会话/窗口相关接口测试失败: " + e.getMessage());
            throw e;
        }
    }

    /**
     * 记录日志到文件和控制台
     */
    private void log(String message) {
        String logMessage = "[" + System.currentTimeMillis() + "] " + message;
        Log.d(TAG, logMessage);

        // 写入日志文件
        try {
            File logFile = new File(LOG_FILE_PATH);
            FileWriter writer = new FileWriter(logFile, true);
            writer.write(logMessage + "\n");
            writer.close();
        } catch (IOException e) {
            Log.e(TAG, "写入日志文件失败", e);
        }
    }
}
