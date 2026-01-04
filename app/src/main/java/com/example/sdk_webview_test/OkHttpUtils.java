package com.example.sdk_webview_test;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;


import okhttp3.*;
import java.io.IOException;
import java.util.concurrent.TimeUnit;

public class OkHttpUtils {
    
    // 回调接口
    public interface PostCallback {
        void onSuccess(String response);
        void onFailure(Exception e);
    }

    /**
     * 复用 OkHttpClient。
     */
    private static final OkHttpClient CLIENT = new OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .callTimeout(45, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)
            .build();

    /**
     * 异步 POST 请求
     * @param url 请求地址
     * @param jsonBody JSON 字符串
     * @param callback 回调接口
     */
    public static void postRequest(@Nullable final String url,
            @Nullable final String jsonBody,
            @Nullable final PostCallback callback) {
        try {
            if (url == null || url.trim().isEmpty()) {
                notifyFailure(callback, new IllegalArgumentException("url 不能为空"));
                return;
            }
            if (jsonBody == null) {
                notifyFailure(callback, new IllegalArgumentException("jsonBody 不能为空"));
                return;
            }

            final MediaType JSON = MediaType.parse("application/json; charset=utf-8");
            final RequestBody body = RequestBody.create(jsonBody, JSON);

            final Request request = new Request.Builder()
                    .url(url.trim())
                    .post(body)
                    .addHeader("Content-Type", "application/json")
                    .build();

            CLIENT.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                notifyFailure(callback, e);
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                try {
                    if (!response.isSuccessful()) {
                        notifyFailure(callback, new IOException("Unexpected code " + response));
                        return;
                    }
                    final ResponseBody responseBody = response.body();
                    final String responseString = (responseBody == null) ? "" : responseBody.string();
                    notifySuccess(callback, responseString);
                } catch (final Exception e) {
                    notifyFailure(callback, new IOException("read response failed: " + e.getMessage(), e));
                } finally {
                    try {
                        response.close();
                    } catch (final Exception ignored) {
                    }
                }
            }
            });
        } catch (final Exception e) {
            notifyFailure(callback, e);
        }
    }

    private static void notifySuccess(@Nullable final PostCallback callback, @NonNull final String response) {
        try {
            if (callback != null) {
                callback.onSuccess(response);
            }
        } catch (final Exception ignored) {
        }
    }

    private static void notifyFailure(@Nullable final PostCallback callback, @NonNull final Exception e) {
        try {
            if (callback != null) {
                callback.onFailure(e);
            }
        } catch (final Exception ignored) {
        }
    }
}