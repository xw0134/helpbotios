cmake_minimum_required(VERSION 3.22.1)

project(HelpBotCocos2dDemo)

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Cocos2d-x 路径
set(COCOS2D_ROOT "D:/cocos2d")

# 创建一个最小的测试库
# 注意: 完整的 Cocos2d-x 集成需要更复杂的配置
# 这里创建一个简单的 native 库用于验证编译流程

# 源文件 - 暂时只包含一个简单的 JNI 文件
set(GAME_SRC
    ${CMAKE_CURRENT_SOURCE_DIR}/test_native.cpp
)

# 头文件目录
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/../../Classes
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../HelpBot/include
)

# HelpBot 静态库路径
set(HELPBOT_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../HelpBot/platform/android)

# 添加 HelpBot 子目录
add_subdirectory(${HELPBOT_LIB_DIR} helpbot_build)

# 创建共享库
add_library(cocos2dcpp SHARED ${GAME_SRC})

# 查找必要的库
find_library(log-lib log)
find_library(android-lib android)

# 链接库
target_link_libraries(cocos2dcpp
    helpbot
    ${log-lib}
    ${android-lib}
)

# 导出头文件目录
target_include_directories(cocos2dcpp PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../../Classes
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../HelpBot/include
)
