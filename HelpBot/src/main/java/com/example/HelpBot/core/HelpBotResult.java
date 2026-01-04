package com.example.HelpBot.core;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * HelpBot SDK 操作结果封装类
 * 
 * 用于同步方法的返回值，包含成功/失败状态和数据
 * 
 * @param <T> 成功时返回的数据类型
 */
public class HelpBotResult<T> {

    private final boolean success;
    private final T data;
    private final HelpBotErrorCode errorCode;
    private final String errorMessage;

    /**
     * 私有构造函数
     */
    private HelpBotResult(final boolean success, @Nullable final T data,
            @Nullable final HelpBotErrorCode errorCode,
            @Nullable final String errorMessage) {
        this.success = success;
        this.data = data;
        this.errorCode = errorCode;
        this.errorMessage = errorMessage;
    }

    /**
     * 创建成功结果
     */
    public static <T> HelpBotResult<T> success(@Nullable final T data) {
        return new HelpBotResult<>(true, data, null, null);
    }

    /**
     * 创建成功结果（无数据）
     */
    public static <T> HelpBotResult<T> success() {
        return new HelpBotResult<>(true, null, null, null);
    }

    /**
     * 创建失败结果
     */
    public static <T> HelpBotResult<T> failure(@NonNull final HelpBotErrorCode errorCode,
            @NonNull final String errorMessage) {
        return new HelpBotResult<>(false, null, errorCode, errorMessage);
    }

    /**
     * 创建失败结果（使用错误码默认消息）
     */
    public static <T> HelpBotResult<T> failure(@NonNull final HelpBotErrorCode errorCode) {
        return new HelpBotResult<>(false, null, errorCode, errorCode.getMessage());
    }

    /**
     * 是否成功
     */
    public boolean isSuccess() {
        return success;
    }

    /**
     * 是否失败
     */
    public boolean isFailure() {
        return !success;
    }

    /**
     * 获取数据（仅成功时有效）
     */
    @Nullable
    public T getData() {
        return data;
    }

    /**
     * 获取错误码（仅失败时有效）
     */
    @Nullable
    public HelpBotErrorCode getErrorCode() {
        return errorCode;
    }

    /**
     * 获取错误消息（仅失败时有效）
     */
    @Nullable
    public String getErrorMessage() {
        return errorMessage;
    }

    @Override
    public String toString() {
        if (success) {
            return "HelpBotResult{success=true, data=" + data + '}';
        } else {
            return "HelpBotResult{success=false, errorCode=" + errorCode +
                    ", errorMessage='" + errorMessage + "'}";
        }
    }
}
