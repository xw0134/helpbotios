cmake_minimum_required(VERSION 3.10)

set(APP_NAME HelpBotCocos)
project(${APP_NAME})

# Cocos2d-x 路径配置
set(COCOS2DX_ROOT_PATH "C:/Cocos/Cocos2d-x")
set(CMAKE_MODULE_PATH ${COCOS2DX_ROOT_PATH}/cmake/Modules/)

include(CocosBuildSet)
add_subdirectory(${COCOS2DX_ROOT_PATH}/cocos ${ENGINE_BINARY_PATH}/cocos/core)

# 编译选项
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 源文件列表
set(GAME_SOURCE
    Classes/AppDelegate.cpp
    Classes/MainScene.cpp
    Classes/HelpBotBridge.cpp
)

set(GAME_HEADERS
    Classes/AppDelegate.h
    Classes/MainScene.h
    Classes/HelpBotBridge.h
)

# 资源文件
set(GAME_RES_FOLDER
    "${CMAKE_CURRENT_SOURCE_DIR}/Resources"
)

if(ANDROID)
    # Android 平台特定配置
    list(APPEND GAME_SOURCE
         proj.android/app/jni/hellocpp/main.cpp
    )
elseif(APPLE)
    # iOS 平台特定配置
    if(IOS)
        list(APPEND GAME_HEADERS
             proj.ios_mac/ios/RootViewController.h
        )
        list(APPEND GAME_SOURCE
             proj.ios_mac/ios/main.m
             proj.ios_mac/ios/RootViewController.mm
             proj.ios_mac/ios/AppController.mm
        )
        
        # iOS 资源
        file(GLOB_RECURSE APP_RESOURCES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
             "proj.ios_mac/ios/*.png"
             "proj.ios_mac/ios/*.jpg"
        )
        list(APPEND GAME_SOURCE ${APP_RESOURCES})
        
        # Framework 链接
        set(APP_FRAMEWORKS
            HelpBotSDK
        )
        
        # Framework 搜索路径
        set(FRAMEWORK_SEARCH_PATHS
            "${CMAKE_CURRENT_SOURCE_DIR}/proj.ios_mac/ios/Frameworks"
        )
    endif()
endif()

# 包含目录
set(GAME_INC_DIRS
    "${CMAKE_CURRENT_SOURCE_DIR}/Classes"
)

# 创建可执行文件
if(ANDROID)
    add_library(${APP_NAME} SHARED ${GAME_SOURCE} ${GAME_HEADERS})
    IF(CMAKE_BUILD_TYPE MATCHES RELEASE)
        ADD_CUSTOM_COMMAND(TARGET ${APP_NAME} POST_BUILD COMMAND ${CMAKE_STRIP} lib${APP_NAME}.so)
    ENDIF()
else()
    add_executable(${APP_NAME} ${GAME_SOURCE} ${GAME_HEADERS})
endif()

# 链接目录
target_link_directories(${APP_NAME}
    PRIVATE ${COCOS2DX_ROOT_PATH}/cocos/platform
    PRIVATE ${COCOS2DX_ROOT_PATH}/external
)

# 包含目录
target_include_directories(${APP_NAME}
    PRIVATE ${GAME_INC_DIRS}
    PRIVATE ${COCOS2DX_ROOT_PATH}/cocos
    PRIVATE ${COCOS2DX_ROOT_PATH}/external
)

# 链接库
target_link_libraries(${APP_NAME} cocos2d)

# iOS 特定配置
if(APPLE)
    if(IOS)
        set_target_properties(${APP_NAME} PROPERTIES
            MACOSX_BUNDLE 1
            MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/proj.ios_mac/ios/Info.plist"
            XCODE_ATTRIBUTE_FRAMEWORK_SEARCH_PATHS "${FRAMEWORK_SEARCH_PATHS}"
        )
        
        # 链接 Framework
        foreach(FRAMEWORK ${APP_FRAMEWORKS})
            target_link_libraries(${APP_NAME} "-framework ${FRAMEWORK}")
        endforeach()
        
        # 设置资源文件
        set_source_files_properties(${APP_RESOURCES} PROPERTIES
            MACOSX_PACKAGE_LOCATION Resources
        )
    endif()
endif()

# 复制资源文件
if(ANDROID)
    # Android 资源通过 assets 目录处理
else()
    # 其他平台复制资源
    cocos_copy_target_res(${APP_NAME} COPY_TO ${CMAKE_CURRENT_BINARY_DIR}/Resources FOLDERS ${GAME_RES_FOLDER})
endif()

# 预编译宏定义
target_compile_definitions(${APP_NAME}
    PRIVATE $<$<CONFIG:Debug>:COCOS2D_DEBUG=1>
)
