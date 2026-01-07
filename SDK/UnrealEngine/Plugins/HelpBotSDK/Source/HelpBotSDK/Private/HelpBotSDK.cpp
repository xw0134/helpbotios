#include "HelpBotSDK.h"

#if PLATFORM_ANDROID
#include "Android/AndroidApplication.h"
#include "Android/AndroidJNI.h"
#include "Android/AndroidJava.h"
#endif

#define LOCTEXT_NAMESPACE "FHelpBotSDKModule"

void FHelpBotSDKModule::StartupModule()
{
	// This code will execute after your module is loaded into memory; the exact timing is specified in the .uplugin file per-module
}

void FHelpBotSDKModule::ShutdownModule()
{
	// This function may be called during shutdown to clean up your module.  For modules that support dynamic reloading,
	// we call this function before unloading the module.
}

void FHelpBotSDKModule::Install(const FString& ChannelId, const FString& Domain)
{
#if PLATFORM_ANDROID
	if (JNIEnv* Env = FAndroidApplication::GetJavaEnv())
	{
		jstring jChannelId = Env->NewStringUTF(TCHAR_TO_UTF8(*ChannelId));
		jstring jDomain = Env->NewStringUTF(TCHAR_TO_UTF8(*Domain));
		
		FJavaWrapper::CallVoidMethod(Env, FJavaWrapper::GameActivityThis, FJavaWrapper::FindMethod(Env, FJavaWrapper::GameActivityClassID, "AndroidThunkJava_HelpBot_Install", "(Ljava/lang/String;Ljava/lang/String;)V", false), jChannelId, jDomain);
		
		Env->DeleteLocalRef(jChannelId);
		Env->DeleteLocalRef(jDomain);
	}
#elif PLATFORM_IOS
    // iOS wrapper call would go here
#endif
}

void FHelpBotSDKModule::Login(const FString& JwtToken)
{
#if PLATFORM_ANDROID
	if (JNIEnv* Env = FAndroidApplication::GetJavaEnv())
	{
		jstring jToken = Env->NewStringUTF(TCHAR_TO_UTF8(*JwtToken));
		
		FJavaWrapper::CallVoidMethod(Env, FJavaWrapper::GameActivityThis, FJavaWrapper::FindMethod(Env, FJavaWrapper::GameActivityClassID, "AndroidThunkJava_HelpBot_Login", "(Ljava/lang/String;)V", false), jToken);
		
		Env->DeleteLocalRef(jToken);
	}
#endif
}

void FHelpBotSDKModule::ShowConversation()
{
#if PLATFORM_ANDROID
	if (JNIEnv* Env = FAndroidApplication::GetJavaEnv())
	{
		FJavaWrapper::CallVoidMethod(Env, FJavaWrapper::GameActivityThis, FJavaWrapper::FindMethod(Env, FJavaWrapper::GameActivityClassID, "AndroidThunkJava_HelpBot_ShowConversation", "()V", false));
	}
#endif
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FHelpBotSDKModule, HelpBotSDK)
