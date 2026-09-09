/****************************************************************************
 * ZGC 覆盖层：现代罗盘部件（QGCCompassWidget）重绘
 * 同路径覆盖上游 qml/QGroundControl/FlightMap/Widgets/QGCCompassWidget.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：A3-20260908-modern1（ZFYZ-30）。仅视觉/样式层变更：
 *   - 去机械刻度盘（CompassDial）与硬描边圆盘 → 细线圆环 + 方位字母 + 双色现代指针
 *   - 航向数字读数改为底部胶囊徽章，数据层级清晰
 *   - 公开接口不变（size/vehicle/usedByMultipleVehicleList 及全部行为函数原样保留），
 *     Horizontal/Vertical 仪表样式与本部件的既有消费点无需改动
 * 上游原文位置：src/FlightMap/Widgets/QGCCompassWidget.qml
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    id:     root
    width:  size
    height: size
    opacity:        vehicle && usedByMultipleVehicleList && !vehicle.armed ? 0.5 : 1

    property real size:                         _defaultSize
    property var  vehicle:                      null
    property bool usedByMultipleVehicleList:    false

    property real _defaultSize:                 usedByMultipleVehicleList ? ScreenTools.defaultFontPixelHeight * 3 : ScreenTools.defaultFontPixelHeight * 10
    property real _sizeRatio:                   (usedByMultipleVehicleList || ScreenTools.isTinyScreen) ? (size / _defaultSize) * 0.5 : size / _defaultSize
    property int  _fontSize:                    ScreenTools.defaultFontPointSize * _sizeRatio < 8 ? 8 : ScreenTools.defaultFontPointSize * _sizeRatio
    property real _heading:                     vehicle ? vehicle.heading.rawValue : 0
    property real _headingToHome:               vehicle ? vehicle.headingToHome.rawValue : 0
    property real _groundSpeed:                 vehicle ? vehicle.groundSpeed.rawValue : 0
    property real _headingToNextWP:             vehicle ? vehicle.headingToNextWP.rawValue : 0
    property real _courseOverGround:            vehicle ? vehicle.gps.courseOverGround.rawValue : 0
    property var  _flyViewSettings:             QGroundControl.settingsManager.flyViewSettings
    property bool _showAdditionalIndicators:    _flyViewSettings.showAdditionalIndicatorsCompass.value && !usedByMultipleVehicleList
    property bool _lockNoseUpCompass:           _flyViewSettings.lockNoseUpCompass.value && !usedByMultipleVehicleList

    // ZGC: 现代罗盘绘制参数——指针/方位字母几何与品牌红 — ZFYZ-30
    property var  _qgcPal:                      QGroundControl.globalPalette
    property color _brandingColor:              "#d94232"
    property real _cardinalOffsetRadius:        (width / 2) - (ScreenTools.defaultFontPixelHeight * 0.9)
    property real _needleHalfWidth:             width * 0.085
    property real _needleTipInset:              width * 0.08

    function showCOG(){
        if (_groundSpeed < 0.5) {
            return false
        } else{
            return vehicle && _showAdditionalIndicators
        }
    }

    function showHeadingHome() {
        return vehicle && _showAdditionalIndicators && !isNaN(_headingToHome)
    }

    function showHeadingToNextWP() {
        return vehicle && _showAdditionalIndicators && !isNaN(_headingToNextWP)
    }

    function translateCenterToAngleX(radius, angle) {
        return radius * Math.sin(angle * (Math.PI / 180))
    }

    function translateCenterToAngleY(radius, angle) {
        return -radius * Math.cos(angle * (Math.PI / 180))
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    Connections {
        target:                                 _qgcPal
        function onGlobalThemeChanged() { needleCanvas.requestPaint() }
    }

    // 表盘底盘与细线圆环（替代上游硬描边实心圆盘）
    Rectangle {
        anchors.fill:       parent
        radius:             width / 2
        color:              qgcPal.button
        border.color:       qgcPal.windowShadeLight
        border.width:       1
    }

    Item {
        id:             rotationParent
        anchors.fill:   parent
        rotation:       _lockNoseUpCompass ? -_heading : 0

        // 方位字母（N 品牌红加粗，其余弱化；去机械刻度，仅保留方位感）
        Repeater {
            model: [ { label: "N", angle: 0 }, { label: "E", angle: 90 }, { label: "S", angle: 180 }, { label: "W", angle: 270 } ]

            delegate: QGCLabel {
                required property var modelData

                anchors.centerIn:   parent
                text:               modelData.label
                font.pointSize:     _fontSize * 0.8
                font.bold:          modelData.label === "N"
                color:              modelData.label === "N" ? root._brandingColor : root._qgcPal.colorGrey
                rotation:           _lockNoseUpCompass ? _heading : 0

                transform: Translate {
                    x:  root.translateCenterToAngleX(root._cardinalOffsetRadius, modelData.angle)
                    y:  root.translateCenterToAngleY(root._cardinalOffsetRadius, modelData.angle)
                }
            }
        }

        // 双色现代指针：北半品牌红、南半中性灰，尾部内凹风筝形
        Canvas {
            id:                 needleCanvas
            anchors.fill:       parent
            antialiasing:       true

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2
                var cy = height / 2
                var hw = root._needleHalfWidth
                var tip = root._needleTipInset
                ctx.fillStyle = root._brandingColor
                ctx.beginPath()
                ctx.moveTo(cx, tip)
                ctx.lineTo(cx + hw, cy)
                ctx.lineTo(cx, cy + hw)
                ctx.lineTo(cx - hw, cy)
                ctx.closePath()
                ctx.fill()
                ctx.fillStyle = root._qgcPal.colorGrey
                ctx.beginPath()
                ctx.moveTo(cx, height - tip)
                ctx.lineTo(cx + hw, cy)
                ctx.lineTo(cx, cy - hw)
                ctx.lineTo(cx - hw, cy)
                ctx.closePath()
                ctx.fill()
            }

            transform: Rotation {
                origin.x:   needleCanvas.width / 2
                origin.y:   needleCanvas.height / 2
                angle:      _heading
            }
        }

        Image {
            id:                 cogPointer
            source:             "/qmlimages/cOGPointer.svg"
            mipmap:             true
            fillMode:           Image.PreserveAspectFit
            anchors.fill:       parent
            sourceSize.height:  parent.height
            visible:            showCOG()
            rotation:           _courseOverGround
        }

        Image {
            id:                 nextWPPointer
            source:             "/qmlimages/compassDottedLine.svg"
            mipmap:             true
            fillMode:           Image.PreserveAspectFit
            anchors.fill:       parent
            sourceSize.height:  parent.height
            visible:            showHeadingToNextWP()
            rotation:           _headingToNextWP
        }

        // Launch location indicator
        Rectangle {
            width:              Math.max(label.contentWidth, label.contentHeight)
            height:             width
            color:              qgcPal.mapIndicator
            radius:             width / 2
            anchors.centerIn:   parent
            visible:            showHeadingHome()

            QGCLabel {
                id:                 label
                text:               qsTr("L")
                font.bold:          true
                color:              qgcPal.text
                anchors.centerIn:   parent
                rotation:           _lockNoseUpCompass ? _heading : 0
            }

            transform: Translate {
                property double _angle:        _headingToHome
                property real   _labelOffset:  root.width / 2 + ScreenTools.defaultFontPixelHeight / 2

                x: root.translateCenterToAngleX(_labelOffset, _angle)
                y: root.translateCenterToAngleY(_labelOffset, _angle)
            }
        }
    }

    // 航向读数胶囊徽章（数据层级：航向为主读数）
    Rectangle {
        id:                     headingPill
        anchors.horizontalCenter: parent.horizontalCenter
        y:                      parent.height * 0.72
        width:                  headingLabel.contentWidth + (_fontSize * 1.5)
        height:                 headingLabel.contentHeight + (ScreenTools.defaultFontPixelHeight / 3)
        radius:                 height / 2
        color:                  qgcPal.textField
        border.color:           qgcPal.windowShadeLight
        border.width:           1
        visible:                vehicle && !usedByMultipleVehicleList

        QGCLabel {
            id:                 headingLabel
            anchors.centerIn:   parent
            text:               vehicle ? _heading.toFixed(0) + "°" : ""
            font.pointSize:     _fontSize
            font.bold:          true
            color:              qgcPal.textFieldText
        }
    }
}
