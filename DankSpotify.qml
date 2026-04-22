import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string pluginId: "dankSpotify"
    property string trigger: "~"
    property string playerName: "ncspot"
    property string terminal: "foot"
    property string _currentTrack: ""
    property string _playerStatus: ""

    signal itemsChanged

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData(pluginId, "trigger", "~");
        playerName = pluginService.loadPluginData(pluginId, "playerName", "ncspot");
        terminal = pluginService.loadPluginData(pluginId, "terminal", "foot");
        refreshStatus();
    }

    property Timer refreshTimer: Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: root.refreshStatus()
    }

    function refreshStatus() {
        statusProcess.running = true;
    }

    property Process statusProcess: Process {
        running: false
        command: ["playerctl", "-p", root.playerName, "metadata", "--format", "{{status}}\t{{title}}\t{{artist}}\t{{album}}"]

        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim();
                if (line.length === 0) {
                    root._playerStatus = "";
                    root._currentTrack = "";
                    root.itemsChanged();
                    return;
                }
                var parts = line.split("\t");
                root._playerStatus = parts[0] || "";
                var title = parts[1] || "";
                var artist = parts[2] || "";
                root._currentTrack = title + (artist ? " - " + artist : "");
                root.itemsChanged();
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root._playerStatus = "";
                root._currentTrack = "";
            }
        }
    }

    function getItems(query) {
        var results = [];

        if (query && query.trim().length > 0) {
            var searchQuery = query.trim();
            results.push({
                name: "Search: " + searchQuery,
                icon: "material:search",
                comment: "Open " + playerName + " and search",
                action: "search:" + searchQuery,
                categories: ["Spotify"]
            });
        }

        // Current playback info
        if (_currentTrack) {
            var statusIcon = _playerStatus === "Playing" ? "material:pause_circle" : "material:play_circle";
            results.push({
                name: _currentTrack,
                icon: statusIcon,
                comment: _playerStatus || "Unknown",
                action: "toggle:",
                categories: ["Spotify"]
            });
        }

        // Playback controls
        results.push({
            name: "Play / Pause",
            icon: "material:play_pause",
            comment: "Toggle playback",
            action: "toggle:",
            categories: ["Spotify"]
        });
        results.push({
            name: "Next Track",
            icon: "material:skip_next",
            comment: "Skip to next",
            action: "next:",
            categories: ["Spotify"]
        });
        results.push({
            name: "Previous Track",
            icon: "material:skip_previous",
            comment: "Go to previous",
            action: "prev:",
            categories: ["Spotify"]
        });
        results.push({
            name: "Open " + playerName,
            icon: "material:open_in_new",
            comment: "Launch in terminal",
            action: "launch:",
            categories: ["Spotify"]
        });

        return results;
    }

    function executeItem(item) {
        if (!item?.action)
            return;
        var colonIdx = item.action.indexOf(":");
        if (colonIdx === -1)
            return;
        var actionType = item.action.substring(0, colonIdx);
        var actionData = item.action.substring(colonIdx + 1);

        switch (actionType) {
        case "toggle":
            Quickshell.execDetached(["playerctl", "-p", playerName, "play-pause"]);
            break;
        case "next":
            Quickshell.execDetached(["playerctl", "-p", playerName, "next"]);
            break;
        case "prev":
            Quickshell.execDetached(["playerctl", "-p", playerName, "previous"]);
            break;
        case "launch":
            Quickshell.execDetached([terminal, playerName]);
            break;
        case "search":
            launchAndSearch(actionData);
            break;
        }

        // Refresh status after a short delay
        Qt.callLater(function() {
            refreshTimer.restart();
            refreshStatus();
        });
    }

    function launchAndSearch(query) {
        // Launch ncspot in terminal, wait briefly, then type the search
        Quickshell.execDetached([terminal, playerName]);

        // Use a delayed wtype sequence to search
        // F2 opens global search in ncspot, then type query and press Enter
        searchTimer.searchQuery = query;
        searchTimer.start();
    }

    property Timer searchTimer: Timer {
        property string searchQuery: ""
        interval: 800
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["wtype", "-k", "F2"]);
            typeTimer.searchQuery = searchQuery;
            typeTimer.start();
        }
    }

    property Timer typeTimer: Timer {
        property string searchQuery: ""
        interval: 200
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["wtype", "-s", "10", searchQuery]);
            enterTimer.start();
        }
    }

    property Timer enterTimer: Timer {
        interval: 200
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["wtype", "-M", "shift", "-P", "enter", "-m", "shift"]);
        }
    }

    onTriggerChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData(pluginId, "trigger", trigger);
    }

    onPlayerNameChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData(pluginId, "playerName", playerName);
    }

    onTerminalChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData(pluginId, "terminal", terminal);
    }
}
