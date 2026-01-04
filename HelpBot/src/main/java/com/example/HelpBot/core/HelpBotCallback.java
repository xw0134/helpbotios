package com.example.HelpBot.core;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * HelpBot SDK 统一回调接口
 * 
 * 用于所有异步操作的结果回调
 * 
 * @param <T> 成功时返回的数据类型
 */
public interface HelpBotCallback<T> {

    /**
     * 操作成功回调
     * 
     * @param result 操作结果数据，可能为 null
     */
    void onSuccess(@Nullable T result);

    /**
     * 操作失败回调
     * 
     * @param errorCode    错误码，参见 {@link HelpBotErrorCode}
     * @param errorMessage 错误描述信息
     */
    void onFailure(@NonNull HelpBotErrorCode errorCode, @NonNull String errorMessage);
}
