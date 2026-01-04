cmake_minimum_required(VERSION 3.4.1)

project(HelpBot)

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 源文件
set(HELPBOT_SRC
    ../../src/HBLogger.cpp
    ../../src/HelpBot.cpp
    HelpBotJNI.cpp
    HelpBotAndroid.cpp
)

# 头文件目录
include_directories(
    ../../include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# 创建静态库
add_library(helpbot STATIC ${HELPBOT_SRC})

# 链接库
target_link_libraries(helpbot
    log
    android
)

# 导出头文件目录
target_include_directories(helpbot PUBLIC
    ../../include
)
