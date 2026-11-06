import QtQuick

// Scores comparáveis entre fontes. Correspondência textual domina tipo e uso.
QtObject {
    function matchScore(value, query) {
        const text = String(value ?? "").toLowerCase().trim()
        const q = String(query ?? "").toLowerCase().trim()
        if (!q || !text)
            return 0
        if (text === q)
            return 1200
        if (text.startsWith(q))
            return 800
        if (text.includes(q))
            return 420
        const words = q.split(/\s+/).filter(word => word.length > 0)
        return words.length > 1 && words.every(word => text.includes(word)) ? 300 : 0
    }

    function fuzzyMatch(value, query) {
        const text = String(value ?? "").toLowerCase()
        const q = String(query ?? "").toLowerCase().trim()
        if (q.length < 3)
            return false
        let pos = 0
        for (let i = 0; i < text.length && pos < q.length; i++)
            if (text[i] === q[pos])
                pos++
        return pos === q.length
    }

    function score(item, query) {
        const title = matchScore(item.title, query)
        const subtitle = matchScore(item.subtitle, query)
        const provider = String(item.provider ?? "")
        if (title === 0 && subtitle === 0) {
            const executable = item.payload?.entry?.execString ?? item.payload?.entry?.exec ?? ""
            return provider === "apps" &&
                (fuzzyMatch(item.title, query) || fuzzyMatch(executable, query))
                ? Math.min(180, Number(item.score ?? 0) * 0.15) : 0
        }
        const priority = provider === "apps" ? 80 : (provider === "windows" ? 40 : 0)
        const usage = provider === "apps" ? Math.min(40, Number(item.score ?? 0) * 0.02) : 0
        return Math.max(title, subtitle * 0.35) + priority + usage
    }

    function merge(query, apps, windows, actions) {
        const source = (apps ?? []).concat(windows ?? [], actions ?? [])
        const seen = {}
        return source.map(item => ({ item: item, rank: score(item, query) }))
            .filter(row => row.rank > 0)
            .sort((a, b) => {
                const aWindow = a.item.provider === "windows"
                const bWindow = b.item.provider === "windows"
                if (aWindow !== bWindow)
                    return aWindow ? 1 : -1
                return b.rank - a.rank
                    || String(a.item.title).localeCompare(String(b.item.title))
            })
            .filter(row => {
                if (seen[row.item.id])
                    return false
                seen[row.item.id] = true
                return true
            })
            .slice(0, 8)
            .map(row => row.item)
    }
}
