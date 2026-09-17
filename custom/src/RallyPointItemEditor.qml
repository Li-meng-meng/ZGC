/****************************************************************************
 * ZGC 覆盖层：规划点编辑卡选中态前景反白
 * 同路径覆盖上游 qml/QGroundControl/PlanView/RallyPointItemEditor.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：ZFYZ-69 修复轮（红上红缺陷链 · P2 #8）。选中卡底色为 buttonHighlight（志翔红），
 * 上游 _outerTextColor 恒 qgcPal.text（深色）——选中卡标题/删除图标深字落红底。同族
 * MissionItemEditor.qml:32 已是状态驱动反白（_currentItem ? buttonHighlightText : text），
 * 上游自身不一致（调研报告 §4.2 #8 对照证据）。本覆盖对齐该写法，仅一处：
 *   - _outerTextColor → _currentItem ? qgcPal.buttonHighlightText : qgcPal.text
 * 未选中态（windowShade 底）与数值区（windowShadeDark 底）不受影响，接口不变。
 * 上游原文位置：src/PlanView/RallyPointItemEditor.qml
 * 消费点：Plan 视图 Rally 点编辑卡（RallyPointEditorLoader）
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id: root
    height: _currentItem ? valuesRect.y + valuesRect.height + _innerMargin : titleLayout.y + titleLayout.height + _margin
    color: _currentItem ? qgcPal.buttonHighlight : qgcPal.windowShade
    radius: _radius

    property var rallyPoint ///< RallyPoint object associated with editor
    property var controller ///< RallyPointController

    property bool _currentItem: rallyPoint ? rallyPoint === controller.currentRallyPoint : false
    property color _outerTextColor: _currentItem ? qgcPal.buttonHighlightText : qgcPal.text // ZGC: 选中卡红底态前景反白，对齐同族 MissionItemEditor.qml 写法（原恒 qgcPal.text 深色落红底）— ZFYZ-69

    readonly property real _margin: ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _innerMargin: 2
    readonly property real _radius: ScreenTools.defaultFontPixelWidth / 2
    readonly property real _titleHeight: ScreenTools.implicitComboBoxHeight + ScreenTools.defaultFontPixelWidth

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    RowLayout {
        id: titleLayout
        anchors.margins: _margin
        anchors.left: parent.left
        anchors.rightMargin: _margin * 2
        anchors.right: parent.right
        height: _titleHeight
        spacing: ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text: qsTr("Rally Point")
            color: _outerTextColor
        }

        QGCColoredImage {
            id: deleteButton
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.5
            Layout.preferredHeight: Layout.preferredWidth
            source: "/res/XDelete.svg"
            color: _outerTextColor
        }
    }

    QGCMouseArea {
        id: selectMouseArea
        anchors.top: titleLayout.top
        anchors.bottomMargin: -_margin
        anchors.bottom: titleLayout.bottom
        anchors.left: titleLayout.left
        anchors.right: titleLayout.right
        onClicked: {
            if (mainWindow.allowViewSwitch()) {
                controller.currentRallyPoint = rallyPoint
            }
        }
    }

    QGCMouseArea {
        anchors.top: selectMouseArea.top
        anchors.bottom: selectMouseArea.bottom
        anchors.right: selectMouseArea.right
        width: height
        onClicked: {
            if (mainWindow.allowViewSwitch()) {
                controller.removePoint(rallyPoint)
            }
        }
    }

    Rectangle {
        id: valuesRect
        anchors.margins: _innerMargin
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleLayout.bottom
        height: valuesLayout.height + (_margin * 2)
        color: qgcPal.windowShadeDark
        visible: _currentItem
        radius: _radius

        ColumnLayout {
            id: valuesLayout
            anchors.margins: _margin
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: _margin

            Repeater {
                model: rallyPoint ? rallyPoint.textFieldFacts : 0

                LabelledFactTextField {
                    Layout.fillWidth: true
                    label: modelData.shortDescription
                    fact: modelData
                }
            }
        }
    }
}
