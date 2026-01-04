package com.example.HelpBot.storage;

/**
 * 共享参数存储接口。
 * 用于定义简单的键值对存储操作。
 */
public interface ISharedPreferencesStore {
    /**
     * 获取字符串值。
     *
     * @param key 键名
     * @return 对应的字符串值
     */
    String getString(final String key);

    /**
     * 存储字符串值。
     *
     * @param key   键名
     * @param value 要存储的值
     */
    void putString(final String key, final String value);

    /**
     * 移除指定的键值对。
     *
     * @param key 键名
     */
    void remove(final String key);

    /**
     * 存储长整型值。
     *
     * @param key   键名
     * @param value 要存储的值
     */
    void putLong(final String key, final long value);

    /**
     * 获取长整型值。
     *
     * @param key 键名
     * @return 对应的长整型值
     */
    long getLong(final String key);

    /**
     * 存储整型值。
     *
     * @param key   键名
     * @param value 要存储的值
     */
    void putInt(final String key, final int value);

    /**
     * 获取整型值。
     *
     * @param key 键名
     * @return 对应的整型值
     */
    int getInt(final String key);

    /**
     * 存储布尔值。
     *
     * @param key   键名
     * @param value 要存储的值
     */
    void putBoolean(final String key, final boolean value);

    /**
     * 获取布尔值。
     *
     * @param key 键名
     * @return 对应的布尔值
     */
    boolean getBoolean(final String key);

    /**
     * 清空所有数据。
     */
    void clear();
}
