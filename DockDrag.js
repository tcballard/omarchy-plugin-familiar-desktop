.pragma library

// Both rails and folder grids shift neighbouring items using the same order.
function visualSlot(index, from, to) {
    if (from < 0 || to < 0 || from === to || index === from) return index;
    if (from < to && index > from && index <= to) return index - 1;
    if (from > to && index >= to && index < from) return index + 1;
    return index;
}

// Use the same decision for drag feedback and the eventual drop.
function railTarget(index, count, size, offset, canMerge) {
    var clamped = Math.max(-index * size, Math.min((count - 1 - index) * size, offset));
    var position = index * size + clamped;
    var target = Math.max(0, Math.min(count - 1, Math.round(position / size)));
    var distance = position - target * size;
    var merge = !!canMerge && target !== index && (target > index
        ? distance >= -22 && distance <= 0
        : distance <= 22 && distance >= 0);
    if ((target === 0 && position <= 8) || (target === count - 1 && position >= (count - 1) * size - 8)) merge = false;
    return { index: target, merge: merge };
}
