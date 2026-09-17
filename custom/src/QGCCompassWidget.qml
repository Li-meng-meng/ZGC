/****************************************************************************
 * ZGC 覆盖层：罗盘起飞点「L」标前景反白
 * 同路径覆盖上游 qml/QGroundControl/FlightMap/Widgets/QGCCompassWidget.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：ZFYZ-69 修复轮（红上红缺陷链 · P2 #9）。Home「L」标圆点恒 mapIndicator（志翔红），
 * 上游「L」文字着 qgcPal.text（深色）落红点，常驻小元素不可辨（调研报告 §4.2 #9）。
 * 仅一处前景 token 变更：「L」→ primaryButtonText（白）。
 * 注意（ZFYZ-35 回退边界）：成员裁决回退的是 B 项「Fly 仪表卡片化」覆盖副本——本件
 * 与该回退无关，罗盘表盘/指针/刻度全部上游原样，仅改「L」标一个文字色。
 * 本覆盖件为散文件加载，不享有 FlightMap 模块隐式导入——CompassDial/
 * CompassHeadingIndicator 为 FlightMap 模块内类型，须显式 import（同 MainStatusIndicator
 * 覆盖件 A4 门禁教训，ZFYZ-30）。
 * 上游原文位置：src/FlightMap/Widgets/QGCCompassWidget.qml
 * 消费点：Fly 视图主罗盘、多机列表小罗盘
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap // ZGC: 覆盖件散文件加载无 FlightMap 模块隐式导入，CompassDial/CompassHeadingIndicator 需显式导入 — ZFYZ-69

Rectangle {
    id:     root
    width:  size
    height: size
    radius: width / 2
    color:  qgcPal.window
    border.color:   qgcPal.text
    border.width:   usedByMultipleVehicleList ? 1 : 0
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

    Item {
        id:             rotationParent
        anchors.fill:   parent
        rotation:           _lockNoseUpCompass ? -_heading : 0

        CompassDial {
            anchors.fill:   parent
            visible:        !usedByMultipleVehicleList
        }

        CompassHeadingIndicator {
            compassSize:    size
            heading:        _heading
            simplified:     usedByMultipleVehicleList
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
                color:              qgcPal.primaryButtonText // ZGC: 「L」落 mapIndicator 红点上，前景反白（原 qgcPal.text 深色落红底）— ZFYZ-69
                anchors.centerIn:   parent
                rotation:           _lockNoseUpCompass ? _heading : 0
            }

            transform: Translate {
                property double _angle:        _headingToHome
                property real   _labelOffset:  root.width / 2 + ScreenTools.defaultFontPixelHeight / 2

                x: translateCenterToAngleX(_labelOffset, _angle)
                y: translateCenterToAngleY(_labelOffset, _angle)
            }
        }
    }

    QGCLabel {
        anchors.horizontalCenter:   parent.horizontalCenter
        y:                          size * 0.74
        text:                       vehicle && !usedByMultipleVehicleList ? _heading.toFixed(0) + "°" : ""
        horizontalAlignment:        Text.AlignHCenter
    }
}
