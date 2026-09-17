-- test_text_search.lua
-- Tests for the text-protocol web search helpers in assistant_tool_executor.lua:
-- parseTextSearch, ensureTextSearchPrompt, appendTextSearchResult.
local helper = require("test.helper")
local assert = helper.assert
local ASUtils = helper.ASUtils
local ToolExecutor = require("assistant_tool_executor")
local Prompts = require("assistant_prompts").assistant_prompts

local function test(name, fn)
    return { name = name, fn = fn }
end

local tests = {

    -- =========================================================================
    -- parseTextSearch
    -- =========================================================================

    test("parse: plain SEARCH line", function()
        assert.equal(ToolExecutor.parseTextSearch("SEARCH: Dark Forest Cixin Liu plot"), "Dark Forest Cixin Liu plot")
    end),

    test("parse: markdown decoration and quotes stripped", function()
        assert.equal(ToolExecutor.parseTextSearch("  **SEARCH:** \"weather Boston yesterday\"\n"), "weather Boston yesterday")
        assert.equal(ToolExecutor.parseTextSearch("`SEARCH: foo bar`"), "foo bar")
    end),

    test("parse: a short preamble line before SEARCH is tolerated", function()
        local reply = "I'm not sure about this. Let me search for it.\n\nSEARCH: Da Shi character The Three-Body Problem"
        assert.equal(ToolExecutor.parseTextSearch(reply), "Da Shi character The Three-Body Problem")
    end),

    test("parse: real answers are not mistaken for searches", function()
        assert.equal(ToolExecutor.parseTextSearch("Search: the act of looking for something"), nil)
        assert.equal(ToolExecutor.parseTextSearch("The Dark Forest is the second book of the trilogy."), nil)
        assert.equal(ToolExecutor.parseTextSearch("SEARCH:"), nil)
        assert.equal(ToolExecutor.parseTextSearch("one\ntwo\nthree\nSEARCH: x"), nil, "too many lines")
        assert.equal(ToolExecutor.parseTextSearch(string.rep("Long answer text. ", 30) .. "\nSEARCH: x"), nil, "too long")
        assert.equal(ToolExecutor.parseTextSearch(nil), nil)
    end),

    -- =========================================================================
    -- ensureTextSearchPrompt
    -- =========================================================================

    test("ensure: instruction appended to the last user message once", function()
        local history = {
            { role = "system", content = "sys" },
            { role = "user", content = "question" },
        }
        ToolExecutor.ensureTextSearchPrompt(history)
        assert.equal(history[1].content, "sys", "system prompt untouched")
        assert.matches(history[2].content, "^question")
        assert.matches(history[2].content, "SEARCH:")
        local once = history[2].content
        ToolExecutor.ensureTextSearchPrompt(history)
        assert.equal(history[2].content, once, "not appended twice")
        assert.equal(ASUtils.get_attr(history[2], "text_search_prompt"), true)
    end),

    test("ensure: nothing happens when the last message is not a user string", function()
        local history = { { role = "assistant", content = "answer" } }
        ToolExecutor.ensureTextSearchPrompt(history)
        assert.equal(history[1].content, "answer")
        assert.equal(#history, 1)
    end),

    -- =========================================================================
    -- appendTextSearchResult
    -- =========================================================================

    test("append: assistant call and user result messages", function()
        local history = { { role = "user", content = "q" } }
        ToolExecutor.appendTextSearchResult(history, "SEARCH: foo", "foo", "## results")
        assert.equal(#history, 3)
        assert.equal(history[2].role, "assistant")
        assert.equal(history[2].content, "SEARCH: foo")
        assert.matches(ASUtils.get_attr(history[2], "search_keywords"), "foo")
        assert.equal(history[3].role, "user")
        assert.matches(history[3].content, "WEB SEARCH RESULTS for: foo")
        assert.matches(history[3].content, "## results")
        assert.equal(ASUtils.get_attr(history[3], "is_search_result"), true)
    end),

    test("prompt text exists and mentions the protocol", function()
        assert.notNil(Prompts.text_search_prompt)
        assert.matches(Prompts.text_search_prompt, "SEARCH: <concise query>")
    end),
}

return helper.runTests("text_search", tests)
