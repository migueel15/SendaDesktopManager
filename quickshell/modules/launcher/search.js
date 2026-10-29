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

// Evaluates arithmetic with + - * / % ^, parentheses and decimal commas.
// Returns null when the text is not a complete expression.
function calculate(text) {
    const source = text.replace(/^=/, "").replace(/,/g, ".").replace(/\s+/g, "");
    if (!source || !/^[0-9.+\-*/%^()]+$/.test(source)) return null;
    if (!text.startsWith("=") && !/[0-9.)][+\-*/%^]/.test(source)) return null;
    let position = 0;
    const peek = () => source[position];
    function primary() {
        if (peek() === "(") {
            position++;
            const value = sum();
            if (peek() !== ")") throw new Error("paren");
            position++;
            return value;
        }
        const match = /^\d*\.?\d+|^\d+\./.exec(source.slice(position));
        if (!match) throw new Error("number");
        position += match[0].length;
        return parseFloat(match[0]);
    }
    function unary() {
        if (peek() === "-") { position++; return -unary(); }
        if (peek() === "+") { position++; return unary(); }
        return power();
    }
    function power() {
        const base = primary();
        if (peek() !== "^") return base;
        position++;
        return Math.pow(base, unary());
    }
    function product() {
        let value = unary();
        while (peek() === "*" || peek() === "/" || peek() === "%") {
            const operator = source[position++];
            const right = unary();
            value = operator === "*" ? value * right : operator === "/" ? value / right : value % right;
        }
        return value;
    }
    function sum() {
        let value = product();
        while (peek() === "+" || peek() === "-") {
            const operator = source[position++];
            const right = product();
            value = operator === "+" ? value + right : value - right;
        }
        return value;
    }
    try {
        const value = sum();
        if (position !== source.length || !isFinite(value)) return null;
        return String(parseFloat(value.toPrecision(12)));
    } catch (error) {
        return null;
    }
}
