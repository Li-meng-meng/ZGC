/****************************************************************************
 * ZGC 覆盖层：字阶系统 5 级化＋派生字号重定比（Fly/Plan/Setup/Settings 全局生效）
 * 同路径覆盖上游 qml/QGroundControl/Controls/ScreenTools.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：A3-20260909-roundF-typescale（ZFYZ-42）。仅字号体系层变更：
 *   - 5 级字阶：xsmall 0.75 / small 0.85 / default 1.0 / medium 1.15 / large 1.3
 *     （上游为 small/medium/large 三级倍率 0.75/1.25/1.5，无体系；本表克制重定，默认字号不动）
 *   - small 0.75 → 0.85：小字号可读性修正（B 项被否决教训：可读性优先）
 *   - medium 1.25 → 1.15、large 1.5 → 1.3：标题级收敛，层级更平缓（密度收紧的标题侧）
 *   - 新增 xsmall 级（0.75，沿上游 small 旧值）：超密场景可选级，上游零引用、零行为变化
 *   - ratio 属性名（small/medium/largeFontPointRatio）与全部既有属性/函数签名不变，
 *     外部 ratio 引用点（MissionItemIndexLabel.qml:34 等按 ratio 算几何）自动跟随
 *   - 其余（_setBasePointSize 流程、uiScalePercent 联动、平台判定、fakeMobile）与上游逐行一致
 * 上游原文位置：src/QmlControls/ScreenTools.qml
 ****************************************************************************/

pragma Singleton

import QtQuick
import QtQuick.Controls
import QtQuick.Window

import QGroundControl

// ZGC: 覆盖件经拦截器以散文件路径加载，不继承模块目录类型可见性（H 轮教训）；
// ScreenToolsController 为 QGroundControl.Controls 模块 C++ 单例，须显式 import
// （D 轮 ToolStrip 覆盖件同法先例）— ZFYZ-42
import QGroundControl.Controls

/*!
 The ScreenTools Singleton provides information on QGC's standard font metrics. It also provides information on screen
 size which can be used to adjust user interface for varying available screen real estate.

 QGC has four standard font sizes: default, small, medium and large. The QGC controls use the default font for display and you should use this font
 for most text within the system that is drawn using something other than a standard QGC control. The small font is smaller than the default font.
 The medium and large fonts are larger than the default font.

 Usage:

        import QGroundControl.Controls
        Rectangle {
            anchors.fill:       parent
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            ...
        }
*/
Item {
    id: _screenTools

    //-- The point and pixel font size values are computed at runtime

    property real defaultFontPointSize:     10
    property real platformFontPointSize:    10

    // ZGC: 5 级字阶表——xsmall 0.75（新增级，沿上游 small 旧值）/ small 0.85（可读性
    // 修正）/ medium 1.15、large 1.3（标题级收敛）。属性名不变，外部几何引用自动跟随
    // — ZFYZ-42
    readonly property real xsmallFontPointRatio:     0.75
    readonly property real smallFontPointRatio:      0.85
    readonly property real mediumFontPointRatio:     1.15
    readonly property real largeFontPointRatio:      1.3

    /// You can use these properties to position ui elements in a screen resolution independent manner. Using fixed positioning values should not
    /// be done. All positioning should be done using anchors or a ratio of the defaultFontPixelHeight and defaultFontPixelWidth values. This way
    /// your ui elements will reposition themselves appropriately on varying screen sizes and resolutions.
    property real defaultFontPixelHeight:   10
    property real largeFontPixelHeight:     defaultFontPixelHeight * largeFontPointRatio
    property real mediumFontPixelHeight:    defaultFontPixelHeight * mediumFontPointRatio
    // ZGC: xsmall 级像素尺寸（与 small/medium/large 同源倍率）— ZFYZ-42
    property real xsmallFontPixelHeight:    defaultFontPixelHeight * xsmallFontPointRatio
    property real xsmallFontPixelWidth:     defaultFontPixelWidth * xsmallFontPointRatio
    property real smallFontPixelHeight:     defaultFontPixelHeight * smallFontPointRatio

    /// You can use these properties to position ui elements in a screen resolution independent manner. Using fixed positioning values should not
    /// be done. All positioning should be done using anchors or a ratio of the defaultFontPixelHeight and defaultFontPixelWidth values. This way
    /// your ui elements will reposition themselves appropriately on varying screen sizes and resolutions.
    property real defaultFontPixelWidth:    10
    property real largeFontPixelWidth:      defaultFontPixelWidth * largeFontPointRatio
    property real mediumFontPixelWidth:     defaultFontPixelWidth * mediumFontPointRatio
    property real smallFontPixelWidth:      defaultFontPixelWidth * smallFontPointRatio

    /// QFontMetrics::descent for default font at default point size
    property real defaultFontDescent:       0

    /// The default amount of space in between controls in a dialog
    property real defaultDialogControlSpacing: defaultFontPixelHeight / 2

    // ZGC: 新增 xsmall 级派生字号（与 small/medium/large 同源计算）— ZFYZ-42
    property real xsmallFontPointSize:      10
    property real smallFontPointSize:       10
    property real mediumFontPointSize:      10
    property real largeFontPointSize:       10

    property real toolbarHeight:            0

    property real realPixelDensity: {
        //-- If a plugin defines it, just use what it tells us
        if(QGroundControl.corePlugin.options.devicePixelDensity != 0) {
            return QGroundControl.corePlugin.options.devicePixelDensity
        }
        //-- Android is rather unreliable
        if(isAndroid) {
            // Lets assume it's unlikely you have a tablet over 300mm wide
            if((Screen.width / Screen.pixelDensity) > 300) {
                return Screen.pixelDensity * 2
            }
        }
        //-- Let's use what the system tells us
        return Screen.pixelDensity
    }

    // These properties allow us to create simulated mobile sizing for a desktop build.
    // This makes testing the UI for smaller mobile sizing much easier.
    // The 731x411 size is the size of the Herelink screen which is our target lower bound
    property real screenWidth:  ScreenToolsController.fakeMobile ? 731 : Screen.width
    property real screenHeight: ScreenToolsController.fakeMobile ? 411 : Screen.height

    property bool isAndroid:                        ScreenToolsController.isAndroid
    property bool isiOS:                            ScreenToolsController.isiOS
    property bool isMobile:                         ScreenToolsController.isMobile
    property bool isFakeMobile:                     ScreenToolsController.fakeMobile
    property bool isWindows:                        ScreenToolsController.isWindows
    property bool isDebug:                          ScreenToolsController.isDebug
    property bool isMac:                            ScreenToolsController.isMacOS
    property bool isLinux:                          ScreenToolsController.isLinux
    property bool isTinyScreen:                     (Screen.width / realPixelDensity) < 120 // 120mm
    property bool isShortScreen:                    ((Screen.height / realPixelDensity) < 120) || (ScreenToolsController.isMobile && ((Screen.height / Screen.width) < 0.6))
    property bool isHugeScreen:                     (Screen.width / realPixelDensity) >= (23.5 * 25.4) // 27" monitor
    property bool isSerialAvailable:                ScreenToolsController.isSerialAvailable

    readonly property real minTouchMillimeters:     5   ///< Minimum touch size in millimeters
    property real minTouchPixels:                   0   ///< Minimum touch size in pixels (calculatedd from minTouchMillimeters and realPixelDensity)

    // The implicit heights/widths for our custom control set
    property real implicitButtonWidth:              Math.round(defaultFontPixelWidth *  5.0)
    property real implicitButtonHeight:             Math.round(defaultFontPixelHeight * 1.6)
    property real implicitCheckBoxHeight:           Math.round(defaultFontPixelHeight * 1.0)
    property real implicitRadioButtonHeight:        implicitCheckBoxHeight
    property real implicitTextFieldWidth:           defaultFontPixelWidth * 10
    property real implicitTextFieldHeight:          implicitButtonHeight
    property real implicitComboBoxHeight:           implicitButtonHeight
    property real implicitComboBoxWidth:            implicitButtonWidth
    property real comboBoxPadding:                  defaultFontPixelWidth
    property real implicitSliderHeight:             defaultFontPixelHeight
    property real defaultBorderRadius:              defaultFontPixelWidth / 2

    // It's not possible to centralize an even number of pixels, checkBoxIndicatorSize should be an odd number to allow centralization
    property real checkBoxIndicatorSize:            2 * Math.floor(defaultFontPixelHeight / 2) + 1
    property real radioButtonIndicatorSize:         checkBoxIndicatorSize

    readonly property string normalFontFamily:      ScreenToolsController.normalFontFamily
    readonly property string fixedFontFamily:       ScreenToolsController.fixedFontFamily
    /* This mostly works but for some reason, reflowWidths() in SetupView doesn't change size.
       I've disabled (in release builds) until I figure out why. Changes require a restart for now.
    */
    Connections {
        target: QGroundControl.settingsManager.appSettings.uiScalePercent
        function onValueChanged() {
            var pct = QGroundControl.settingsManager.appSettings.uiScalePercent.value
            _setBasePointSize(platformFontPointSize * pct / 100)
        }
    }

    onRealPixelDensityChanged: {
        _setBasePointSize(defaultFontPointSize)
    }

    function printScreenStats() {
        console.log('ScreenTools: Screen.width: ' + Screen.width + ' Screen.height: ' + Screen.height + ' Screen.pixelDensity: ' + Screen.pixelDensity)
    }

    /// Returns the current x position of the mouse in global screen coordinates.
    function mouseX() {
        return ScreenToolsController.mouseX()
    }

    /// Returns the current y position of the mouse in global screen coordinates.
    function mouseY() {
        return ScreenToolsController.mouseY()
    }

    /// \private
    function _setBasePointSize(pointSize) {
        _textMeasure.font.pointSize = pointSize
        defaultFontPointSize    = pointSize
        defaultFontPixelHeight  = Math.round(_textMeasure.fontHeight/2.0)*2
        defaultFontPixelWidth   = Math.round(_textMeasure.fontWidth/2.0)*2
        defaultFontDescent      = ScreenToolsController.defaultFontDescent(defaultFontPointSize)
        // ZGC: xsmall 级与 small/medium/large 同源计算 — ZFYZ-42
        xsmallFontPointSize     = defaultFontPointSize  * _screenTools.xsmallFontPointRatio
        smallFontPointSize      = defaultFontPointSize  * _screenTools.smallFontPointRatio
        mediumFontPointSize     = defaultFontPointSize  * _screenTools.mediumFontPointRatio
        largeFontPointSize      = defaultFontPointSize  * _screenTools.largeFontPointRatio
        minTouchPixels          = Math.round(minTouchMillimeters * realPixelDensity)
        if (minTouchPixels / Screen.height > 0.15) {
            // If using physical sizing takes up too much of the vertical real estate fall back to font based sizing
            minTouchPixels      = defaultFontPixelHeight * 3
        }
        toolbarHeight           = defaultFontPixelHeight * 3
        toolbarHeight           = toolbarHeight * QGroundControl.corePlugin.options.toolbarHeightMultiplier
    }

    Text {
        id:     _defaultFont
        text:   "X"
    }

    Text {
        id:     _textMeasure
        text:   "X"
        font.family:    normalFontFamily
        property real   fontWidth:    contentWidth
        property real   fontHeight:   contentHeight
        Component.onCompleted: {
            //-- First, compute platform, default size
            if(ScreenToolsController.isMobile) {
                //-- Check iOS really tiny screens (iPhone 4s/5/5s)
                if(ScreenToolsController.isiOS) {
                    if(ScreenToolsController.isiOS && Screen.width < 570) {
                        // For iPhone 4s size we don't fit with additional tweaks to fit screen,
                        // we will just drop point size to make things fit. Correct size not yet determined.
                        platformFontPointSize = 12;  // This will be lowered in a future pull
                    } else {
                        platformFontPointSize = 14;
                    }
                } else if((Screen.width / realPixelDensity) < 120) {
                    platformFontPointSize = 11;
                // Other Android
                } else {
                    platformFontPointSize = 14;
                }
            } else {
                platformFontPointSize = _defaultFont.font.pointSize;
            }
            //-- See if we are using a custom size
            var _uiScalePercentFact = QGroundControl.settingsManager.appSettings.uiScalePercent
            var pct = _uiScalePercentFact.value
            //-- Sanity check
            if(pct < _uiScalePercentFact.min || pct > _uiScalePercentFact.max) {
                pct = 100;
                _uiScalePercentFact.value = pct
            }
            //-- Set size saved in settings
            _screenTools._setBasePointSize(platformFontPointSize * pct / 100);
        }
    }
}
