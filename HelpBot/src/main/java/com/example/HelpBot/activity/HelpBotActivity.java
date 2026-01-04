package com.example.HelpBot.activity;

import com.example.HelpBot.BuildConfig;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.log.HelpBotLogger;
import com.example.HelpBot.web.HelpBotWebViewSession;

import android.net.Uri;
import android.os.Bundle;
import android.content.Intent;
import android.view.MenuItem;
import android.webkit.ValueCallback;
import android.webkit.WebView;
import android.widget.FrameLayout;
import android.view.View;

import androidx.activity.OnBackPressedCallback;
import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;

import com.example.HelpBot.R;

import com.example.HelpBot.HelpBot;

public class HelpBotActivity extends AppCompatActivity {
    WebView webView; //  仅供 SDK 内部访问(HelpBot.getActiveWebView)
    private FrameLayout webViewContainer;

    private static final String TAG = "HelpBotActivity";

    // 文件选择处理
    private ValueCallback<Uri[]> filePathCallback;
    private final ActivityResultLauncher<android.content.Intent> fileChooserLauncher = registerForActivityResult(
            new ActivityResultContracts.StartActivityForResult(), result -> {
                if (filePathCallback == null)
                    return;
                Uri[] results = null;
                if (result.getResultCode() == RESULT_OK && result.getData() != null) {
                    android.content.Intent data = result.getData();
                    if (data.getClipData() != null) {
                        int count = data.getClipData().getItemCount();
                        results = new Uri[count];
                        for (int i = 0; i < count; i++) {
                            results[i] = data.getClipData().getItemAt(i).getUri();
                        }
                    } else if (data.getData() != null) {
                        results = new Uri[] { data.getData() };
                    }
                }
                filePathCallback.onReceiveValue(results);
                filePathCallback = null;
            });

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);
        setContentView(R.layout.helpbot_activity_main);
        setupResponsiveInsets();

        // 初始化 Toolbar
        final Toolbar toolbar = findViewById(R.id.toolbar);
        final boolean showTitleBar = shouldShowTitleBar();
        if (!showTitleBar) {
            try {
                if (toolbar != null) {
                    toolbar.setVisibility(View.GONE);
                }
            } catch (final Exception ignored) {
            }
        } else {
            try {
                if (toolbar != null) {
                    setSupportActionBar(toolbar);
                }
            } catch (final Exception ignored) {
            }
        }

        // 设置导航返回按钮
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setDisplayShowHomeEnabled(true);
        }
        // - 优先 WebView 内部回退
        // - 回退失败时再关闭 SDK
        try {
            getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
                @Override
                public void handleOnBackPressed() {
                    try {
                        if (webView != null && webView.canGoBack()) {
                            webView.goBack();
                            return;
                        }
                    } catch (final Exception ignored) {
                    }
                    try {
                        HelpBot.hideConversation();
                    } catch (final Exception ignored) {
                        finish();
                    }
                }
            });
        } catch (final Exception ignored) {
        }

        // 注册当前 Activity 到 HelpBot
        HelpBot.setCurrentActivity(this);

        // 初始化日志
        // SDK 作为依赖库：不得强行覆盖宿主日志系统
        // - 若宿主未初始化 Logger，则按 debugMode 初始化（release 默认关闭 debug 日志）
        try {
            // 禁止日志输出，因此仅在 debug 变体允许初始化默认 logger
            if (BuildConfig.DEBUG) {
                HBlogger.initLoggerIfAbsent(new HelpBotLogger(BuildConfig.DEBUG));
            }
        } catch (final Exception e) {
            // 避免日志初始化问题影响宿主稳定性
        }

        // 设置 WebView
        webViewContainer = findViewById(R.id.hbWebViewContainer);

        // Activity 显示 WebView
        HelpBotWebViewSession.getInstance().attachToActivity(this, webViewContainer,
                (callback, acceptType, allowMultiple) -> {
                    try {
                        if (HelpBotActivity.this.filePathCallback != null) {
                            HelpBotActivity.this.filePathCallback.onReceiveValue(null);
                        }
                        HelpBotActivity.this.filePathCallback = callback;

                        final android.content.Intent intent = new android.content.Intent(
                                android.content.Intent.ACTION_OPEN_DOCUMENT);
                        intent.addCategory(android.content.Intent.CATEGORY_OPENABLE);
                        intent.setType((acceptType == null || acceptType.trim().isEmpty()) ? "*/*" : acceptType);
                        intent.putExtra(android.content.Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple);

                        fileChooserLauncher.launch(android.content.Intent.createChooser(intent, "选择文件"));
                    } catch (final Exception e) {
                        HBlogger.e(TAG, "打开文件选择器异常", e);
                        try {
                            callback.onReceiveValue(null);
                        } catch (final Exception ignored) {
                        }
                        HelpBotActivity.this.filePathCallback = null;
                    }
                });

        // 绑定当前可用 WebView
        webView = HelpBotWebViewSession.getInstance().getWebView();
    }

    /**
     * - 默认显示
     * - 若宿主希望全屏/自定义标题栏，可通过 HelpBotConfig.customConfig 传入 showTitleBar=false
     */
    private boolean shouldShowTitleBar() {
        try {
            final com.example.HelpBot.core.HelpBotConfig cfg = HelpBot.getConfig();
            if (cfg == null) {
                return true;
            }
            final java.util.Map<String, Object> map = cfg.getCustomConfig();
            if (map == null) {
                return true;
            }
            final Object v = map.get("showTitleBar");
            if (v instanceof Boolean) {
                return (Boolean) v;
            }
            if (v instanceof String) {
                final String s = ((String) v).trim();
                if (s.isEmpty()) {
                    return true;
                }
                return !"false".equalsIgnoreCase(s) && !"0".equalsIgnoreCase(s) && !"no".equalsIgnoreCase(s);
            }
            return true;
        } catch (final Exception ignored) {
            return true;
        }
    }

    /**
     * 大屏/分屏/横屏/全面屏沉浸式适配：
     * - Toolbar 全宽显示，顶部加上状态栏/刘海 inset，避免内容被遮挡
     * - 内容区（WebView 容器）居中 + maxWidth，左右加上 cutout/systemBars inset
     * - 底部使用 max(systemBars, ime)，避免键盘弹出时 WebView 被遮挡
     *
     * 
     */
    private void setupResponsiveInsets() {
        try {
            final View root = findViewById(R.id.Main);
            final Toolbar toolbar = findViewById(R.id.toolbar);
            final View wrapper = findViewById(R.id.hbContentWrapper);
            if (root == null || toolbar == null || wrapper == null) {
                return;
            }

            final int toolbarPaddingLeft = toolbar.getPaddingLeft();
            final int toolbarPaddingTop = toolbar.getPaddingTop();
            final int toolbarPaddingRight = toolbar.getPaddingRight();
            final int toolbarPaddingBottom = toolbar.getPaddingBottom();
            final int baseToolbarHeightPx = getResources().getDimensionPixelSize(R.dimen.helpbot_toolbar_height);

            final int wrapperPaddingLeft = wrapper.getPaddingLeft();
            final int wrapperPaddingTop = wrapper.getPaddingTop();
            final int wrapperPaddingRight = wrapper.getPaddingRight();
            final int wrapperPaddingBottom = wrapper.getPaddingBottom();

            ViewCompat.setOnApplyWindowInsetsListener(root, (v, insets) -> {
                try {
                    // systemBars + displayCutout：兼容刘海/挖孔/侧边系统栏（含大屏导航条在侧边的情况）
                    final Insets bars = insets.getInsets(
                            WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
                    // 键盘
                    final Insets ime = insets.getInsets(WindowInsetsCompat.Type.ime());
                    final int bottom = Math.max(bars.bottom, ime.bottom);

                    // Toolbar 高度必须包含状态栏高度，否则在沉浸式下导航按钮可能被裁剪/遮挡
                    try {
                        final int targetHeight = Math.max(baseToolbarHeightPx + bars.top, baseToolbarHeightPx);
                        if (toolbar.getLayoutParams() != null && toolbar.getLayoutParams().height != targetHeight) {
                            toolbar.getLayoutParams().height = targetHeight;
                            toolbar.requestLayout();
                        }
                    } catch (final Exception e) {
                        HBlogger.w(TAG, "调整 Toolbar 高度失败", e);
                    }

                    // 仅增加顶部/左右 inset，保证全宽背景一致但内容不被遮挡
                    toolbar.setPadding(
                            toolbarPaddingLeft + bars.left,
                            toolbarPaddingTop + bars.top,
                            toolbarPaddingRight + bars.right,
                            toolbarPaddingBottom);

                    // 左右 inset 保障侧边栏/刘海安全区；底部跟随 IME/systemBars
                    wrapper.setPadding(
                            wrapperPaddingLeft + bars.left,
                            wrapperPaddingTop,
                            wrapperPaddingRight + bars.right,
                            wrapperPaddingBottom + bottom);
                } catch (final Exception e) {
                    HBlogger.w(TAG, "应用 WindowInsets 失败", e);
                }
                return insets;
            });

            // 确保首次进入即可正确布局（部分机型/主题下需要显式触发）
            try {
                ViewCompat.requestApplyInsets(root);
            } catch (final Exception ignored) {
            }
        } catch (final Exception e) {
            HBlogger.w(TAG, "setupResponsiveInsets 异常", e);
        }
    }

    @Override
    public void onMultiWindowModeChanged(final boolean isInMultiWindowMode) {
        super.onMultiWindowModeChanged(isInMultiWindowMode);
        try {
            HBlogger.d(TAG, "onMultiWindowModeChanged: " + isInMultiWindowMode);
            final View root = findViewById(R.id.Main);
            if (root != null) {
                ViewCompat.requestApplyInsets(root);
            }
        } catch (final Exception e) {
            HBlogger.w(TAG, "onMultiWindowModeChanged 异常", e);
        }
    }

    @Override
    protected void onNewIntent(final Intent intent) {
        super.onNewIntent(intent);
        try {
            // launchMode=singleTask 场景：二次唤起会走 onNewIntent，确保触发 open
            HelpBotWebViewSession.getInstance().openWhenReady();
        } catch (final Exception e) {
            HBlogger.e(TAG, "onNewIntent openWhenReady 异常", e);
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        HBlogger.d(TAG, "HelpBot 界面已暂停");
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        HBlogger.d(TAG, "HelpBot 界面已销毁");
        // 清除当前 Activity 引用
        HelpBot.clearCurrentActivity();
        // 解绑 WebView
        try {
            HelpBotWebViewSession.getInstance().detachFromActivity();
        } catch (final Exception e) {
            HBlogger.e(TAG, "detachFromActivity 异常", e);
        }
    }

    // 返回按钮的具体实现 onOptionsItemSelected
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == android.R.id.home) {
            // WebView 回退，否则隐藏会话
            try {
                if (webView != null && webView.canGoBack()) {
                    webView.goBack();
                    return true;
                }
            } catch (final Exception ignored) {
            }
            try {
                HelpBot.hideConversation();
            } catch (final Exception ignored) {
                finish();
            }
            return true;
        }
        return super.onOptionsItemSelected(item);
    }
}
