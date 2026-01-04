package com.example.HelpBot.core;

import java.util.Map;

public interface HelpBotUserLoginEventsListener {

    void onLoginSuccess();

    void onLoginFailure(final String reason, final Map<String, String> error);
}
