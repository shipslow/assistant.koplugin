-- test_engine_position.lua
-- Tests for the crengine position save/restore around book-text extraction
-- (ASUtils.saveEnginePosition / restoreEnginePosition / extractBookTextForAnalysis)
-- and for getChapterContext.
local helper = require("test.helper")
local assert = helper.assert
local ASUtils = helper.ASUtils

local function test(name, fn)
    return { name = name, fn = fn }
end

-- Reflowable document mock. The engine's bookmark moves to the start of the
-- range after getTextFromXPointers (as crengine does) and only gotoPage /
-- gotoPos put it back.
local function makeUI(opts)
    opts = opts or {}
    local calls = { gotoPage = {}, gotoPos = {}, gotoXPointer = {} }
    local state = { page = opts.page or 225, xp = "xp_page" .. tostring(opts.page or 225) }
    local ui = {
        document = {
            info = { has_pages = false },
            getXPointer = function() return state.xp end,
            getCurrentPage = function() return state.page end,
            getCurrentPos = function() return opts.pos or 4321 end,
            gotoPos = function(self, pos)
                table.insert(calls.gotoPos, pos)
                state.xp = "xp_cover"
                state.page = 1
            end,
            gotoXPointer = function(self, xp)
                table.insert(calls.gotoXPointer, xp)
                -- crengine leaves the bookmark stale here
            end,
            gotoPage = function(self, page)
                table.insert(calls.gotoPage, page)
                state.page = page
                state.xp = "xp_page" .. tostring(page)
            end,
            getTextFromXPointers = function(self, xp0, xp1)
                return opts.text or "book text"
            end,
        },
        view = { view_mode = opts.view_mode or "page", state = { page = opts.page or 225 } },
    }
    return ui, calls, state
end

local function mockAssistant(ui, features)
    features = features or {}
    return {
        ui = ui,
        config = {
            getFeature = function(self, key, default)
                local v = features[key]
                if v ~= nil then return v end
                return default
            end,
        },
    }
end

local tests = {

    test("extractBookTextForAnalysis restores the engine page after extraction", function()
        local ui, calls, state = makeUI({ page = 225 })
        local text, total = ASUtils.extractBookTextForAnalysis(mockAssistant(ui))
        assert.equal(text, "book text")
        assert.equal(total, 9)
        assert.equal(calls.gotoPage[#calls.gotoPage], 225, "gotoPage(saved page) is the last navigation")
        assert.equal(state.page, 225)
        assert.equal(state.xp, "xp_page225", "bookmark back on the reading page")
    end),

    test("a second extraction sees the same range as the first", function()
        local ui = makeUI({ page = 300 })
        local a = mockAssistant(ui)
        local first = { ASUtils.extractBookTextForAnalysis(a) }
        local second = { ASUtils.extractBookTextForAnalysis(a) }
        assert.equal(second[1], first[1])
        assert.equal(ui.document:getXPointer(), "xp_page300")
    end),

    test("tail truncation reports the untruncated length", function()
        local ui = makeUI({ text = string.rep("x", 50) })
        local text, total = ASUtils.extractBookTextForAnalysis(mockAssistant(ui, { max_text_length_for_analysis = 20 }))
        assert.equal(#text, 20)
        assert.equal(total, 50)
    end),

    test("scroll mode restores with gotoPos", function()
        local ui, calls = makeUI({ view_mode = "scroll", pos = 999 })
        ASUtils.extractBookTextForAnalysis(mockAssistant(ui))
        assert.equal(calls.gotoPos[#calls.gotoPos], 999, "last gotoPos is the saved position")
    end),

    test("save/restore helpers tolerate a broken document", function()
        local ui = { document = {}, view = {} }
        local saved = ASUtils.saveEnginePosition(ui)
        assert.equal(saved, nil)
        ASUtils.restoreEnginePosition(ui, nil) -- must not error
        assert.isTrue(true)
    end),

    test("getChapterContext lists chapters reached and the current one", function()
        local ui = makeUI({ page = 225 })
        ui.toc = {
            toc = {
                { page = 1, title = "  Chapter 1 ", depth = 1 },
                { page = 100, title = "Chapter 2", depth = 1 },
                { page = 120, title = "Section 2.1", depth = 2 },
                { page = 130, title = "Deep note", depth = 3 },
                { page = 400, title = "Chapter 3", depth = 1 },
            },
            fillToc = function() end,
            cleanUpTocTitle = function(self, t) return (t:gsub("^%s+", ""):gsub("%s+$", "")) end,
            getTocTitleByPage = function(self, page) return "Chapter 2" end,
        }
        ui.getCurrentPage = function() return 1 end -- engine page lags; the view page must win
        local ctx = ASUtils.getChapterContext(mockAssistant(ui))
        assert.notNil(ctx)
        assert.equal(ctx.current, "Chapter 2")
        assert.equal(#ctx.read, 3, "top two levels reached: Chapter 1, Chapter 2, Section 2.1")
        assert.equal(ctx.read[1], "Chapter 1")
        assert.equal(ctx.read[3], "Section 2.1")
    end),

    test("getChapterContext trims long lists keeping head and tail", function()
        local ui = makeUI({ page = 1000 })
        local entries = {}
        for i = 1, 100 do entries[i] = { page = i, title = "C" .. i, depth = 1 } end
        ui.toc = {
            toc = entries,
            fillToc = function() end,
            cleanUpTocTitle = function(self, t) return t end,
            getTocTitleByPage = function() return "C100" end,
        }
        local ctx = ASUtils.getChapterContext(mockAssistant(ui), 60)
        assert.equal(#ctx.read, 60)
        assert.equal(ctx.read[1], "C1")
        assert.equal(ctx.read[11], "…")
        assert.equal(ctx.read[60], "C100")
    end),

    test("getChapterContext returns nil without a TOC", function()
        local ui = makeUI({})
        ui.toc = { toc = {}, fillToc = function() end }
        assert.equal(ASUtils.getChapterContext(mockAssistant(ui)), nil)
    end),
}

return helper.runTests("engine_position", tests)
