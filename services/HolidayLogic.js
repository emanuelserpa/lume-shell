.pragma library

const NATIONAL_HOLIDAYS = [
    { month: 0, day: 1, name: "Confraternização Universal" },
    { month: 3, day: 21, name: "Tiradentes" },
    { month: 4, day: 1, name: "Dia do Trabalho" },
    { month: 8, day: 7, name: "Independência do Brasil" },
    { month: 9, day: 12, name: "Nossa Senhora Aparecida" },
    { month: 10, day: 2, name: "Finados" },
    { month: 10, day: 15, name: "Proclamação da República" },
    { month: 10, day: 20, name: "Consciência Negra" },
    { month: 11, day: 25, name: "Natal" }
]

function easterDate(year) {
    // Meeus/Jones/Butcher Gregorian Easter algorithm.
    const a = year % 19
    const b = Math.floor(year / 100)
    const c = year % 100
    const d = Math.floor(b / 4)
    const e = b % 4
    const f = Math.floor((b + 8) / 25)
    const g = Math.floor((b - f + 1) / 3)
    const h = (19 * a + b - d - g + 15) % 30
    const i = Math.floor(c / 4)
    const k = c % 4
    const l = (32 + 2 * e + 2 * i - h - k) % 7
    const m = Math.floor((a + 11 * h + 22 * l) / 451)
    const month = Math.floor((h + l - 7 * m + 114) / 31)
    const day = ((h + l - 7 * m + 114) % 31) + 1
    return new Date(year, month - 1, day)
}

function dayNumber(date) {
    return Math.floor(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / 86400000)
}

function dateLabel(date) {
    const months = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
    return date.getDate() + " " + months[date.getMonth()]
}

function holidaysForYear(year, region) {
    const holidays = NATIONAL_HOLIDAYS.map(function(item) {
        return { name: item.name, date: new Date(year, item.month, item.day) }
    })

    const goodFriday = easterDate(year)
    goodFriday.setDate(goodFriday.getDate() - 2)
    holidays.push({ name: "Paixão de Cristo", date: goodFriday })

    if (String(region).toLowerCase().includes("cear") || String(region).toUpperCase() === "CE") {
        holidays.push({ name: "Data Magna do Ceará", date: new Date(year, 2, 25) })
    }

    return holidays
}

function nextHolidays(fromDate, region, limit) {
    const count = Math.max(0, Number(limit) || 0)
    const today = dayNumber(fromDate)
    const candidates = holidaysForYear(fromDate.getFullYear(), region)
        .concat(holidaysForYear(fromDate.getFullYear() + 1, region))
        .map(function(holiday) {
            const daysUntil = dayNumber(holiday.date) - today
            return {
                name: holiday.name,
                date: holiday.date,
                dateLabel: dateLabel(holiday.date),
                daysUntil: daysUntil,
                countdown: daysUntil === 0 ? "Hoje"
                           : daysUntil === 1 ? "Amanhã"
                           : "em " + daysUntil + " dias"
            }
        })
        .filter(function(holiday) { return holiday.daysUntil >= 0 })
        .sort(function(a, b) { return a.daysUntil - b.daysUntil })

    return candidates.slice(0, count)
}
