# ============================================================================
# ZGC (ZflyGroundControl) Build Configuration Overrides
# 由 custom-example/cmake/CustomOverrides.cmake 引导，按任务 A2-20260903-brand-ui（ZFYZ-5）裁剪。
# 本文件在根 CMakeLists.txt project() 之前被 include，品牌变量必须用 CACHE ... FORCE 才能生效。
# ============================================================================

# ----------------------------------------------------------------------------
# Application Branding（变量取值由 Mika 裁决：QGC_APP_NAME 用 ASCII，规避中文
# project/exe 名的工具链风险 R1；中文品牌由覆盖层 QML/显示名机制呈现）
# ----------------------------------------------------------------------------
set(QGC_APP_NAME "ZflyGroundControl" CACHE STRING "App Name" FORCE)
set(QGC_APP_COPYRIGHT "Copyright (c) 2026 志翔. All rights reserved." CACHE STRING "Copyright" FORCE)
set(QGC_APP_DESCRIPTION "志翔无人系统地面站" CACHE STRING "App Description" FORCE)
set(QGC_ORG_NAME "志翔" CACHE STRING "Org Name" FORCE)
set(QGC_ORG_DOMAIN "zfly.example.com" CACHE STRING "Org Domain" FORCE)
set(QGC_PACKAGE_NAME "com.zfly.zgc" CACHE STRING "Package Name" FORCE)

# QGC_ANDROID_PACKAGE_NAME 在 CustomOptions.cmake 中取 ${QGC_PACKAGE_NAME} 的时机早于本文件，
# 不 FORCE 会残留默认值 org.mavlink.qgroundcontrol（Android 打包本阶段不做，仅校正元数据）。
set(QGC_ANDROID_PACKAGE_NAME "com.zfly.zgc" CACHE STRING "Android package identifier" FORCE)

# ----------------------------------------------------------------------------
# MSVC 源码字符集
# 仓库未启用 /utf-8（cmake/CompilerWarnings.cmake 仅 /wd4819 压警告）。无 BOM 的 UTF-8
# 源文件在非 UTF-8 代码页（如简中 GBK）下，MSVC 会按代码页解码——qgc_version.h 经
# configure 展开的中文品牌串（版权/组织名/描述）会被错误转码。此处在覆盖层根作用域
# （先于 project()、被子目录继承）用生成器表达式仅对 MSVC 全局追加 /utf-8，零上游改动。
# A4 验证点：确认中文版权/组织名在注册表与安装器元数据中显示正常。
# ----------------------------------------------------------------------------
add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")

# ----------------------------------------------------------------------------
# Custom Icons and Graphics
# 素材源目录 E:/QGC/QGC_ZFLY/Icon（A3a 投放）。全部沿用模板的 if(EXISTS) 守卫模式：
# 缺素材时守卫不生效，自动回退上游默认路径，不阻断 configure。
# ----------------------------------------------------------------------------

# macOS Icon（源 Icon/logo.icns）
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/logo.icns")
    set(QGC_MACOS_ICON_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/logo.icns" CACHE FILEPATH "MacOS Icon Path" FORCE)
endif()

# Linux AppImage Icon（A3a 未投放 SVG 素材，守卫暂不生效；保留条目供后续阶段按同名路径投放）
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/logo.svg")
    set(QGC_APPIMAGE_ICON_SCALABLE_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/logo.svg" CACHE FILEPATH "AppImage Icon SVG Path" FORCE)
endif()

# Windows Installer Header（A3a 未投放素材，守卫暂不生效；保留条目供后续阶段按同名路径投放）
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/installheader.bmp")
    set(QGC_WINDOWS_INSTALL_HEADER_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/installheader.bmp" CACHE FILEPATH "Windows Install Header Path" FORCE)
endif()

# Windows Application Icon（源 Icon/logo.ico；消费点 cmake/platform/Windows.cmake 的 RC 编译）
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/WindowsQGC.ico")
    set(QGC_WINDOWS_ICON_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/WindowsQGC.ico" CACHE FILEPATH "Windows Icon Path" FORCE)
endif()

# ----------------------------------------------------------------------------
# Feature Set Customization
# R5 裁决：ZGC 主用 ArduPilot，不设置 QGC_DISABLE_APM_PLUGIN_FACTORY；
# PX4 工厂开关保持上游默认，不照抄 custom-example 模板的 QGC_DISABLE_PX4_PLUGIN_FACTORY ON。
# ----------------------------------------------------------------------------
