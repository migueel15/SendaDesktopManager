.pragma library

// A hidden view with pending input is not reconstructible yet. Traverse visual
// children (including controls' content items), never services or model data.
function hasDraft(item) {
    if (!item) return false;
    if (item.retainWhenHidden === true || item.dirty === true || item.editingTitle === true)
        return true;
    return childrenHaveDrafts(item);
}

function childrenHaveDrafts(item) {
    const children = Array.from(item.children ?? []);
    if (item.contentItem && !children.includes(item.contentItem)) children.push(item.contentItem);
    return children.some(hasDraft);
}
