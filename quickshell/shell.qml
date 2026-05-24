//@ pragma UseQApplication
import Quickshell
import QtQuick
import QtQuick.Controls.Material

import qs.modules.bars
import qs.modules.bars.components
import qs.common.components
import qs.modules.panels

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
                    panelController: panelCtrl
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

                PanelController {
                    id: panelCtrl
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
