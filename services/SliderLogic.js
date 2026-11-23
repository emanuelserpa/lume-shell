.pragma library

const BOOST_BARRIER_TICKS = 4
const BOOST_BARRIER_WINDOW_MS = 750

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

function consumeWheelDelta(accumState, angleDeltaY, pixelDeltaY) {
    let angle = Number(accumState?.angle ?? 0)
    let pixel = Number(accumState?.pixel ?? 0)
    const steps = []

    if (pixelDeltaY !== 0) {
        pixel += pixelDeltaY
        const pixelThreshold = 24
        while (Math.abs(pixel) >= pixelThreshold) {
            const up = pixel > 0
            pixel -= up ? pixelThreshold : -pixelThreshold
            steps.push(up)
        }
    } else if (angleDeltaY !== 0) {
        angle += angleDeltaY
        const angleThreshold = 120
        while (Math.abs(angle) >= angleThreshold) {
            const up = angle > 0
            angle -= up ? angleThreshold : -angleThreshold
            steps.push(up)
        }
    }

    return {
        state: { angle: angle, pixel: pixel },
        steps: steps
    }
}

// Require `requiredTicks` consecutive upward scroll steps while resting at
// `referenceValue` (within `windowMs`) before crossing into the boost zone.
function stepWithDetent(barrierState, value, up, step, minimum, maximum, referenceValue, nowMs, requiredTicks, windowMs) {
    const reqTicks = requiredTicks > 0 ? requiredTicks : BOOST_BARRIER_TICKS
    const timeoutMs = windowMs > 0 ? windowMs : BOOST_BARRIER_WINDOW_MS
    const ts = Number.isFinite(nowMs) ? nowMs : Date.now()
    const prevTicks = Number(barrierState?.barrierTicks ?? 0)
    const prevMs = Number(barrierState?.lastTickMs ?? 0)

    if (!hasBoostZone(minimum, maximum, referenceValue)) {
        return {
            value: stepValue(value, up, step, minimum, maximum, -1),
            state: { barrierTicks: 0, lastTickMs: 0 }
        }
    }

    const eps = 0.001
    if (!up) {
        return {
            value: stepValue(value, false, step, minimum, maximum, referenceValue),
            state: { barrierTicks: 0, lastTickMs: 0 }
        }
    }

    // Below 100%: advance normally and stop cleanly at 100%.
    if (value < referenceValue - eps) {
        let next = value + step
        if (maximum <= 10)
            next = Math.round(next * 100) / 100
        if (next >= referenceValue - eps) {
            return {
                value: referenceValue,
                state: { barrierTicks: 0, lastTickMs: ts }
            }
        }
        return {
            value: Math.max(minimum, Math.min(maximum, next)),
            state: { barrierTicks: 0, lastTickMs: 0 }
        }
    }

    // Resting at 100%: require repeated deliberate upward ticks to unlock boost.
    if (Math.abs(value - referenceValue) <= eps) {
        const withinWindow = prevMs > 0 && (ts - prevMs) <= timeoutMs
        const ticks = withinWindow ? (prevTicks + 1) : 1
        if (ticks < reqTicks) {
            return {
                value: referenceValue,
                state: { barrierTicks: ticks, lastTickMs: ts }
            }
        }
        let boosted = referenceValue + step
        if (maximum <= 10)
            boosted = Math.round(boosted * 100) / 100
        return {
            value: Math.max(minimum, Math.min(maximum, boosted)),
            state: { barrierTicks: 0, lastTickMs: 0 }
        }
    }

    // Already above 100%: step smoothly up to maximum.
    return {
        value: stepValue(value, true, step, minimum, maximum, -1),
        state: { barrierTicks: 0, lastTickMs: 0 }
    }
}
