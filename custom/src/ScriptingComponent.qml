/****************************************************************************
 * ZGC 覆盖层：脚本文件条目 chip 图标 on-red token 显式化
 * 同路径覆盖上游 qml/QGroundControl/AutoPilotPlugins/Common/ScriptingComponent.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：ZFYZ-69 修复轮（红上红缺陷链 · P2 #11）。文件条目 chip 恒 buttonHighlight 红底，
 * chip 上下载/删除两图标着 `button.textColor`——该值经 custom QGCButton.qml:93 高亮绑定
 * 在 checked（图标可见态）下已解析为白色，视觉无缺陷；但把「红底上的前景」间接寄托在
 * 内嵌按钮态色上有脆弱性（QGCButton 状态逻辑一旦调整即回退为深色落红底）。
 * 按初审裁决把红底态前景统一显式钉到 buttonHighlightText：
 *   - downloadIcon/deleteIcon：color: button.textColor → qgcPal.buttonHighlightText
 * 视觉零变化（白→白），接口与布局逐行不变。§4.2 #11 的核实结论见交付报告。
 * 上游原文位置：src/AutoPilotPlugins/Common/ScriptingComponent.qml
 * 本覆盖件为散文件加载：所用类型 SetupPage/QGCFileDialog 等均属 QGroundControl.Controls、
 * FTPController/FactPanelController 属根模块 QGroundControl，沿用上游 import 列表即可。
 * 消费点：Analyze → Scripting 页（高级页）
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SetupPage {
    id:             scriptingPage
    pageComponent:  pageComponent

    Component {
        id: pageComponent

        ColumnLayout {
            id: root
            width: availableWidth
            spacing: ScreenTools.defaultFontPixelHeight * 0.75

            readonly property string scriptRoot: "/APM/scripts/"
            readonly property var luaNameFilters: [ qsTr("Lua Scripts (*.lua)"), qsTr("All Files (*)") ]
            readonly property Fact scriptingEnabledFact: factController.getParameterFact(-1, "SCR_ENABLE", false)

            readonly property var filteredEntries: {
                let rawEntries = ftpController.directoryEntries.filter(function(entry) {
                    if (!entry || entry.length < 2) {
                        return false
                    }
                    var kind = entry.charAt(0)
                    if (kind === "F") {
                        return true
                    }
                    return false
                })
                let filenameEntries = []
                for (let i=0; i<rawEntries.length; i++) {
                    filenameEntries.push(rawEntries[i].slice(1).split("\t")[0])
                }
                return filenameEntries
            }

            function fullRemotePath(filename) {
                return scriptRoot + filename
            }

            function fileNameFromPath(path) {
                if (!path) {
                    return ""
                }
                // Handle both forward slashes and backslashes
                var normalizedPath = path.replace(/\\/g, "/")
                var parts = normalizedPath.split("/")
                return parts[parts.length - 1]
            }

            function refreshDirectoryList() {
                ftpController.listDirectory(scriptRoot)
            }

            Component.onCompleted: {
                if (scriptingEnabledFact && scriptingEnabledFact.rawValue) {
                    ftpController.listDirectory(root.scriptRoot)
                }
            }

            Connections {
                target: scriptingEnabledFact

                onRawValueChanged: {
                    if (scriptingEnabledFact.rawValue) {
                        ftpController.listDirectory(root.scriptRoot)
                    } else {
                        statusText.text = ""
                    }
                }
            }

            FTPController {
                id: ftpController

                onUploadComplete: (remotePath, error) => {
                    if (error.length > 0) {
                        statusText.text = error
                    } else {
                        statusText.text = qsTr("Upload succeeded: %1").arg(remotePath)
                        refreshDirectoryList()
                    }
                }

                onDownloadComplete: (filePath, error) => {
                    if (error.length > 0) {
                        statusText.text = error
                    } else {
                        statusText.text = qsTr("Download succeeded: %1").arg(filePath)
                    }
                }

                onDeleteComplete: (remotePath, error) => {
                    if (error.length > 0) {
                        statusText.text = error
                    } else {
                        statusText.text = qsTr("Delete succeeded: %1").arg(remotePath)
                        refreshDirectoryList()
                    }
                }
            }

            FactPanelController {
                id: factController
            }

            QGCPalette { id: qgcPal; colorGroupEnabled: true }

            FactCheckBoxSlider {
                text: qsTr("Enable Scripting")
                fact: scriptingEnabledFact
                enabled: scriptingEnabledFact !== null
            }

            QGCLabel {
                id: statusText
                Layout.fillWidth: true
                text: ftpController.errorString
                wrapMode: Text.Wrap
            }

            Flow {
                id: directoryView
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelHeight
                enabled: !ftpController.busy && scriptingEnabledFact && scriptingEnabledFact.rawValue

                QGCButton {
                    text: qsTr("Upload")
                    iconSource: "/res/Upload.svg"
                    enabled: !ftpController.busy
                    onClicked: {
                        uploadDialog.folder = QGroundControl.settingsManager.appSettings.missionSavePath
                        uploadDialog.openForLoad()
                    }
                }

                Repeater {
                    model: root.filteredEntries

                    Rectangle {
                        width: button.checked ? deleteIcon.x + deleteIcon.width + button.rightPadding : button.width
                        height: button.height
                        radius: button.backRadius
                        border.width: button.showBorder ? 1 : 0
                        border.color: button.background.border.color
                        color: qgcPal.buttonHighlight

                        QGCColoredImage {
                            id: downloadIcon
                            anchors.leftMargin: button.leftPadding
                            anchors.left: parent.left
                            anchors.verticalCenter: button.verticalCenter
                            width: height
                            height: button._iconHeight
                            fillMode: Image.PreserveAspectFit
                            source: "/res/Download.svg"
                            color: qgcPal.buttonHighlightText // ZGC: chip 红底前景显式钉 on-red token（原 button.textColor 间接态色，可见态下同为白，消脆弱依赖）— ZFYZ-69
                            visible: button.checked

                            QGCMouseArea {
                                fillItem: parent
                                onClicked: {
                                    downloadDialog.defaultSuffix = "lua"
                                    downloadDialog.title = qsTr("Download %1").arg(modelData)
                                    downloadDialog.fileToDownload = modelData
                                    downloadDialog.folder = QGroundControl.settingsManager.appSettings.missionSavePath
                                    downloadDialog.openForLoad()
                                }
                            }
                        }

                        QGCButton {
                            id: button
                            anchors.left: checked ? downloadIcon.right : parent.left
                            text: modelData
                            checkable: true
                        }

                        QGCColoredImage {
                            id: deleteIcon
                            anchors.left: button.right
                            anchors.verticalCenter: button.verticalCenter
                            width: height
                            height: button._iconHeight
                            fillMode: Image.PreserveAspectFit
                            source: "/res/TrashCan.svg"
                            color: qgcPal.buttonHighlightText // ZGC: chip 红底前景显式钉 on-red token（原 button.textColor 间接态色，可见态下同为白，消脆弱依赖）— ZFYZ-69
                            visible: button.checked

                            QGCMouseArea {
                                fillItem: parent
                                onClicked: {
                                    var confirm = qsTr("Are you sure you want to delete the script \"%1\"? This action cannot be undone.").arg(modelData)
                                    QGroundControl.showMessageDialog(scriptingPage, qsTr("Delete Lua Script"), confirm, Dialog.Ok | Dialog.Cancel, function() {
                                        var remotePath = root.fullRemotePath(modelData)
                                        if (!ftpController.deleteFile(remotePath)) {
                                            var deleteError = ftpController.errorString.length > 0 ? ftpController.errorString : qsTr("Delete failed")
                                            QGroundControl.showMessageDialog(scriptingPage, qsTr("Lua Delete"), deleteError)
                                        }
                                    })
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelHeight * 0.5

                QGCButton {
                    text: qsTr("Cancel Operation")
                    visible: ftpController.busy
                    onClicked: ftpController.cancelActiveOperation()
                }

                Item { Layout.fillWidth: true }

                QGCLabel {
                    text: qsTr("Transferring... %1%" ).arg(Math.round(ftpController.progress * 100))
                    visible: ftpController.busy
                }
            }

            QGCFileDialog {
                id: uploadDialog
                title: qsTr("Select Lua script to upload")
                nameFilters: root.luaNameFilters

                onAcceptedForLoad: (file) => {
                    if (!file) {
                        close()
                        return
                    }
                    var fileName = root.fileNameFromPath(file)
                    if (fileName.length === 0) {
                        close()
                        return
                    }
                    if (!fileName.toLowerCase().endsWith(".lua")) {
                        fileName = fileName + ".lua"
                    }
                    var remotePath = root.fullRemotePath(fileName)
                    if (!ftpController.uploadFile(file, remotePath)) {
                        var uploadError = ftpController.errorString.length > 0 ? ftpController.errorString : qsTr("Upload failed")
                        QGroundControl.showMessageDialog(scriptingPage, qsTr("Lua Upload"), uploadError)
                    }
                    close()
                }
            }

            QGCFileDialog {
                id: downloadDialog
                title: qsTr("Save Lua Script")
                nameFilters: root.luaNameFilters
                selectFolder: true

                property string fileToDownload

                onAcceptedForLoad: (folder) => {
                    if (!folder) {
                        close()
                        return
                    }
                    if (!ftpController.downloadFile(root.fullRemotePath(fileToDownload), folder, fileToDownload)) {
                        var downloadError = ftpController.errorString.length > 0 ? ftpController.errorString : qsTr("Download failed")
                        QGroundControl.showMessageDialog(scriptingPage, qsTr("Lua Download"), downloadError)
                    }
                    close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: availableHeight
                color: qgcPal.window
                visible: scriptingEnabledFact === null

                QGCLabel {
                    anchors.centerIn: parent
                    text: qsTr("Scripting is not supported by this version of firmware.")
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
