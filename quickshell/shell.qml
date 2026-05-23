//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls.Material

import qs.common
import qs.common.bars
import qs.common.bars.components
import qs.common.components
import qs.common.services
import "common" as Common

import qs.modules.wallpaper

ShellRoot {
    id: root

    Material.theme: Material.Dark
    Material.accent: Material.Purple

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Item {
                required property var modelData

                TopBar {
                    id: topBar
                    screen: modelData
                    popupController: popupCtrl
                }
                // SideBar {
                //     screen: modelData
                // }
                TopRightCorner {
                    screen: modelData
                }
                TopLeftCorner {
                    screen: modelData
                }
                BottomLeftCorner {
                    screen: modelData
                }
                BottomRightCorner {
                    screen: modelData
                }

                Common.PopupController {
                    id: popupCtrl
                    screen: modelData
                }

                VolumeOSD {}

                WallpaperLayer {
                    screen: modelData
                }
            }
        }
    }
}
