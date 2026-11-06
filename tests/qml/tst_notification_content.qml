import QtQuick
import QtTest
import "../../services/BatteryAlertLogic.js" as BatteryAlertLogic
import "../../services/NotificationContent.js" as NotificationContent

TestCase {
    name: "NotificationContent"

    function test_historyGroupsCollapseAndExpand() {
        const a = { id: 3, appName: "Chat", desktopEntry: "chat", summary: "Grupo" }
        const b = { id: 2, appName: "Mail", summary: "mail" }
        const c = { id: 1, appName: "Chat", desktopEntry: "chat", summary: "Grupo" }
        const collapsed = NotificationContent.historyRows([a, b, c], [])
        compare(collapsed.length, 2)
        compare(collapsed[0].notification, a)
        compare(collapsed[0].count, 2)
        verify(collapsed[0].first && collapsed[0].last)
        verify(collapsed[0].header)
        compare(collapsed[0].name, "Chat")
        verify(!collapsed[1].header)
        const expanded = NotificationContent.historyRows([a, b, c], ["desktop:chat"])
        compare(expanded.length, 3)
        compare(expanded[1].notification, c)
        verify(expanded[0].first && !expanded[0].last)
        verify(!expanded[1].first && expanded[1].last)
        verify(expanded[2].first && expanded[2].last)
        verify(!expanded[1].header)
        compare(expanded[2].notification, b)
    }

    function test_allConversationsFromSameAppShareOneGroup() {
        const list = [
            {id: 5, appName: "Elecwhat", desktopEntry: "elecwhat", summary: "Carreata", body: "nova"},
            {id: 4, appName: "Elecwhat", desktopEntry: "elecwhat", summary: "Carreata", body: "antiga"},
            {id: 3, appName: "Elecwhat", desktopEntry: "elecwhat", summary: "Direita", body: "nova"},
            {id: 2, appName: "Elecwhat", desktopEntry: "elecwhat", summary: "Conversa pessoal", body: "única"}
        ]
        const rows = NotificationContent.historyRows(list, [])
        compare(rows.length, 1)
        compare(rows[0].name, "Elecwhat")
        compare(rows[0].count, 4)
        verify(rows[0].header)

        const expanded = NotificationContent.historyRows(list, ["desktop:elecwhat"])
        compare(expanded.length, 4)
        compare(expanded[0].notification, list[0])
        compare(expanded[1].notification, list[1])
        compare(expanded[2].notification, list[2])
        compare(expanded[3].notification, list[3])
        verify(expanded.slice(1).every(function(row) { return !row.header }))
    }

    function test_historyGroupIdentityAndRemoval() {
        const list = [{id: 4, appName: "Same", desktopEntry: "one"},
                      {id: 3, appName: "Same", desktopEntry: "two"},
                      {id: 2}, {id: 1}]
        compare(NotificationContent.historyRows(list, []).length, 4)
        compare(NotificationContent.historyRows([], ["desktop:one"]).length, 0)
        const remaining = NotificationContent.historyRows([list[0]], ["desktop:one"])
        compare(remaining.length, 1)
        verify(!remaining[0].header)
    }

    function test_formatTextDecodesEntitiesAndMarkup() {
        compare(NotificationContent.formatText("<b>Hello</b> &amp; &#x77;orld<br>next"),
                "Hello & world\nnext")
    }

    function test_storageSnapshotKeepsDisplayFieldsButNotActions() {
        const snapshot = NotificationContent.storageSnapshot({
            id: 42,
            appName: "Elecwhat",
            desktopEntry: "elecwhat",
            appIcon: "elecwhat-icon",
            summary: "Grupo",
            body: "Nova mensagem",
            urgency: 2,
            hints: {"image-path": "/tmp/avatar.png", secret: "ignore"},
            actions: [{text: "Responder", invoke: function() {}}]
        }, 123456)

        compare(snapshot.receivedAt, 123456)
        compare(snapshot.appName, "Elecwhat")
        compare(snapshot.desktopEntry, "elecwhat")
        compare(snapshot.summary, "Grupo")
        compare(snapshot.body, "Nova mensagem")
        compare(snapshot.urgency, 2)
        compare(snapshot.hints["image-path"], "/tmp/avatar.png")
        verify(snapshot.hints.secret === undefined)
        verify(snapshot.actions === undefined)
    }

    function test_placeholderLabelsIgnoreCaseAndWhitespace() {
        verify(NotificationContent.isPlaceholderLabel("  NOTIFICAÇÃO  "))
        verify(NotificationContent.isPlaceholderLabel(""))
        verify(!NotificationContent.isPlaceholderLabel("Download concluído"))
    }

    function test_emptyNotificationIsDiscardedRegardlessOfAppName() {
        verify(!NotificationContent.hasUsefulContent({appName: "Spotify", summary: "", body: ""}))
        verify(!NotificationContent.hasUsefulContent({summary: "Notificação", body: ""}))
    }

    function test_summaryOrBodyIsUseful() {
        verify(NotificationContent.hasUsefulContent({summary: "Reunião às 16h"}))
        verify(NotificationContent.hasUsefulContent({body: "Build concluído"}))
    }

    function test_onlyRealImageAttachmentIsUseful() {
        verify(NotificationContent.hasUsefulContent({image: "/tmp/preview.png"}))
        verify(!NotificationContent.hasUsefulContent({image: "image://icon/firefox"}))
        verify(!NotificationContent.hasUsefulContent({image: "firefox", appIcon: "firefox"}))
    }

    function test_onlyUsefulActionIsUseful() {
        verify(NotificationContent.hasUsefulContent({actions: [{text: "Aceitar"}]}))
        verify(!NotificationContent.hasUsefulContent({actions: [{text: "Ação"}]}))
    }

    function test_isBatteryDetectsBatteryNotifications() {
        verify(NotificationContent.isBattery({appName: "Battery", summary: "Bateria fraca"}))
        verify(NotificationContent.isBattery({appIcon: "battery-caution", summary: "Alerta"}))
        verify(NotificationContent.isBattery({summary: "Carregador conectado", body: "Bateria em 80%."}))
        verify(!NotificationContent.isBattery({appName: "Spotify", summary: "Música nova"}))
    }

    function test_isNetworkAppletDetectsAndExcludesFromHistory() {
        const netPt = {
            id: 10,
            appName: "Miniaplicativo gerenciador de redes",
            desktopEntry: "org.freedesktop.network-manager-applet",
            summary: "Conexão estabelecida",
            body: "Conectado ao Wi-Fi"
        }
        const netEn = {
            id: 11,
            appName: "NetworkManager Applet",
            desktopEntry: "nm-applet",
            summary: "Connection Established"
        }
        const normal = {
            id: 12,
            appName: "Zen",
            desktopEntry: "zen",
            summary: "Download concluído"
        }
        verify(NotificationContent.isNetworkApplet(netPt))
        verify(NotificationContent.isNetworkApplet(netEn))
        verify(!NotificationContent.isNetworkApplet(normal))
        verify(NotificationContent.isExcludedFromHistory(netPt))
        verify(!NotificationContent.isExcludedFromHistory(normal))

        const rows = NotificationContent.historyRows([netPt, netEn, normal], [])
        compare(rows.length, 1)
        compare(rows[0].notification, normal)
    }

    function test_batteryIconReturnsCorrectGlyphs() {
        compare(NotificationContent.batteryIcon({summary: "Carregador conectado"}), "󰂄")
        compare(NotificationContent.batteryIcon({urgency: 2, summary: "Bateria criticamente baixa"}), "󰂃")
        compare(NotificationContent.batteryIcon({summary: "Bateria fraca", body: "20% restante"}), "󰁺")
    }

    function test_chargingVersusLowDistinction() {
        verify(NotificationContent.isChargingNotification({summary: "Carregador conectado", body: "Bateria em 80%."}))
        verify(!NotificationContent.isChargingNotification({summary: "Bateria fraca", body: "20% restante. Considere conectar o carregador."}))
        verify(NotificationContent.isCriticalNotification({urgency: 2, summary: "Alerta de energia"}))
        verify(NotificationContent.isCriticalNotification({summary: "Bateria criticamente baixa", body: "5% restante"}))
        verify(!NotificationContent.isCriticalNotification({urgency: 1, summary: "Bateria fraca", body: "20% restante"}))
    }

    function test_fullscreenHidesNormalToastsAndKeepsCritical() {
        const normal = {notification: {urgency: 1}}
        const critical = {notification: {urgency: 2}}
        const toasts = [normal, critical]

        compare(NotificationContent.visibleToastItems(toasts, false, 2).length, 2)
        const visible = NotificationContent.visibleToastItems(toasts, true, 2)
        compare(visible.length, 1)
        compare(visible[0], critical)
    }

    function test_dismissingBatteryAlertsKeepsOtherCriticalToasts() {
        const battery = {id: "battery", notification: {
            appName: "Battery", urgency: 2, summary: "Bateria muito fraca"
        }}
        const other = {id: "other", notification: {
            appName: "Backup", urgency: 2, summary: "Falha no backup"
        }}

        const remaining = NotificationContent.withoutBatteryAlertToasts([battery, other])
        compare(remaining.length, 1)
        compare(remaining[0], other)
    }

    function test_chargerConnectedNoticeIsNotDismissedAsStaleBatteryAlert() {
        verify(NotificationContent.isBatteryAlert({appName: "Battery", summary: "Bateria fraca"}))
        verify(!NotificationContent.isBatteryAlert({appName: "Battery", appIcon: "battery-good-charging", summary: "Carregador conectado", body: "Bateria em 35%."}))
    }

    function test_batteryThresholdsAndUrgencies() {
        compare(BatteryAlertLogic.levelForPercentage(20), "low")
        compare(BatteryAlertLogic.levelForPercentage(10), "very-low")
        compare(BatteryAlertLogic.levelForPercentage(5), "critical")
        compare(BatteryAlertLogic.levelForPercentage(21), "")
        compare(BatteryAlertLogic.notificationForLevel("low", 20).urgency, "normal")
        compare(BatteryAlertLogic.notificationForLevel("very-low", 10).urgency, "critical")
        compare(BatteryAlertLogic.notificationForLevel("critical", 5).urgency, "critical")
    }

    function test_batteryAlertsEscalateOnlyWhenCrossingIntoAnotherTier() {
        const first = BatteryAlertLogic.transition("", false, 20, true, false)
        compare(first.level, "low")
        verify(first.notice !== null)

        const sameTier = BatteryAlertLogic.transition(first.level, first.wasCharging, 18, true, false)
        compare(sameTier.level, "low")
        compare(sameTier.notice, null)

        const escalation = BatteryAlertLogic.transition(sameTier.level, false, 10, true, false)
        compare(escalation.level, "very-low")
        compare(escalation.notice.summary, "Bateria muito fraca")
    }

    function test_chargingResetsAlertAndNotifiesOnlyAfterAnAlert() {
        const noPriorAlert = BatteryAlertLogic.transition("", false, 80, false, true)
        compare(noPriorAlert.notice, null)

        const connected = BatteryAlertLogic.transition("low", false, 35, false, true)
        compare(connected.level, "")
        compare(connected.wasCharging, true)
        compare(connected.notice.summary, "Carregador conectado")

        const remainsConnected = BatteryAlertLogic.transition("", true, 100, false, true)
        compare(remainsConnected.notice, null)

        const unplugged = BatteryAlertLogic.transition(connected.level, connected.wasCharging, 19, true, false)
        compare(unplugged.level, "low")
        verify(unplugged.notice !== null)
    }

    function test_nonDischargingStateDoesNotEmitAlertsOrResetTier() {
        const next = BatteryAlertLogic.transition("low", false, 18, false, false)
        compare(next.level, "low")
        compare(next.wasCharging, false)
        compare(next.notice, null)
    }
}
