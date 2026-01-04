package com.example.HelpBot.storage;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Base64;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.example.HelpBot.log.HBlogger;

import java.nio.charset.StandardCharsets;
import java.math.BigInteger;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.SecureRandom;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.cert.Certificate;
import java.util.Calendar;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import javax.security.auth.x500.X500Principal;

/**
 * 加密存储管理器。
 * 用于安全存储敏感数据（如 JWT Token、用户身份信息等）。
 *
 * 安全特性：
 * 1. 使用 AES-256-GCM 加密算法。
 * 2. 每次加密使用随机 IV。
 * 3. 密钥存储在 Android Keystore (API 23+) 或本地加密存储。
 * 4. 兼容 Android 5.0+ (API 21+)。
 *
 * 使用方法：
 * EncryptedStorage storage = EncryptedStorage.getInstance(context);
 * storage.putEncryptedString("jwt_token", token);
 * String token = storage.getEncryptedString("jwt_token");
 */
public class EncryptedStorage {
    private static final String TAG = "EncryptedStorage";
    private static final String PREFS_NAME = "helpbot_encrypted_store";
    private static final String KEY_ALIAS = "helpbot_master_key";
    private static final String KEY_ALIAS_RSA = "helpbot_master_key_rsa";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int GCM_TAG_LENGTH = 128;
    private static final int GCM_IV_LENGTH = 12;
    private static final String PREF_KEY_WRAPPED_AES = "master_key_wrapped";
    private static final String PREF_KEY_LEGACY_PLAIN_AES = "master_key_encoded";

    private static volatile EncryptedStorage instance;
    private final SharedPreferences preferences;
    private final SecretKey masterKey;
    private final Object lock = new Object();

    /**
     * 获取 EncryptedStorage 单例实例。
     *
     * @param context Application Context
     * @return EncryptedStorage 实例
     */
    public static EncryptedStorage getInstance(@NonNull final Context context) {
        if (instance == null) {
            synchronized (EncryptedStorage.class) {
                if (instance == null) {
                    instance = new EncryptedStorage(context.getApplicationContext());
                }
            }
        }
        return instance;
    }

    /**
     * 私有构造函数。
     *
     * @param context Application Context
     */
    private EncryptedStorage(final Context context) {
        this.preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        this.masterKey = getOrCreateMasterKey(context);

        if (this.masterKey == null) {
            HBlogger.e(TAG, "无法创建主密钥，加密存储不可用");
        } else {
            HBlogger.d(TAG, "加密存储初始化成功");
        }
    }

    /**
     * 获取或创建主密钥。
     * 优先使用 Android Keystore (API 23+)，否则使用本地加密存储。
     */
    private SecretKey getOrCreateMasterKey(final Context context) {
        try {
            // API 23+ 使用 Android Keystore
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                return getOrCreateKeystoreKey();
            } else {
                // API 21-22 使用本地加密存储
                return getOrCreateLocalKey(context);
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "创建主密钥失败", e);
            return null;
        }
    }

    /**
     * 使用 Android Keystore 创建密钥 (API 23+)。
     */
    @androidx.annotation.RequiresApi(api = Build.VERSION_CODES.M)
    private SecretKey getOrCreateKeystoreKey() {
        try {
            final java.security.KeyStore keyStore = java.security.KeyStore.getInstance("AndroidKeyStore");
            keyStore.load(null);

            // 检查密钥是否已存在
            if (keyStore.containsAlias(KEY_ALIAS)) {
                return (SecretKey) keyStore.getKey(KEY_ALIAS, null);
            }

            // 创建新密钥
            final javax.crypto.KeyGenerator keyGenerator = javax.crypto.KeyGenerator.getInstance(
                    android.security.keystore.KeyProperties.KEY_ALGORITHM_AES,
                    "AndroidKeyStore");

            final android.security.keystore.KeyGenParameterSpec keyGenParameterSpec = new android.security.keystore.KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    android.security.keystore.KeyProperties.PURPOSE_ENCRYPT |
                            android.security.keystore.KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build();

            keyGenerator.init(keyGenParameterSpec);
            return keyGenerator.generateKey();
        } catch (final Exception e) {
            HBlogger.e(TAG, "Keystore 密钥创建失败", e);
            return null;
        }
    }

    /**
     * 使用本地加密存储创建密钥 (API 21-22 兼容方案)。
     */
    private SecretKey getOrCreateLocalKey(final Context context) {
        try {
            // API 21-22 企业级安全基线：
            // 1. 禁止把 AES 主密钥明文存到 SharedPreferences
            // 2. 使用 AndroidKeyStore 的 RSA KeyPair 对 AES key 做包裹（wrap），仅把密钥密文存到
            // SharedPreferences

            // 1) 优先读已包裹的 AES key
            final String wrapped = preferences.getString(PREF_KEY_WRAPPED_AES, null);
            if (wrapped != null && !wrapped.trim().isEmpty()) {
                final byte[] wrappedBytes = Base64.decode(wrapped, Base64.NO_WRAP);
                final byte[] aesBytes = unwrapAesKeyWithRsa(context, wrappedBytes);
                if (aesBytes != null && aesBytes.length >= 16) {
                    return new SecretKeySpec(aesBytes, "AES");
                }
            }

            // 2) 兼容历史版本：也曾将 AES key 明文存储在 SharedPreferences (高危)
            // 做一次迁移：读出明文 key -> 立即用 RSA 包裹 -> 删除旧字段
            final String legacyPlain = preferences.getString(PREF_KEY_LEGACY_PLAIN_AES, null);
            if (legacyPlain != null && !legacyPlain.trim().isEmpty()) {
                final byte[] decodedKey = Base64.decode(legacyPlain, Base64.NO_WRAP);
                final byte[] newWrapped = wrapAesKeyWithRsa(context, decodedKey);
                if (newWrapped != null) {
                    preferences.edit()
                            .putString(PREF_KEY_WRAPPED_AES, Base64.encodeToString(newWrapped, Base64.NO_WRAP))
                            .remove(PREF_KEY_LEGACY_PLAIN_AES)
                            .apply();
                    HBlogger.w(TAG, "已将历史明文 AES key 迁移为 Keystore(RSA) 包裹存储");
                }
                return new SecretKeySpec(decodedKey, "AES");
            }

            // 3) 生成新 AES key，并用 RSA 包裹后存储
            final KeyGenerator keyGenerator = KeyGenerator.getInstance("AES");
            keyGenerator.init(256, new SecureRandom());
            final SecretKey secretKey = keyGenerator.generateKey();
            final byte[] wrappedNew = wrapAesKeyWithRsa(context, secretKey.getEncoded());
            if (wrappedNew != null) {
                preferences.edit()
                        .putString(PREF_KEY_WRAPPED_AES, Base64.encodeToString(wrappedNew, Base64.NO_WRAP))
                        .apply();
            } else {
                // 极端兜底：如果 Keystore/RSA 失败，拒绝创建“明文主密钥”，避免虚假安全
                HBlogger.e(TAG, "API 21-22 Keystore(RSA) 包裹失败，拒绝回退到明文主密钥存储");
                return null;
            }

            HBlogger.w(TAG, "API 21-22 使用 Keystore(RSA) 包裹 AES key（仍建议优先使用 Android 6.0+ Keystore AES）");
            return secretKey;
        } catch (final Exception e) {
            HBlogger.e(TAG, "本地密钥创建失败", e);
            return null;
        }
    }

    /**
     * 获取或创建用于包裹 AES key 的 RSA KeyPair（API 21-22）。
     */
    @Nullable
    private static KeyPair getOrCreateRsaKeyPair(@NonNull final Context context) {
        try {
            final java.security.KeyStore ks = java.security.KeyStore.getInstance("AndroidKeyStore");
            ks.load(null);
            if (ks.containsAlias(KEY_ALIAS_RSA)) {
                final PrivateKey privateKey = (PrivateKey) ks.getKey(KEY_ALIAS_RSA, null);
                final Certificate cert = ks.getCertificate(KEY_ALIAS_RSA);
                final PublicKey publicKey = (cert == null) ? null : cert.getPublicKey();
                if (privateKey != null && publicKey != null) {
                    return new KeyPair(publicKey, privateKey);
                }
            }

            // 创建新的 RSA KeyPair
            final Calendar start = Calendar.getInstance();
            final Calendar end = Calendar.getInstance();
            end.add(Calendar.YEAR, 30);

            final android.security.KeyPairGeneratorSpec spec = new android.security.KeyPairGeneratorSpec.Builder(
                    context)
                    .setAlias(KEY_ALIAS_RSA)
                    .setSubject(new X500Principal("CN=" + KEY_ALIAS_RSA))
                    .setSerialNumber(BigInteger.ONE)
                    .setStartDate(start.getTime())
                    .setEndDate(end.getTime())
                    .setKeySize(2048)
                    .build();

            final KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA", "AndroidKeyStore");
            kpg.initialize(spec);
            return kpg.generateKeyPair();
        } catch (final Exception e) {
            HBlogger.e(TAG, "getOrCreateRsaKeyPair 失败", e);
            return null;
        }
    }

    @Nullable
    private static byte[] wrapAesKeyWithRsa(@NonNull final Context context, @NonNull final byte[] aesKeyBytes) {
        try {
            final KeyPair kp = getOrCreateRsaKeyPair(context);
            if (kp == null || kp.getPublic() == null) {
                return null;
            }
            final Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
            cipher.init(Cipher.ENCRYPT_MODE, kp.getPublic());
            return cipher.doFinal(aesKeyBytes);
        } catch (final Exception e) {
            HBlogger.e(TAG, "wrapAesKeyWithRsa 失败", e);
            return null;
        }
    }

    @Nullable
    private static byte[] unwrapAesKeyWithRsa(@NonNull final Context context, @NonNull final byte[] wrappedBytes) {
        try {
            final KeyPair kp = getOrCreateRsaKeyPair(context);
            if (kp == null || kp.getPrivate() == null) {
                return null;
            }
            final Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
            cipher.init(Cipher.DECRYPT_MODE, kp.getPrivate());
            return cipher.doFinal(wrappedBytes);
        } catch (final Exception e) {
            HBlogger.e(TAG, "unwrapAesKeyWithRsa 失败", e);
            return null;
        }
    }

    /**
     * 加密并存储字符串。
     *
     * @param key   存储键
     * @param value 明文值
     * @return 是否成功
     */
    public boolean putEncryptedString(@NonNull final String key, @Nullable final String value) {
        if (masterKey == null) {
            HBlogger.e(TAG, "主密钥不可用，无法加密存储");
            return false;
        }

        synchronized (lock) {
            try {
                if (value == null) {
                    remove(key);
                    return true;
                }

                final Cipher cipher = Cipher.getInstance(TRANSFORMATION);

                // 判断是否使用 Keystore 密钥
                final boolean isKeystoreKey = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                        && masterKey.getClass().getName().contains("android.security.keystore");

                byte[] iv;
                byte[] encrypted;

                if (isKeystoreKey) {
                    // Keystore 密钥：不提供 IV，让 Cipher 自己生成
                    cipher.init(Cipher.ENCRYPT_MODE, masterKey);
                    encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
                    iv = cipher.getIV(); // 获取 Cipher 生成的 IV
                } else {
                    // 本地密钥：手动生成 IV
                    iv = new byte[GCM_IV_LENGTH];
                    new SecureRandom().nextBytes(iv);
                    final GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
                    cipher.init(Cipher.ENCRYPT_MODE, masterKey, spec);
                    encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
                }

                // 组合 IV + 密文
                final byte[] combined = new byte[iv.length + encrypted.length];
                System.arraycopy(iv, 0, combined, 0, iv.length);
                System.arraycopy(encrypted, 0, combined, iv.length, encrypted.length);

                // Base64 编码后存储
                final String encoded = Base64.encodeToString(combined, Base64.NO_WRAP);
                preferences.edit().putString(key, encoded).apply();

                HBlogger.d(TAG, "加密存储成功: " + key);
                return true;
            } catch (final Exception e) {
                HBlogger.e(TAG, "加密存储失败: " + key, e);
                return false;
            }
        }
    }

    /**
     * 读取并解密字符串。
     *
     * @param key 存储键
     * @return 明文值，失败返回 null
     */
    @Nullable
    public String getEncryptedString(@NonNull final String key) {
        if (masterKey == null) {
            HBlogger.e(TAG, "主密钥不可用，无法解密读取");
            return null;
        }

        synchronized (lock) {
            try {
                final String encoded = preferences.getString(key, null);
                if (encoded == null) {
                    return null;
                }

                // Base64 解码
                final byte[] combined = Base64.decode(encoded, Base64.NO_WRAP);
                if (combined.length < GCM_IV_LENGTH) {
                    HBlogger.e(TAG, "加密数据格式错误: " + key);
                    return null;
                }

                // 分离 IV 和密文
                final byte[] iv = new byte[GCM_IV_LENGTH];
                final byte[] encrypted = new byte[combined.length - GCM_IV_LENGTH];
                System.arraycopy(combined, 0, iv, 0, GCM_IV_LENGTH);
                System.arraycopy(combined, GCM_IV_LENGTH, encrypted, 0, encrypted.length);

                // 解密
                final Cipher cipher = Cipher.getInstance(TRANSFORMATION);
                final GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
                cipher.init(Cipher.DECRYPT_MODE, masterKey, spec);
                final byte[] decrypted = cipher.doFinal(encrypted);

                return new String(decrypted, StandardCharsets.UTF_8);
            } catch (final Exception e) {
                HBlogger.e(TAG, "解密读取失败: " + key, e);
                return null;
            }
        }
    }

    /**
     * 删除加密数据。
     *
     * @param key 存储键
     */
    public void remove(@NonNull final String key) {
        synchronized (lock) {
            preferences.edit().remove(key).apply();
            HBlogger.d(TAG, "删除加密数据: " + key);
        }
    }

    /**
     * 清空所有加密数据。
     */
    public void clear() {
        synchronized (lock) {
            preferences.edit().clear().apply();
            HBlogger.d(TAG, "清空所有加密数据");
        }
    }

    /**
     * 检查加密存储是否可用。
     *
     * @return 是否可用
     */
    public boolean isAvailable() {
        return masterKey != null;
    }
}
