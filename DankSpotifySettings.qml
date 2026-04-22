import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankSpotify"

    StyledText {
        width: parent.width
        text: I18n.tr("Spotify Settings")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Control Spotify playback and search tracks")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: settingsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: settingsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: I18n.tr("Configuration")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StringSetting {
                settingKey: "trigger"
                label: I18n.tr("Trigger Prefix")
                description: I18n.tr("Type this prefix to control Spotify")
                placeholder: "~"
                defaultValue: "~"
            }

            StringSetting {
                settingKey: "playerName"
                label: I18n.tr("Player Name")
                description: I18n.tr("MPRIS player name for playerctl (e.g. ncspot, spotify, spotifyd)")
                placeholder: "ncspot"
                defaultValue: "ncspot"
            }

            StringSetting {
                settingKey: "terminal"
                label: I18n.tr("Terminal")
                description: I18n.tr("Terminal emulator for launching the player")
                placeholder: "foot"
                defaultValue: "foot"
            }
        }
    }

    StyledRect {
        width: parent.width
        height: infoColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: infoColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingM

                DankIcon {
                    name: "info"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: I18n.tr("Usage")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: I18n.tr("Type a query to search in ncspot.\nWithout a query, use playback controls.\n\nControls: play/pause, next, previous.\nShows current track when a player is active.\n\nRequires playerctl, ncspot, and wtype.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }
        }
    }
}
