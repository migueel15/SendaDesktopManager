.pragma library

function isSubsequence(query, text) {
    let index = 0;
    for (const character of text) {
        if (character === query[index]) index++;
        if (index === query.length) return true;
    }
    return false;
}

// Lower values represent a closer match. Recency breaks ties between matches.
function matchRank(entry, query) {
    if (!query) return 0;
    const name = (entry.name || "").toLocaleLowerCase();
    if (name === query) return 0;
    if (name.startsWith(query)) return 1;
    if (name.includes(query)) return 2;
    if (isSubsequence(query, name)) return 3;

    const secondary = [entry.genericName, entry.comment, entry.id].concat(entry.keywords || []);
    if (secondary.some(term => (term || "").toLocaleLowerCase().includes(query))) return 4;
    const alternateNames = [entry.genericName, entry.id];
    if (alternateNames.some(term => isSubsequence(query, (term || "").toLocaleLowerCase()))) return 5;
    return -1;
}

function sortEntries(entries, query, recentIds) {
    const matches = [];
    for (const entry of entries) {
        if (entry.noDisplay || !entry.name) continue;
        const rank = matchRank(entry, query);
        if (rank >= 0) matches.push({entry: entry, rank: rank});
    }
    matches.sort((a, b) => {
        if (a.rank !== b.rank) return a.rank - b.rank;
        const aIndex = recentIds.indexOf(a.entry.id);
        const bIndex = recentIds.indexOf(b.entry.id);
        if (aIndex !== -1 || bIndex !== -1)
            return aIndex === -1 ? 1 : bIndex === -1 ? -1 : aIndex - bIndex;
        return a.entry.name.localeCompare(b.entry.name);
    });
    return matches.map(match => match.entry);
}
