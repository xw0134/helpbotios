package com.example.HelpBot.core;

import androidx.annotation.NonNull;

/**
 * HelpBot SDK 初始化回调接口
 * 
 * 用于监听 SDK 初始化过程的各个阶段
 */
public interface HelpBotInitCallback {

    /**
     * 初始化开始
     */
    void onInitStart();

    /**
     * 初始化进度更新
     * 
     * @param progress 进度百分比 (0-100)
     * @param message  当前步骤描述
     */
    void onInitProgress(int progress, @NonNull String message);

    /**
     * 初始化成功
     */
    void onInitSuccess();

    /**
     * 初始化失败
     * 
     * @param errorCode    错误码
     * @param errorMessage 错误描述
     */
    void onInitFailure(@NonNull HelpBotErrorCode errorCode, @NonNull String errorMessage);
}
