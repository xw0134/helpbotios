package com.example.HelpBot.storage;

import android.content.Context;
import android.content.SharedPreferences;

import com.example.HelpBot.log.HBlogger;

import androidx.annotation.NonNull;

/**
 * SharedPreferences 存储实现类。
 * 提供线程安全的持久化存储，支持各种基础数据类型。
 */
public class SharedPreferencesStore implements ISharedPreferencesStore {
    private static final String TAG = "SharedPrefStore";
    private final SharedPreferences preferences;
    // 同步锁，确保线程安全
    private final Object lock = new Object();

    /**
     * 构造函数。
     *
     * @param context 上下文
     * @param name    SharedPreferences 文件名
     * @param mode    开启模式
     */
    public SharedPreferencesStore(@NonNull final Context context, @NonNull final String name, final int mode) {
        super();
        this.preferences = context.getSharedPreferences(name, mode);
    }

    @Override
    public String getString(final String key) {
        synchronized (lock) {
            return this.preferences.getString(key, "");
        }
    }

    @Override
    public void putString(final String key, final String value) {
        synchronized (lock) {
            final SharedPreferences.Editor editor = this.preferences.edit();
            editor.putString(key, value);
            // 使用 apply() 替代 commit()，避免主线程阻塞（ANR 风险）
            // apply() 是异步的，不会阻塞调用线程，适合 SDK 场景
            editor.apply();
        }
    }

    @Override
    public void remove(final String key) {
        synchronized (lock) {
            final SharedPreferences.Editor editor = this.preferences.edit();
            editor.remove(key);
            // 使用 apply() 替代 commit()，避免主线程阻塞
            editor.apply();
        }
    }

    @Override
    public void putLong(final String key, final long value) {
        synchronized (lock) {
            final SharedPreferences.Editor editor = this.preferences.edit();
            editor.putLong(key, value);
            // 使用 apply() 替代 commit()，避免主线程阻塞
            editor.apply();
        }
    }

    @Override
    public long getLong(final String key) {
        synchronized (lock) {
            return this.preferences.getLong(key, 0L);
        }
    }

    @Override
    public void putInt(final String key, final int value) {
        synchronized (lock) {
            final SharedPreferences.Editor editor = this.preferences.edit();
            editor.putInt(key, value);
            // 使用 apply() 替代 commit()，避免主线程阻塞
            editor.apply();
        }
    }

    @Override
    public int getInt(final String key) {
        synchronized (lock) {
            return this.preferences.getInt(key, 0);
        }
    }

    @Override
    public void putBoolean(final String key, final boolean value) {
        synchronized (lock) {
            final SharedPreferences.Editor editor = this.preferences.edit();
            editor.putBoolean(key, value);
            // 使用 apply() 替代 commit()，避免主线程阻塞
            editor.apply();
        }
    }

    @Override
    public boolean getBoolean(final String key) {
        synchronized (lock) {
            return this.preferences.getBoolean(key, false);
        }
    }

    @Override
    public void clear() {
        synchronized (lock) {
            this.preferences.edit().clear().apply();
        }
    }
}
