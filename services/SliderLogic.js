.pragma library

function normalizedRatio(value, minimum, maximum) {
    const span = Math.max(0.0001, maximum - minimum)
    return Math.max(0, Math.min(1, (value - minimum) / span))
}

function effectiveDragMaximum(minimum, maximum, dragMaximum) {
    return Math.max(minimum, Math.min(maximum, dragMaximum))
}

function hasBoostZone(minimum, maximum, referenceValue) {
    return referenceValue > minimum && referenceValue < maximum
}

function isBoosted(value, minimum, maximum, referenceValue) {
    return hasBoostZone(minimum, maximum, referenceValue) && value > referenceValue + 0.001
}

// Map pointer position linearly across the full visual [minimum, maximum] track
// so the thumb tracks the cursor 1:1, then clamp at dragMaximum.
function valueFromPointer(mouseX, trackWidth, minimum, maximum, dragMaximum) {
    const ratio = Math.max(0, Math.min(1, mouseX / Math.max(1, trackWidth)))
    const raw = minimum + ratio * (maximum - minimum)
    return Math.min(effectiveDragMaximum(minimum, maximum, dragMaximum), raw)
}

function stepValue(value, up, step, minimum, maximum, referenceValue) {
    let next = up ? (value + step) : (value - step)
    if (maximum <= 10) {
        next = Math.round(next * 100) / 100
    }
    if (hasBoostZone(minimum, maximum, referenceValue)) {
        const eps = 0.001
        if (up && value < referenceValue - eps && next > referenceValue + eps) {
            next = referenceValue
        } else if (!up && value > referenceValue + eps && next < referenceValue - eps) {
            next = referenceValue
        }
    }
    return Math.max(minimum, Math.min(maximum, next))
}
