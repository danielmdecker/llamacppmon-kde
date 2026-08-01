import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ---- state ----
    property var runningModels: []          // last parsed /running result (JS array)
    property string errorText: ""           // non-empty when the server is unreachable
    property double ramTotalKb: 0           // /proc/meminfo, KiB
    property double ramAvailKb: 0
    property double vramTotalKb: 0          // amdgpu sysfs, KiB (0 = unknown)
    property double vramUsedKb: 0

    // Per-port process memory cache so list entries keep their numbers between
    // the model refresh and the (slower) per-process memory refresh.
    property var memCache: ({})

    readonly property double vramAvailKb: Math.max(0, vramTotalKb - vramUsedKb)
    readonly property int loadedCount: runningModels.length

    // Expose the view model to the full representation.
    property alias listModel: modelListModel

    // Bundled round llama icon (no icon theme ships one).
    readonly property url llamaIcon: Qt.resolvedUrl("../icons/llamacpp.svg")

    Plasmoid.icon: llamaIcon
    Plasmoid.title: i18n("Llama.cpp Monitor")
    toolTipMainText: i18n("Llama.cpp Monitor")
    toolTipSubText: {
        if (errorText.length > 0) {
            return errorText
        }
        var s = i18np("%1 model loaded", "%1 models loaded", loadedCount)
        if (vramTotalKb > 0) {
            s += "\n" + i18n("VRAM: %1 free of %2", formatKb(vramAvailKb), formatKb(vramTotalKb))
        }
        if (ramTotalKb > 0) {
            s += "\n" + i18n("RAM: %1 free of %2", formatKb(ramAvailKb), formatKb(ramTotalKb))
        }
        return s
    }

    preferredRepresentation: compactRepresentation

    ListModel { id: modelListModel }

    // ---- command execution (Plasma 6 executable engine) ----
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        property var callbacks: ({})

        onNewData: function (sourceName, data) {
            var cb = callbacks[sourceName]
            delete callbacks[sourceName]
            disconnectSource(sourceName)
            if (cb) {
                cb(data["stdout"] || "", data["stderr"] || "", data["exit code"])
            }
        }

        // Run `cmd` once; `cb(stdout, stderr, exitCode)` is optional (null = fire and forget).
        function run(cmd, cb) {
            if (cb) {
                callbacks[cmd] = cb
            }
            connectSource(cmd)
        }
    }

    // ---- helpers ----
    function serverUrl() {
        var u = Plasmoid.configuration.serverUrl || "http://127.0.0.1:8090"
        return u.replace(/\/+$/, "")
    }

    // POSIX single-quote a string for safe embedding in a shell command.
    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    // Human-readable size from KiB.
    function formatKb(kb) {
        if (kb >= 1048576) {
            return i18n("%1 GiB", (kb / 1048576).toFixed(1))
        }
        if (kb >= 1024) {
            return i18n("%1 MiB", Math.round(kb / 1024))
        }
        return i18n("%1 KiB", Math.round(kb))
    }

    // ---- data refresh ----
    function refresh() {
        refreshModels()
        refreshMemory()
    }

    // Query llama-swap for the models currently loaded (state "starting"/"ready").
    function refreshModels() {
        executable.run("curl -sf --max-time 3 " + shQuote(serverUrl() + "/running"),
            function (stdout, stderr, code) {
                if (code !== 0) {
                    root.errorText = i18n("Cannot reach llama-swap at %1", serverUrl())
                    root.runningModels = []
                    syncListModel()
                    return
                }
                var arr
                try {
                    arr = JSON.parse(stdout).running || []
                } catch (e) {
                    root.errorText = i18n("Unexpected response from %1", serverUrl())
                    return
                }
                root.errorText = ""
                var list = []
                for (var i = 0; i < arr.length; i++) {
                    var entry = arr[i]
                    // The per-model llama-server port, from the proxy URL; used to
                    // attribute process memory to the model.
                    var port = 0
                    var m = /:(\d+)\/?$/.exec(entry.proxy || "")
                    if (m) {
                        port = parseInt(m[1], 10)
                    }
                    list.push({
                        name: entry.model || "?",
                        modelState: entry.state || "",
                        port: port
                    })
                }
                root.runningModels = list
                syncListModel()
                if (root.expanded) {
                    fetchModelMemory()
                }
            })
    }

    // System-wide memory: RAM from /proc/meminfo, VRAM from amdgpu sysfs (bytes).
    function refreshMemory() {
        executable.run(
            "awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{printf \"ram %d %d\\n\", t, a}' /proc/meminfo; "
            + "for f in /sys/class/drm/card*/device/mem_info_vram_total; do "
            + "[ -r \"$f\" ] || continue; d=${f%/*}; "
            + "echo \"vram $(cat \"$f\") $(cat \"$d/mem_info_vram_used\")\"; done",
            function (stdout) {
                var vt = 0
                var vu = 0
                var lines = stdout.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/)
                    if (parts.length !== 3) {
                        continue
                    }
                    if (parts[0] === "ram") {
                        root.ramTotalKb = parseInt(parts[1], 10)
                        root.ramAvailKb = parseInt(parts[2], 10)
                    } else if (parts[0] === "vram") {
                        vt += parseInt(parts[1], 10) / 1024
                        vu += parseInt(parts[2], 10) / 1024
                    }
                }
                root.vramTotalKb = vt
                root.vramUsedKb = vu
            })
    }

    // Per-model memory: find each model's llama-server by its port, then read VRAM
    // and GTT from DRM fdinfo (deduplicated by drm-client-id) and RSS from /proc.
    function fetchModelMemory() {
        var script = ""
        for (var i = 0; i < runningModels.length; i++) {
            var port = runningModels[i].port
            if (port <= 0) {
                continue
            }
            script += "p=" + port + "; "
                + "pid=$(pgrep -f -- \"llama-serve[r] .*--port $p( |$)\" | head -1); "
                + "if [ -n \"$pid\" ]; then "
                + "m=$(awk '/^drm-client-id/{id=$2} /^drm-memory-vram/{v[id]=$2} /^drm-memory-gtt/{g[id]=$2} "
                + "END{tv=0;tg=0;for(i in v)tv+=v[i];for(i in g)tg+=g[i];printf \"%d %d\", tv, tg}' "
                + "/proc/$pid/fdinfo/* 2>/dev/null); "
                + "r=$(awk '/^VmRSS/{print $2}' /proc/$pid/status 2>/dev/null); "
                + "echo \"$p ${m:-0 0} ${r:-0}\"; fi; "
        }
        if (script.length === 0) {
            return
        }
        executable.run(script, function (stdout) {
            var changed = false
            var lines = stdout.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].trim().split(/\s+/)
                if (parts.length !== 4) {
                    continue
                }
                root.memCache[parts[0]] = {
                    vram: parseInt(parts[1], 10),
                    gtt: parseInt(parts[2], 10),
                    rss: parseInt(parts[3], 10)
                }
                changed = true
            }
            if (changed) {
                syncListModel()
            }
        })
    }

    // Rebuild the ListModel from runningModels, applying cached per-process memory.
    // A model's host-RAM footprint is GTT (GPU-visible host memory, where CPU-offloaded
    // weights live under Vulkan) plus the process RSS.
    function syncListModel() {
        modelListModel.clear()
        for (var i = 0; i < runningModels.length; i++) {
            var m = runningModels[i]
            var mem = memCache[m.port]
            modelListModel.append({
                name: m.name,
                modelState: m.modelState,
                port: m.port,
                vramKb: mem ? mem.vram : 0,
                ramKb: mem ? (mem.gtt + mem.rss) : 0,
                memKnown: mem !== undefined
            })
        }
    }

    // ---- actions ----
    function unloadModel(name) {
        executable.run("curl -sf --max-time 10 -X POST "
            + shQuote(serverUrl() + "/api/models/unload/" + encodeURIComponent(name)),
            function () { root.refresh() })
    }

    // ---- representations ----
    compactRepresentation: MouseArea {
        id: compact
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.fill: parent
            source: root.llamaIcon
            active: compact.containsMouse
        }

        // Loaded-model count badge, in the style of task manager notification badges.
        Rectangle {
            visible: root.loadedCount > 0
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Math.max(height, badgeLabel.implicitWidth + height * 0.4)
            height: Math.max(12, Math.round(parent.height * 0.45))
            radius: height / 2
            color: Kirigami.Theme.highlightColor

            PlasmaComponents.Label {
                id: badgeLabel
                anchors.centerIn: parent
                text: root.loadedCount
                color: Kirigami.Theme.highlightedTextColor
                font.pixelSize: Math.max(8, Math.round(parent.height * 0.7))
                font.weight: Font.Bold
            }
        }
    }

    fullRepresentation: FullRepresentation {
        backend: root
    }

    // ---- lifecycle ----
    Component.onCompleted: refresh()

    onExpandedChanged: {
        if (root.expanded) {
            refresh()
        }
    }

    // Fast refresh while the popup is open.
    Timer {
        interval: Math.max(1, Plasmoid.configuration.refreshInterval) * 1000
        repeat: true
        running: root.expanded
        onTriggered: root.refresh()
    }

    // Slow refresh while collapsed, to keep the badge and tooltip current.
    Timer {
        interval: Math.max(5, Plasmoid.configuration.idleRefreshInterval) * 1000
        repeat: true
        running: !root.expanded
        onTriggered: root.refresh()
    }
}
