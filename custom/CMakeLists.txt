# ============================================================================
# ZGC (ZflyGroundControl) Custom Overlay
# 由 custom-example/CMakeLists.txt 引导；功能示例按任务 A2-20260903-brand-ui（ZFYZ-5）裁剪，
# 仅保留品牌资源注册与 CustomPlugin（URL 拦截器宿主）注入。
# ============================================================================

message(STATUS "QGC: Adding Custom Plugin (ZGC)")

# ============================================================================
# Custom Android Package Template（覆盖机制保留；custom/android 目前为空目录骨架，
# GLOB 结果为空时自动回退上游默认包，零副作用。Android 图标/Splash 属后续阶段）
# ============================================================================

if(ANDROID)
    set(CUSTOM_ANDROID_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android")
    if(IS_DIRECTORY "${CUSTOM_ANDROID_DIR}")
        file(GLOB_RECURSE CUSTOM_ANDROID_FILES
            CONFIGURE_DEPENDS
            LIST_DIRECTORIES FALSE
            "${CUSTOM_ANDROID_DIR}/*"
        )
        if(CUSTOM_ANDROID_FILES)
            message(STATUS "QGC: Custom Android package template found. Overlaying custom files...")
            set(DEFAULT_ANDROID_DIR "${CMAKE_SOURCE_DIR}/android")
            set(FINAL_ANDROID_DIR "${CMAKE_BINARY_DIR}/${QGC_CUSTOM_DIR}/android")
            file(GLOB_RECURSE DEFAULT_ANDROID_FILES
                CONFIGURE_DEPENDS
                LIST_DIRECTORIES FALSE
                "${DEFAULT_ANDROID_DIR}/*"
            )

            # Recreate the merge so removed source files cannot remain stale.
            file(REMOVE_RECURSE "${FINAL_ANDROID_DIR}")
            file(COPY "${DEFAULT_ANDROID_DIR}/" DESTINATION "${FINAL_ANDROID_DIR}")
            file(COPY "${CUSTOM_ANDROID_DIR}/" DESTINATION "${FINAL_ANDROID_DIR}")

            set(QGC_ANDROID_PACKAGE_SOURCE_DIR "${FINAL_ANDROID_DIR}")
            set(QGC_ANDROID_PACKAGE_SOURCE_DIR "${FINAL_ANDROID_DIR}" PARENT_SCOPE)
            message(STATUS "QGC: Android package template path will be set to: ${QGC_ANDROID_PACKAGE_SOURCE_DIR}")
        else()
            message(STATUS "QGC: Custom Android package template empty. Using default.")
        endif()
    else()
        message(STATUS "QGC: No custom Android package template found. Using default.")
    endif()
endif()

# ============================================================================
# ZGC Brand Resources
# ============================================================================

# 应用内 Logo：CustomOverrideInterceptor 将上游请求 qrc:/res/QGCLogoFull.svg 改写为
# qrc:/Custom/res/QGCLogoFull.svg，因此资源别名必须精确等于上游请求名 "QGCLogoFull.svg"
# （含 .svg 后缀）。文件实体为 PNG（源 Icon/png/logo_512.png），Qt Image 按内容嗅探格式，
# 与扩展名无关（A1 调研报告 §3.3）。上游消费点：FlightMap/GeoMap/MainWindow/Toolbar 等。
set(CUSTOM_LOGO_RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/res/Images/QGCLogoFull.png")
set_source_files_properties("${CUSTOM_LOGO_RESOURCE}" PROPERTIES QT_RESOURCE_ALIAS "QGCLogoFull.svg")
qt_add_resources(${CMAKE_PROJECT_NAME} custom_brand
    PREFIX "/Custom/res"
    FILES "${CUSTOM_LOGO_RESOURCE}"
)

# Linux 窗口图标：QGCApplication.cc 仅在 Q_OS_LINUX 下请求 qrc:/res/qgroundcontrol.ico 并经
# 拦截器改写；Windows 下 exe 图标走 QGC_WINDOWS_ICON_PATH 的 RC 编译，不依赖此资源。
# 复用 Windows 安装图标同一物理文件，避免二进制重复入库。
set(CUSTOM_APP_ICON_RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/deploy/windows/WindowsQGC.ico")
set_source_files_properties("${CUSTOM_APP_ICON_RESOURCE}" PROPERTIES QT_RESOURCE_ALIAS "qgroundcontrol.ico")
qt_add_resources(${CMAKE_PROJECT_NAME} custom_brand_icon
    PREFIX "/Custom/res"
    FILES "${CUSTOM_APP_ICON_RESOURCE}"
)

# ZGC: 按 A2 裁剪（ZFYZ-5）的资源条目——如后续阶段需要，参照 custom-example/CMakeLists.txt 回补：
#   custom_images             （res/Images/*.svg 部件示例图集，PREFIX /custom/img）
#   custom_vehicle_icon       （CustomVehicleIcon.svg → 别名 PaperPlane.svg，PREFIX /Custom/qmlimages）
#   custom_qml_overrides      （CustomGuidedActionsController.qml / FlyViewCustomLayer.qml /
#                              FlyViewToolStripActionList.qml，PREFIX /Custom/qml）
#   custom_shared_resources   （上游 gear-white.svg → PREFIX /res）
#   custom_json               （PerimeterScan.SettingsGroup.json，PREFIX /json）
#   custom_settings_json      （Custom.SettingsGroup.json，PREFIX /json）
#   QML_IMPORT_PATH           （res/Custom/Widgets 导入路径，随 CustomModule 裁剪）

# ============================================================================
# Custom Plugin Sources
# ============================================================================

set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.h
    PARENT_SCOPE
)
# ZGC: 按 A2 裁剪（ZFYZ-5）的源码条目——CustomAutoPilotPlugin / CustomFirmwarePlugin /
# CustomFirmwarePluginFactory / PerimeterScanComplexItem / PerimeterScanPlanCreator /
# CustomSettings（详见报告裁剪清单）。

set(CUSTOM_LIBRARIES
    PARENT_SCOPE
)
# ZGC: 按 A2 裁剪（ZFYZ-5）：CustomModule（Custom.Widgets 部件示例）与
# CustomPlanModule（PerimeterScan 地图组件）两个静态 QML 模块不再构建。

set(CUSTOM_INCLUDE_DIRECTORIES
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    PARENT_SCOPE
)

# CUSTOM_DEFINITIONS 注入约定：QGCCorePlugin.cc 在 QGC_CUSTOM_BUILD 下
# #include CUSTOMHEADER 并由 CUSTOMCLASS::instance() 替换单例（调研报告 §1）。
set(CUSTOM_DEFINITIONS
    QGC_CUSTOM_BUILD
    CUSTOMHEADER="CustomPlugin.h"
    CUSTOMCLASS=CustomPlugin
    PARENT_SCOPE
)

set(CUSTOM_QT_COMPONENTS
    Core
    PARENT_SCOPE
)
