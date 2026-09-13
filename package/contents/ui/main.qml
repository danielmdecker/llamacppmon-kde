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
    property var serverProcs: []            // llama-server processes found on the host (JS array)
    property string errorText: ""           // non-empty when the server is unreachable
    property double ramTotalKb: 0           // /proc/meminfo, KiB
    property double ramAvailKb: 0
    property double vramTotalKb: 0          // amdgpu sysfs, KiB (0 = unknown)
    property double vramUsedKb: 0

    // Per-PID process memory cache so list entries keep their numbers while the
    // popup is closed (memory is only read while it is open).
    property var memCache: ({})

    readonly property double vramAvailKb: Math.max(0, vramTotalKb - vramUsedKb)
    readonly property int loadedCount: modelListModel.count

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
        refreshProcesses()
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
                    // match the model to its llama-server process.
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

    // Find every llama-server process on the host (including ones inside containers)
    // by process name. For each, report whether llama-swap is an ancestor and its
    // command line. While the popup is open, also read VRAM and GTT from DRM fdinfo
    // (deduplicated by drm-client-id) and RSS from /proc.
    function refreshProcesses() {
        var withMem = root.expanded
        var script = "for pid in $(pgrep -x llama-server); do "
            + "s=0; p=$pid; "
            + "while [ \"$p\" -gt 1 ] 2>/dev/null; do "
            + "p=$(awk '/^PPid/{print $2}' /proc/$p/status 2>/dev/null); "
            + "[ \"$(cat /proc/$p/comm 2>/dev/null)\" = llama-swap ] && { s=1; break; }; "
            + "done; "
            + "m='- -'; r=-; "
        if (withMem) {
            script += "m=$(awk '/^drm-client-id/{id=$2} /^drm-memory-vram/{v[id]=$2} /^drm-memory-gtt/{g[id]=$2} "
                + "END{tv=0;tg=0;for(i in v)tv+=v[i];for(i in g)tg+=g[i];printf \"%d %d\", tv, tg}' "
                + "/proc/$pid/fdinfo/* 2>/dev/null); "
                + "r=$(awk '/^VmRSS/{print $2}' /proc/$pid/status 2>/dev/null); "
        }
        script += "echo \"P $pid $s ${m:-0 0} ${r:-0}\"; "
            + "echo \"C $(tr '\\0\\n' '\\t ' < /proc/$pid/cmdline 2>/dev/null)\"; "
            + "done"
        executable.run(script, function (stdout) {
            var procs = []
            var cur = null
            var lines = stdout.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (line.indexOf("P ") === 0) {
                    var parts = line.trim().split(/\s+/)
                    if (parts.length !== 6) {
                        cur = null
                        continue
                    }
                    cur = { pid: parseInt(parts[1], 10), swap: parts[2] === "1" }
                    if (parts[3] !== "-") {
                        root.memCache[cur.pid] = {
                            vram: parseInt(parts[3], 10),
                            gtt: parseInt(parts[4], 10),
                            rss: parseInt(parts[5], 10)
                        }
                    }
                } else if (line.indexOf("C ") === 0 && cur) {
                    var args = parseServerArgs(line.substring(2).split("\t"))
                    cur.port = args.port
                    cur.name = args.name
                    procs.push(cur)
                    cur = null
                }
            }
            // Drop cached memory for processes that have exited.
            var live = {}
            for (var j = 0; j < procs.length; j++) {
                live[procs[j].pid] = true
            }
            for (var pid in root.memCache) {
                if (!live[pid]) {
                    delete root.memCache[pid]
                }
            }
            root.serverProcs = procs
            syncListModel()
        })
    }

    // Port and display name from a llama-server argv: --alias (first of a comma list),
    // else the --model file name, else the --hf-repo, else "llama-server".
    function parseServerArgs(argv) {
        var opts = {}
        for (var i = 1; i < argv.length; i++) {
            var a = argv[i]
            var eq = a.indexOf("=")
            if (a.indexOf("-") === 0 && eq > 0) {
                opts[a.substring(0, eq)] = a.substring(eq + 1)
            } else if (a.indexOf("-") === 0 && i + 1 < argv.length) {
                opts[a] = argv[i + 1]
            }
        }
        var alias = opts["--alias"] || opts["-a"]
        var model = opts["--model"] || opts["-m"]
        var hf = opts["--hf-repo"] || opts["-hf"] || opts["-hfr"]
        var name = alias ? alias.split(",")[0]
                 : model ? model.replace(/^.*\//, "").replace(/\.gguf$/i, "")
                 : hf ? hf
                 : "llama-server"
        return {
            port: parseInt(opts["--port"] || "8080", 10),
            name: name
        }
    }

    // Rebuild the ListModel. llama-swap models are matched to the llama-server
    // process that llama-swap spawned on their port. llama-server processes not
    // started by llama-swap (e.g. in a container) are listed as external.
    // A model's host-RAM footprint is GTT (GPU-visible host memory, where CPU-offloaded
    // weights live under Vulkan) plus the process RSS.
    function syncListModel() {
        modelListModel.clear()
        for (var i = 0; i < runningModels.length; i++) {
            var m = runningModels[i]
            var pid = 0
            for (var j = 0; j < serverProcs.length; j++) {
                if (serverProcs[j].swap && serverProcs[j].port === m.port) {
                    pid = serverProcs[j].pid
                    break
                }
            }
            appendRow(m.name, m.modelState, pid, false)
        }
        for (var k = 0; k < serverProcs.length; k++) {
            if (!serverProcs[k].swap) {
                appendRow(serverProcs[k].name, "ready", serverProcs[k].pid, true)
            }
        }
    }

    function appendRow(name, modelState, pid, external) {
        var mem = pid > 0 ? memCache[pid] : undefined
        modelListModel.append({
            name: name,
            modelState: modelState,
            pid: pid,
            external: external,
            vramKb: mem ? mem.vram : 0,
            ramKb: mem ? (mem.gtt + mem.rss) : 0,
            memKnown: mem !== undefined
        })
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
