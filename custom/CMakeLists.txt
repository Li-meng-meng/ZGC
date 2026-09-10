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
# （含 .svg 后缀）。上游消费点：FlightMap/GeoMap/MainWindow/Toolbar 等。
# ZGC: DEF-3——实体由裸 PNG 改为 SVG 信封（res/Images/QGCLogoFull.svg，base64 内嵌品牌
# PNG）。裸 PNG 字段顶着 .svg 别名时，Logo 按钮（QGCToolBarButton logo 路径 → QGCVectorImage）
# 解析失败导致四处 Logo 空白；VectorImage 支持 <image> 内嵌 data:URI 位图（Qt 6.11.1 实测，
# 证据见 workspace/artifacts/A3-20260905-brand-ui-fix/fix-def3-change.md），普通 Image
# 内容嗅探路径（GeoMap/FlightMap）同样成立。品牌素材更新后按信封内注释重造该文件。
set(CUSTOM_LOGO_RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/res/Images/QGCLogoFull.svg")
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

# ============================================================================
# ZGC QML Same-Path Overrides（A3d 界面现代化首轮 · ZFYZ-30）
# CustomOverrideInterceptor（custom/src/CustomPlugin.cc）把 qrc:/<path> 探测为
# :/Custom/<path>；以下别名精确等于上游 qrc 全路径（RESOURCE_PREFIX /qml + 模块 URI），
# 命中即整文件替换：Fly/Plan 工具栏三件。
# ZGC: 成员裁决回退 B 项（Fly 仪表卡片化）——IntegratedCompassAttitude.qml /
# QGCCompassWidget.qml 覆盖副本及其注册条目已删除，上游原生机械圆仪表恢复加载（ZFYZ-35）。
# ZGC: D 轮 ToolStrip 按钮组胶囊化——新增 ToolStrip.qml / ToolStripHoverButton.qml 两件
# 覆盖（Fly/Plan 左条共用组件；两件须同时注册，按钮胶囊形态才完整生效）
# （A3-20260909-roundD-toolstrip，ZFYZ-39）。
# ZGC: E 轮 Vehicle Summary 卡片升级——新增 VehicleSummary.qml 一件覆盖（Setup 页车辆概要
# 卡片统一圆角＋hover 抬升＋状态徽章化；加载点 VehicleConfigView.qml setSource 上游 qrc
# 全路径，经拦截器命中本覆盖）（A3-20260909-roundE-vehsum，ZFYZ-40）。
# ZGC: H 轮 Plan 右面板/指示器抽屉毛玻璃化——新增 PlanViewRightPanel.qml / MainWindow.qml
# 两件覆盖（MultiEffect 背景模糊＋窗底色半透调和层，零新增色值；后者为主窗口根文件覆盖，
# 加载点 QGCCorePlugin.cc createRootWindow 入口 load，经拦截器命中本覆盖）
# （A3-20260909-roundH-glass，ZFYZ-41）。
# 注册样板：custom-example/CMakeLists.txt（QT_RESOURCE_ALIAS 全路径 + PREFIX /Custom/qml）。
# ============================================================================
set(CUSTOM_QML_OVERRIDES
    "${CMAKE_CURRENT_SOURCE_DIR}/src/FlyViewToolBar.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/MainStatusIndicator.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/PlanViewToolBar.qml"
    # ZGC: D 轮 ToolStrip 按钮组胶囊化（A3-20260909-roundD-toolstrip，ZFYZ-39）
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ToolStrip.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ToolStripHoverButton.qml"
    # ZGC: E 轮 Vehicle Summary 卡片升级（A3-20260909-roundE-vehsum，ZFYZ-40）
    "${CMAKE_CURRENT_SOURCE_DIR}/src/VehicleSummary.qml"
    # ZGC: H 轮 Plan 右面板/指示器抽屉毛玻璃化（A3-20260909-roundH-glass，ZFYZ-41）
    "${CMAKE_CURRENT_SOURCE_DIR}/src/PlanViewRightPanel.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/MainWindow.qml"
)
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/src/FlyViewToolBar.qml"
    PROPERTIES QT_RESOURCE_ALIAS "QGroundControl/Toolbar/FlyViewToolBar.qml"
)
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/src/MainStatusIndicator.qml"
    PROPERTIES QT_RESOURCE_ALIAS "QGroundControl/Toolbar/MainStatusIndicator.qml"
)
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/src/PlanViewToolBar.qml"
    PROPERTIES QT_RESOURCE_ALIAS "QGroundControl/Toolbar/PlanViewToolBar.qml"
)
# ZGC: D 轮别名（QmlControls 模块 URI QGroundControl.Controls，RESOURCE_PREFIX /qml）— ZFYZ-39
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/src/ToolStrip.qml"
    PROPERTIES QT_RESOURCE_ALIAS "QGroundControl/Controls/ToolStrip.qml"
)
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/src/ToolStripHoverButton.qml"
    PROPERTIES QT_RESOURCE_ALIAS "QGroundControl/Controls/ToolStripHoverButton.qml"
)
# ZGC: E 轮别名（VehicleSetup 模块 URI QGroundControl.VehicleSetup，RESOURCE_PREFIX /qml）— ZFYZ-40
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/src/VehicleSummary.qml"
    PROPERTIES QT_RESOURCE_ALIAS "QGroundControl/VehicleSetup/VehicleSummary.qml"
)
# ZGC: H 轮别名（PlanViewRightPanel 属 PlanView 模块 URI QGroundControl.PlanView；
# MainWindow.qml 属 QGroundControl 根模块，别名与上游 src/CMakeLists.txt 的
# QT_RESOURCE_ALIAS "MainWindow.qml" 同形）— ZFYZ-41
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/src/PlanViewRightPanel.qml"
    PROPERTIES QT_RESOURCE_ALIAS "QGroundControl/PlanView/PlanViewRightPanel.qml"
)
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/src/MainWindow.qml"
    PROPERTIES QT_RESOURCE_ALIAS "QGroundControl/MainWindow.qml"
)
qt_add_resources(${CMAKE_PROJECT_NAME} custom_qml_overrides
    PREFIX "/Custom/qml"
    FILES ${CUSTOM_QML_OVERRIDES}
)

# ZGC: 按 A2 裁剪（ZFYZ-5）的资源条目——如后续阶段需要，参照 custom-example/CMakeLists.txt 回补
# （custom_qml_overrides 已于 ZFYZ-30 按本文件上方模板回补）：
#   custom_images             （res/Images/*.svg 部件示例图集，PREFIX /custom/img）
#   custom_vehicle_icon       （CustomVehicleIcon.svg → 别名 PaperPlane.svg，PREFIX /Custom/qmlimages）
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

# ============================================================================
# ZGC Build-Time Runtime Deployment (Windows)
# ============================================================================

# ZGC: A3-20260904-brand-ui-fix —— Windows 构建期自动部署 Qt/GStreamer 运行时（缺陷2）。
# 上游部署仅挂 install/CPack 期（cmake/install/Install.cmake），构建期零部署，裸 exe
# 0xC0000135（ZFYZ-11 遗留问题1）。产物只落 build 树输出目录，不影响 install/打包。
# 挂接机制（回修第1轮）：add_custom_command(TARGET ...) 禁止跨目录作用域调用（主目标
# 创建于根作用域，CMake 3.30.5 实测 configure 即报 "not created in this directory"），
# 故以 cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}") 把注册延迟到根目录作用域
# 末尾执行，POST_BUILD 语义不变。注意 DEFER 的参数在延迟执行时才于根作用域求值——
# custom 作用域普通变量不可见、${CMAKE_CURRENT_SOURCE_DIR} 会被展开为根目录——因此
# custom 作用域求好的值经 INTERNAL cache（FORCE 每轮刷新）传递，$<...> 生成器表达式
# 保持原样、由延迟后的 add_custom_command 在生成期求值。合成交叉工程已实测该形态
# （证据见 workspace/artifacts/A3-20260904-brand-ui-fix/coder-report.md 回修第1轮）。
if(WIN32 AND NOT ANDROID)
    option(ZGC_RUNTIME_DEPLOY
           "Deploy Qt/GStreamer runtime next to the executable after each build (ZGC dev convenience)"
           ON)
    if(ZGC_RUNTIME_DEPLOY AND TARGET Qt6::windeployqt)
        get_target_property(_zgc_wdeployqt Qt6::windeployqt IMPORTED_LOCATION_RELEASE)
        if(NOT _zgc_wdeployqt)
            # Host tools may map to another config; the genex resolves at generate
            # time and Qt6::windeployqt (found in the root scope) stays visible in
            # the deferred root-scope call.
            set(_zgc_wdeployqt "$<TARGET_FILE:Qt6::windeployqt>")
        endif()
        set(ZGC_WINDEPLOYQT_EXECUTABLE "${_zgc_wdeployqt}"
            CACHE INTERNAL "ZGC build-time deploy: windeployqt path" FORCE)
        set(ZGC_RUNTIME_DEPLOY_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/cmake/ZGCRuntimeDeploy.cmake"
            CACHE INTERNAL "ZGC build-time deploy: deploy script path" FORCE)
        cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL add_custom_command
            TARGET ${CMAKE_PROJECT_NAME}
            POST_BUILD
            COMMAND "${CMAKE_COMMAND}"
                    "-DWINDEPLOYQT_EXECUTABLE=${ZGC_WINDEPLOYQT_EXECUTABLE}"
                    "-DEXECUTABLE=$<TARGET_FILE:${CMAKE_PROJECT_NAME}>"
                    "-DOUTPUT_DIR=$<TARGET_FILE_DIR:${CMAKE_PROJECT_NAME}>"
                    "-DCONFIGURATION=$<CONFIG>"
                    "-DSOURCE_ROOT=${CMAKE_SOURCE_DIR}"
                    -P "${ZGC_RUNTIME_DEPLOY_SCRIPT}"
            VERBATIM
        )
        message(STATUS "QGC: ZGC runtime auto-deploy enabled (ZGC_RUNTIME_DEPLOY=ON)")
    elseif(ZGC_RUNTIME_DEPLOY)
        message(WARNING "QGC: ZGC_RUNTIME_DEPLOY is ON but the Qt6::windeployqt target was not found; build-time runtime deployment skipped.")
    endif()
endif()
