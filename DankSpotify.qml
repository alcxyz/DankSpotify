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
    property string _currentArtist: ""
    property string _playerStatus: ""
    property string _busName: ""

    signal itemsChanged

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData(pluginId, "trigger", "~");
        playerName = pluginService.loadPluginData(pluginId, "playerName", "ncspot");
        terminal = pluginService.loadPluginData(pluginId, "terminal", "foot");
        discoverBus();
    }

    property Timer refreshTimer: Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: root.discoverBus()
    }

    // Step 1: discover the MPRIS bus name for the configured player
    function discoverBus() {
        busDiscoveryProcess.running = true;
    }

    property Process busDiscoveryProcess: Process {
        running: false
        command: ["sh", "-c", "busctl --user list --no-pager 2>/dev/null | grep -oP 'org\\.mpris\\.MediaPlayer2\\." + root.playerName + "\\S*'"]

        stdout: StdioCollector {
            onStreamFinished: {
                var name = text.trim().split("\n")[0] || "";
                if (name !== root._busName) {
                    root._busName = name;
                }
                if (root._busName)
                    root.refreshStatus();
                else {
                    root._playerStatus = "";
                    root._currentTrack = "";
                    root._currentArtist = "";
                    root.itemsChanged();
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root._busName = "";
                root._playerStatus = "";
                root._currentTrack = "";
                root._currentArtist = "";
            }
        }
    }

    // Step 2: fetch metadata via dbus properties
    function refreshStatus() {
        if (!_busName)
            return;
        statusProcess.command = [
            "sh", "-c",
            "status=$(busctl --user get-property '" + _busName + "' /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player PlaybackStatus 2>/dev/null | sed 's/^s \"//;s/\"$//');" +
            "meta=$(busctl --user get-property '" + _busName + "' /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Metadata 2>/dev/null);" +
            "title=$(echo \"$meta\" | grep -oP '\"xesam:title\"\\s+s\\s+\"\\K[^\"]+');" +
            "artist=$(echo \"$meta\" | grep -oP '\"xesam:artist\"\\s+as\\s+\\d+\\s+\"\\K[^\"]+');" +
            "printf '%s\\t%s\\t%s' \"$status\" \"$title\" \"$artist\""
        ];
        statusProcess.running = true;
    }

    property Process statusProcess: Process {
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim();
                if (line.length === 0) {
                    root._playerStatus = "";
                    root._currentTrack = "";
                    root._currentArtist = "";
                    root.itemsChanged();
                    return;
                }
                var parts = line.split("\t");
                root._playerStatus = parts[0] || "";
                root._currentTrack = parts[1] || "";
                root._currentArtist = parts[2] || "";
                root.itemsChanged();
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root._playerStatus = "";
                root._currentTrack = "";
                root._currentArtist = "";
            }
        }
    }

    function mprisCall(method) {
        if (!_busName)
            return;
        Quickshell.execDetached(["busctl", "--user", "call", _busName,
            "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", method]);
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
                categories: ["Spotify"],
                _preScored: 1000
            });
        }

        // Current playback info
        if (_currentTrack) {
            var statusIcon = _playerStatus === "Playing" ? "material:pause_circle" : "material:play_circle";
            var trackDisplay = _currentTrack + (_currentArtist ? " - " + _currentArtist : "");
            results.push({
                name: trackDisplay,
                icon: statusIcon,
                comment: _playerStatus || "Unknown",
                action: "toggle:",
                categories: ["Spotify"],
                _preScored: 1000
            });
        }

        // Playback controls
        results.push({
            name: "Play / Pause",
            icon: "material:play_pause",
            comment: "Toggle playback",
            action: "toggle:",
            categories: ["Spotify"],
            _preScored: 1000
        });
        results.push({
            name: "Next Track",
            icon: "material:skip_next",
            comment: "Skip to next",
            action: "next:",
            categories: ["Spotify"],
            _preScored: 1000
        });
        results.push({
            name: "Previous Track",
            icon: "material:skip_previous",
            comment: "Go to previous",
            action: "prev:",
            categories: ["Spotify"],
            _preScored: 1000
        });
        results.push({
            name: "Open " + playerName,
            icon: "material:open_in_new",
            comment: "Launch in terminal",
            action: "launch:",
            categories: ["Spotify"],
            _preScored: 1000
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
            mprisCall("PlayPause");
            break;
        case "next":
            mprisCall("Next");
            break;
        case "prev":
            mprisCall("Previous");
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
            discoverBus();
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
