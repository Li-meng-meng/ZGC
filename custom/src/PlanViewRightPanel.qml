/****************************************************************************
 * ZGC 覆盖层：Plan 右面板毛玻璃化（方案 H）
 * 同路径覆盖上游 qml/QGroundControl/PlanView/PlanViewRightPanel.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：A3-20260909-roundH-glass（ZFYZ-41）。仅视觉层变更，交互契约未动：
 *   - 背景：上游「qgcPal.window 纯色 × 0.85」矩形改为 MultiEffect 背景模糊（毛玻璃）：
 *     ShaderEffectSource 采样 editorMap 中面板正后方区域（visible:false 仅出纹理不显示原图；
 *     sourceRect 以面板 x/y/宽高直接表达——面板与 editorMap 同父同几何，收起/展开锚点翻转
 *     时 x 变化自动联动），MultiEffect 模糊后叠加 qgcPal.window 半透明（0.65）窗底色调和层
 *     保证文字对比度，零新增色值
 *   - 容器矩形（rightPanelBackground）透明化承载玻璃各层（模糊在下、色调在上）；
 *     autoPaddingEnabled:false 使模糊严格收敛于面板矩形内（blurMax 不外溢到面板外）
 *   - 收起/展开把手（toggleButtonRect）改为显式 qgcPal.window × 0.85（视觉同上游；原先引用
 *     rightPanelBackground.color/opacity 的取值随容器透明化改为显式值）
 *   - selectNextNotReady/selectLayer、面板开合交互、PlanTreeView 委托结构与上游逐行一致
 * 门禁修复记录（ZFYZ-49 1/3 轮 FAIL 退回，门禁 1/3 轮）：
 *   首版 import 块缺 QGroundControl.PlanView——PlanTreeView 为该模块成员，上游同目录隐式
 *   可见而散文件覆盖不可见，运行时 "PlanTreeView is not a type" 连锁 PlanView/MainWindow
 *   实例化失败、启动静默退出（smoke 3/3 失败）。修复：补显式 import（上游原文 import 集合
 *   + QtQuick.Effects + QGroundControl.PlanView，见下方 ZGC 标记）。
 * 上游原文位置：src/PlanView/PlanViewRightPanel.qml
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
// ZGC: 毛玻璃 MultiEffect——覆盖件散文件加载不享上游模块隐式导入，须显式声明 — ZFYZ-41
import QtQuick.Effects

import QGroundControl
import QGroundControl.Controls
// ZGC: 门禁 1/3 轮修复——PlanTreeView 为 QGroundControl.PlanView 模块成员（上游同目录
// 隐式可见，散文件覆盖加载必须显式 import，缺它运行时 "PlanTreeView is not a type"，
// 连锁 PlanView/MainWindow 无法实例化，启动静默退出）— ZFYZ-41
import QGroundControl.PlanView

Item {
    required property var editorMap
    required property var planMasterController

    signal editingLayerChangeRequested(int layer)

    id: root

    property var  _missionController: planMasterController.missionController
    property real _toolsMargin:       ScreenTools.defaultFontPixelWidth * 0.75

    function selectNextNotReady() {
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var vmi = _missionController.visualItems.get(i)
            if (vmi.readyForSaveState === VisualMissionItem.NotReadyForSaveData) {
                _missionController.setCurrentPlanViewSeqNum(vmi.sequenceNumber, true)
                break
            }
        }
    }

    QGCPalette { id: qgcPal }

    // ZGC: 毛玻璃背景容器——透明化承载「模糊层＋窗底色调和层」，替代上游纯色 0.85 矩形 — ZFYZ-41
    Rectangle {
        id:             rightPanelBackground
        anchors.fill:   parent
        color:          "transparent"   // ZGC: 容器透明化，玻璃各层见子件；把手取色改显式（见 toggleButtonRect）— ZFYZ-41

        // ZGC: 背后采样——面板与 editorMap 同父同几何，面板坐标即地图坐标；visible:false 仅出
        // 纹理供 MultiEffect 消费；live:true 随底层地图（交互/机位更新）实时刷新 — ZFYZ-41
        ShaderEffectSource {
            id:           panelBackdropSource
            anchors.fill: parent
            sourceItem:   root.editorMap
            sourceRect:   Qt.rect(root.x, root.y, root.width, root.height)
            visible:      false
            live:         true
            smooth:       true
        }

        // ZGC: 背景模糊——模糊半径保守中档（0.6 × blurMax 32px）；autoPaddingEnabled:false
        // 令效果矩形＝面板矩形，模糊边缘不外溢；地图线条/航点标记均化后不可辨 — ZFYZ-41
        MultiEffect {
            anchors.fill:       parent
            source:             panelBackdropSource
            autoPaddingEnabled: false
            blurEnabled:        true
            blur:               0.6
            blurMax:            32
            saturation:         0.1
        }

        // ZGC: 窗底色调和层——qgcPal.window 半透明 0.65（上游 0.85 → 毛玻璃化），浅/深两主题
        // 文字对比度达标，取色同上游零新增 — ZFYZ-41
        Rectangle {
            anchors.fill: parent
            color:        qgcPal.window
            opacity:      0.65
        }
    }


    // Open/Close panel
    Item {
        id:                     panelOpenCloseButton
        anchors.right:          parent.left
        anchors.verticalCenter: parent.verticalCenter
        width:                  toggleButtonRect.width - toggleButtonRect.radius
        height:                 toggleButtonRect.height
        clip:                   true

        property bool _expanded: root.anchors.right == root.parent.right

        Rectangle {
            id:             toggleButtonRect
            width:          ScreenTools.defaultFontPixelWidth * 2.25
            height:         width * 3
            radius:         ScreenTools.defaultBorderRadius
            color:          qgcPal.window   // ZGC: 显式取色替代 rightPanelBackground.color 引用（容器已透明化），视觉同上游 — ZFYZ-41
            opacity:        0.85            // ZGC: 显式透明度替代 rightPanelBackground.opacity 引用，视觉同上游 — ZFYZ-41

            QGCLabel {
                id:                 toggleButtonLabel
                anchors.centerIn:   parent
                text:               panelOpenCloseButton._expanded ? ">" : "<"
                color:              qgcPal.buttonText
            }

        }

        QGCMouseArea {
            anchors.fill: parent

            onClicked: {
                if (panelOpenCloseButton._expanded) {
                    // Close panel
                    root.anchors.right = undefined
                    root.anchors.left = root.parent.right
                } else {
                    // Open panel
                    root.anchors.left = undefined
                    root.anchors.right = root.parent.right
                }
            }
        }
    }

    //-------------------------------------------------------
    // Right Panel Controls
    Item {
        anchors.fill: rightPanelBackground

        DeadMouseArea {
            anchors.fill:   parent
        }

        PlanTreeView {
            id:                     planTreeView
            objectName:             "planView_planTree"
            anchors.fill:           parent
            editorMap:              root.editorMap
            planMasterController:   root.planMasterController
            onEditingLayerChangeRequested: (layer) => root.editingLayerChangeRequested(layer)
        }
    }

    function selectLayer(nodeType) {
        // Ensure panel is open
        if (!panelOpenCloseButton._expanded) {
            root.anchors.left = undefined
            root.anchors.right = root.parent.right
        }
        planTreeView.selectLayer(nodeType)
    }
}
