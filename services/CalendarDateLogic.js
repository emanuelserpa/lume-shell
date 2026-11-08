.pragma library

function followsCurrentMonth(shownDate, currentDate) {
    return shownDate.getMonth() === currentDate.getMonth()
        && shownDate.getFullYear() === currentDate.getFullYear()
}

function datesAfterRefresh(shownDate, currentDate, now) {
    return {
        currentDate: now,
        shownDate: followsCurrentMonth(shownDate, currentDate)
            ? now
            : shownDate
    }
}
