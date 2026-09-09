/****************************************************************************
 * ZGC 覆盖层：Fly 仪表面板（IntegratedCompassAttitude）卡片化重绘
 * 同路径覆盖上游 qml/QGroundControl/FlightMap/Widgets/IntegratedCompassAttitude.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：A3-20260908-modern1（ZFYZ-30）。仅视觉/样式层变更：
 *   - 机械同心圆仪表 → 圆角卡片底 + 卡片内同心罗盘/姿态环
 *   - 公开属性与几何契约不变（attitudeSize/attitudeSpacing 别名、extraInset、
 *     extraValuesWidth、compassRadius 系列、vehicle、qgcPal、usedByMultipleVehicleList）
 * 上游原文位置：src/FlightMap/Widgets/IntegratedCompassAttitude.qml
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

Item {
    id:             control
    implicitWidth:  (compassRadius * 2) + attitudeSpacing + attitudeSize
    implicitHeight: implicitWidth

    property alias attitudeSize:                rollIndicator.attitudeSize
    property alias attitudeSpacing:             rollIndicator.attitudeSpacing
    property real extraInset:                   attitudeSize + attitudeSpacing
    property real extraValuesWidth:             compassRadius
    property real defaultCompassRadius:         (mainWindow.width * 0.15) / 2
    property real maxCompassRadius:             ScreenTools.defaultFontPixelHeight * 7 / 2
    property real compassRadius:                Math.min(defaultCompassRadius, maxCompassRadius)
    property real compassBorder:                ScreenTools.defaultFontPixelHeight / 2
    property var  vehicle:                      globals.activeVehicle
    property var  qgcPal:                       QGroundControl.globalPalette
    property bool usedByMultipleVehicleList:    false

    property real _totalAttitudeSize: attitudeSize + attitudeSpacing

    // ZGC: 卡片化布局参数——姿态环按罗盘半径收缩，保证同心圆簇完整落在卡片内 — ZFYZ-30
    property real _cardRadius:          ScreenTools.defaultFontPixelHeight / 2
    property real _innerCompassRadius:  compassRadius - (attitudeSpacing + attitudeSize / 2)
    property real _innerTotalRadius:    _innerCompassRadius + attitudeSpacing + attitudeSize
    property real _cardCenterX:         width / 2
    property real _cardCenterY:         height / 2

    // 圆角卡片底：替代上游裸圆仪表盘，地图/视频背景上保持可读
    Rectangle {
        anchors.fill:   parent
        radius:         _cardRadius
        color:          qgcPal.window
        border.color:   qgcPal.windowShadeLight
        border.width:   1
    }

    IntegratedAttitudeIndicator {
        id:                     rollIndicator
        x:                      _cardCenterX - _innerTotalRadius
        y:                      _cardCenterY - _innerTotalRadius
        compassRadius:          control._innerCompassRadius
    }

    IntegratedAttitudeIndicator {
        x:                      _cardCenterX - _innerTotalRadius
        y:                      _cardCenterY - _innerTotalRadius
        // Negated: rotating the indicator 90° clockwise moves its zero tick to the right of the
        // compass but leaves the sweep direction clockwise, which would draw nose up as downward.
        attitudeAngleDegrees:   vehicle ? -vehicle.pitch.rawValue : 0
        compassRadius:          control._innerCompassRadius
        attitudeSize:           control.attitudeSize
        attitudeSpacing:        control.attitudeSpacing
        transformOrigin:        Item.Center
        rotation:               90
    }

    Rectangle {
        x:      _cardCenterX - compassRadius
        y:      _cardCenterY - compassRadius
        width:  compassRadius * 2
        height: width
        radius: width / 2
        color:  qgcPal.windowShade

        QGCCompassWidget {
            size:                       parent.width - compassBorder
            vehicle:                    control.vehicle
            usedByMultipleVehicleList:  control.usedByMultipleVehicleList
            anchors.centerIn:           parent
        }
    }
}
