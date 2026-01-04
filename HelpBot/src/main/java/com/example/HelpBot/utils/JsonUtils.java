package com.example.HelpBot.utils;

import com.example.HelpBot.log.HBlogger;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public class JsonUtils {
    private static final String TAG = "JsonUtils";

    private JsonUtils() {
        super();
    }

    public static boolean isEmpty(final JSONArray array) {
        return array == null || array.length() == 0;
    }

    public static boolean isEmpty(final JSONObject object) {
        return object == null || object.length() == 0;
    }

    public static Map<String, Object> jsonStringToMap(final String jsonString) {
        if (Utils.isEmpty(jsonString) || !isValidJsonString(jsonString)) {
            return new HashMap<String, Object>();
        }
        try {
            final JSONObject jsonObject = new JSONObject(jsonString);
            return toMap(jsonObject);
        } catch (final JSONException e) {
            HBlogger.e(TAG, "从 JSON 字符串创建 Map 异常", (Throwable) e);
            return new HashMap<String, Object>();
        }
    }

    public static <K, V> String mapToJsonString(final Map<K, V> data) {
        if (data != null) {
            return new JSONObject((Map) data).toString();
        }
        return "";
    }

    public static Map<String, String> jsonStringToStringMap(final String jsonString) {
        if (Utils.isEmpty(jsonString) || !isValidJsonString(jsonString)) {
            return new HashMap<String, String>();
        }
        try {
            final Map<String, String> dataMap = new HashMap<String, String>();
            final JSONObject jsonObject = new JSONObject(jsonString);
            final Iterator<String> keys = jsonObject.keys();
            while (keys.hasNext()) {
                final String key = keys.next();
                dataMap.put(key, jsonObject.getString(key));
            }
            return dataMap;
        } catch (final Exception e) {
            HBlogger.e(TAG, "从 JSON 字符串创建 String Map 异常", e);
            return new HashMap<String, String>();
        }
    }

    public static Map<String, Object> parseConfigDictionary(final String jsonStr) throws JSONException {
        final JSONObject jsonObject = new JSONObject(jsonStr);
        return toMap(jsonObject);
    }

    public static HashMap<String, Object> toMap(final JSONObject object) throws JSONException {
        final HashMap<String, Object> map = new HashMap<String, Object>();
        final Iterator<String> keys = object.keys();
        while (keys.hasNext()) {
            final String key = keys.next();
            map.put(key, fromJson(object.get(key)));
        }
        return map;
    }

    public static List<Object> toList(final JSONArray array) throws JSONException {
        final List<Object> list = new ArrayList<Object>();
        for (int i = 0; i < array.length(); ++i) {
            list.add(fromJson(array.get(i)));
        }
        return list;
    }

    private static Object fromJson(final Object json) throws JSONException {
        if (json == JSONObject.NULL) {
            return null;
        }
        if (json instanceof JSONObject) {
            return toMap((JSONObject) json);
        }
        if (json instanceof JSONArray) {
            return toList((JSONArray) json);
        }
        return json;
    }

    public static JSONArray listOfMapToJSONArray(final List<Map<String, String>> data) {
        if (data == null || data.isEmpty()) {
            return new JSONArray();
        }
        return new JSONArray((Collection) data);
    }

    public static boolean isValidJsonString(final String json) {
        try {
            new JSONObject(json);
        } catch (final Exception invalidJsonObject) {
            try {
                new JSONArray(json);
            } catch (final Exception invalidJsonArray) {
                return false;
            }
        }
        return true;
    }

    public static <T> List<T> listFromJsonArrayString(final String jsonString) {
        List<T> list = new ArrayList<T>();
        try {
            list = (List<T>) (Utils.isEmpty(jsonString) ? list : toList(new JSONArray(jsonString)));
        } catch (final Exception e) {
            HBlogger.e(TAG, "从 JSON 数组字符串获取列表异常", e);
        }
        return list;
    }

    public static <T> JSONArray jsonArrayFromList(final List<T> list) {
        try {
            return new JSONArray((Collection) list);
        } catch (final Exception e) {
            HBlogger.e(TAG, "从列表获取 JSON 数组异常", e);
            return new JSONArray();
        }
    }
}
