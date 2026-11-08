.pragma library

function followsCurrentMonth(shownDate, currentDate) {
    return shownDate.getMonth() === currentDate.getMonth()
        && shownDate.getFullYear() === currentDate.getFullYear()
}
