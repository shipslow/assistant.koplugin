-- test_term_mentions.lua
-- Tests for ASUtils.extractTermMentions (Term X-Ray context): passages that
-- mention a term, in book order, first passage kept and the most recent ones
-- filling the budget.
local helper = require("test.helper")
local assert = helper.assert
local ASUtils = helper.ASUtils

local function test(name, fn)
    return { name = name, fn = fn }
end

-- 400 sentences; the term appears in sentences 1, 51, 101, ... (8 mentions).
local function makeBook()
    local sents = {}
    for i = 1, 400 do
        if i % 50 == 1 then
            sents[#sents + 1] = "The Wallfacer Luo Ji spoke at meeting " .. i .. "."
        else
            sents[#sents + 1] = "Filler sentence number " .. i .. " about something else entirely."
        end
    end
    return table.concat(sents, " ")
end

local tests = {

    test("all mentions fit: every passage returned in order", function()
        local text, n, shown, total = ASUtils.extractTermMentions(makeBook(), "luo ji", "en", 2, 2, 100000)
        assert.equal(n, 8, "mention count")
        assert.equal(total, 8, "passage count")
        assert.equal(shown, 8, "all passages shown")
        assert.matches(text, "meeting 1%.")
        assert.matches(text, "meeting 351%.")
        local first = text:find("meeting 1%.", 1)
        local last = text:find("meeting 351%.", 1)
        assert.isTrue(first < last, "book order kept")
    end),

    test("case-insensitive matching", function()
        local _, n = ASUtils.extractTermMentions(makeBook(), "LUO JI", "en", 1, 1, 100000)
        assert.equal(n, 8)
    end),

    test("over budget: first passage and the most recent ones survive", function()
        local text, _, shown, total = ASUtils.extractTermMentions(makeBook(), "Luo Ji", "en", 2, 2, 900)
        assert.isTrue(shown < total, "budget dropped passages")
        assert.matches(text, "meeting 1%.", "introduction kept")
        assert.matches(text, "meeting 351%.", "most recent kept")
        assert.notMatches(text, "meeting 51%.", "an early middle passage dropped")
        assert.isTrue(#text <= 900, "within budget")
    end),

    test("term not found returns nil and zero counts", function()
        local text, n, shown, total = ASUtils.extractTermMentions(makeBook(), "Trisolaris", "en", 2, 2, 1000)
        assert.equal(text, nil)
        assert.equal(n, 0)
        assert.equal(shown, 0)
        assert.equal(total, 0)
    end),

    test("overlapping windows merge into one passage", function()
        local book = "A cat sat there. The cat ran away fast. A dog barked loudly. The cat slept well. The end here."
        local _, n, shown, total = ASUtils.extractTermMentions(book, "cat", "en", 1, 1, 10000)
        assert.equal(n, 3, "three mentions")
        assert.equal(total, 1, "one merged passage")
        assert.equal(shown, 1)
    end),

    test("stem fallback finds inflected forms", function()
        local book = "The soldiers marched at dawn today. Nothing else happened here. They were marching all night long."
        local _, n = ASUtils.extractTermMentions(book, "marching", "en", 0, 0, 10000)
        assert.isTrue(n >= 1, "stem of 'marching' matches 'marched'")
    end),

    test("invalid input", function()
        local text, n = ASUtils.extractTermMentions(nil, "x", "en")
        assert.equal(text, nil)
        assert.equal(n, 0)
        text, n = ASUtils.extractTermMentions("some text here.", "", "en")
        assert.equal(text, nil)
        assert.equal(n, 0)
    end),
}

return helper.runTests("term_mentions", tests)
