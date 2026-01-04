package com.example.HelpBot.core;

import androidx.annotation.NonNull;

import java.util.Map;

public interface HelpBotEventsListener {
    void onEventOccurred(@NonNull final String eventName, final Map<String, Object> data);

    void onUserAuthenticationFailure(final HelpBotAuthenticationFailureReason reason);
}
