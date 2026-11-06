pragma Singleton

import QtQuick
import Quickshell
import qs.components

// Tracks yt-dlp jobs and posts a completion notification when one leaves
// the running state. Polls the helper only while a job is active, so the
// idle cost is zero. Spotlight and the download panel share this state.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var jobs: []
    property var seenDone: ({})
    property bool baselined: false
    property string helper: Quickshell.shellDir + "/scripts/ytdlp-download.py"

    readonly property bool hasActive: {
        for (let i = 0; i < jobs.length; i++) {
            if (String(jobs[i]?.status ?? "") === "running")
                return true
        }
        return false
    }

    function pollNow() {
        recentFetch.refresh()
    }

    function trackJob(jobId) {
        notified(jobId, false)
        pollNow()
    }

    function notified(jobId, value) {
        const key = String(jobId ?? "")
        if (key.length === 0)
            return
        if (value === false)
            delete seenDone[key]
        else
            seenDone[key] = true
        seenDoneChanged()
    }

    function jobById(jobId) {
        for (let i = 0; i < jobs.length; i++) {
            if (String(jobs[i]?.job_id ?? "") === String(jobId ?? ""))
                return jobs[i]
        }
        return null
    }

    CommandJson {
        id: recentFetch
        autoStart: false
        interval: 0
        command: ["python3", "-B", root.helper, "recent", "--limit", "20"]
        onResultChanged: {
            const data = result && result.ok && result.data ? result.data : null
            if (!data)
                return
            const fresh = data.jobs ?? []
            root.jobs = fresh
            // First poll after (re)start only baselines: jobs that
            // already finished in a previous session must not notify.
            const silent = !root.baselined
            root.baselined = true
            for (let i = 0; i < fresh.length; i++) {
                const job = fresh[i]
                const status = String(job?.status ?? "")
                const key = String(job?.job_id ?? "")
                if (key.length === 0 || status === "running" || status === "cancelled")
                    continue
                if (root.seenDone[key] || silent) {
                    if (silent)
                        root.notified(key, true)
                    continue
                }
                root.notified(key, true)
                if (status === "done") {
                    NotificationState.postInternalNotification({
                        appName: "Downloads",
                        summary: "Download concluído",
                        body: String(job?.title ?? job?.url ?? ""),
                        image: String(job?.thumbnail ?? ""),
                        replaceKey: "ytdlp-" + key
                    })
                } else if (status === "error") {
                    NotificationState.postInternalNotification({
                        appName: "Downloads",
                        summary: "Download falhou",
                        body: String(job?.title ?? job?.url ?? ""),
                        image: String(job?.thumbnail ?? ""),
                        replaceKey: "ytdlp-" + key
                    })
                }
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.hasActive
        onTriggered: root.pollNow()
    }
}
