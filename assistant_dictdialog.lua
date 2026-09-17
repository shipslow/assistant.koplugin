local logger = require("logger")
local InputDialog = require("ui/widget/inputdialog")
local ChatGPTViewer = require("assistant_viewer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("assistant_gettext")
local T = require("ffi/util").template
local Event = require("ui/event")
local koutil = require("util")
local ASUtils = require("assistant_utils")
local dict_prompts = require("assistant_prompts").assistant_prompts.dict
local Prompts = require("assistant_prompts")

local function showDictionaryDialog(assistant, highlightedText, message_history, prompt_type)
    local Querier = assistant.querier
    local ui = assistant.ui

    -- Prefer already-loaded querier; fallback to getActiveProviderId.
    local provider = (assistant.querier and assistant.querier.provider_name
                      and assistant.querier:is_inited())
                     and assistant.querier.provider_name
                     or assistant.config:getActiveProviderId()
    if not provider then
        UIManager:show(InfoMessage:new{ icon = "notice-warning",
            text = _("No active provider configured. Please add one in Settings.") })
        return
    end
    local ok, err = Querier:load_model(provider)
    if not ok then
        UIManager:show(InfoMessage:new{ icon = "notice-warning", text = err })
        return
    end

    -- Handle case where no text is highlighted (gesture-triggered)
    local input_dialog
    if not highlightedText or highlightedText == "" then
        -- Show a simple input dialog to ask for a word to look up
        input_dialog = InputDialog:new{
            title = _("AI Dictionary"),
            input_hint = _("Enter a word to look up..."),
            input_type = "text",
            buttons = {
                {
                    {
                        text = _("Cancel"),
                        callback = function()
                            UIManager:close(input_dialog)
                        end,
                    },
                    {
                        text = _("Look Up"),
                        is_enter_default = true,
                        callback = function()
                            local word = input_dialog:getInputText()
                            UIManager:close(input_dialog)
                            if word and word ~= "" then
                                -- Recursively call with the entered word
                                showDictionaryDialog(assistant, word, message_history)
                            end
                        end,
                    },
                }
            }
        }
        UIManager:show(input_dialog)
        input_dialog:onShowKeyboard()
        return
    end

    local message_history = message_history or {}

    -- Set up system prompt based on prompt type
    if #message_history == 0 then
        local system_prompt
        if prompt_type == "term_xray" then
            local term_xray_prompts = require("assistant_prompts").builtin_prompts.term_xray
            system_prompt = term_xray_prompts.system_prompt
        else
            system_prompt = dict_prompts.system_prompt
        end

        table.insert(message_history, {
            role = "system",
            content = system_prompt,
        })
    end

    -- Get context for the selected word
    local prev_context, next_context = "", ""
    local context_text = ""
    local context_sentence_count = 0
    local term_xray_coverage = ""
    local dict_language = assistant.settings:readSetting("dict_language") or assistant.ui_language

    if prompt_type == "term_xray" then
        -- Show loading dialog immediately so the app does not look frozen while the context is built
        local context_loading_msg = InfoMessage:new{
            icon = "book.opened",
            text = ASUtils.bold_format(_("<b>Analyzing book context for Term X-Ray...</b>")),
        }
        UIManager:show(context_loading_msg)
        UIManager:forceRePaint()  -- Force immediate display before the blocking extraction

        -- fork: mention passages instead of LexRank. LexRank ranked every
        -- sentence of the book on the device CPU, selected nearly all of them and
        -- then kept the FIRST 100k characters, so a term highlighted late in a
        -- long book got the beginning of the book as its context.
        local book_text = ASUtils.extractBookTextForAnalysis(assistant)
        local mentions_text, mention_count, shown_passages, total_passages
        if book_text and #book_text > 100 then
            local context_before = assistant.config:getFeature("term_xray_context_sentences_before", 5)
            local context_after = assistant.config:getFeature("term_xray_context_sentences_after", 5)
            local max_characters = assistant.config:getFeature("term_xray_max_characters", 100000)
            mentions_text, mention_count, shown_passages, total_passages = ASUtils.extractTermMentions(
                book_text, highlightedText, dict_language, context_before, context_after, max_characters)
        end
        if mentions_text and mention_count > 0 then
            context_text = mentions_text
            context_sentence_count = mention_count
            term_xray_coverage = string.format("%d mentions in %d passages", mention_count, total_passages)
            if shown_passages < total_passages then
                term_xray_coverage = term_xray_coverage
                    .. string.format("; showing the first passage and the %d most recent", shown_passages - 1)
            end
        else
            -- The term was not found in the text before the reading position:
            -- fall back to the words around the selection.
            local ok_ctx, prev, nxt = pcall(function() return ui.highlight:getSelectedWordContext(50) end)
            if ok_ctx then
                prev_context, next_context = prev or "", nxt or ""
            end
            context_text = prev_context .. highlightedText .. next_context
            term_xray_coverage = "the term was not found earlier in the book; only the surrounding text is given"
        end

        -- Close the context loading dialog
        UIManager:close(context_loading_msg)
    else
        -- Standard dictionary context extraction
        if ui.highlight and ui.highlight.getSelectedWordContext then
            -- Helper function to count words in a string.
            local function countWords(str)
                if not str or str == "" then return 0 end
                local _, count = string.gsub(str, "%S+", "")
                return count
            end

            local use_fallback_context = true
            -- Try to get the full sentence containing the word. If `getSelectedSentence()` doesn't exist,
            -- the code will gracefully use the fallback method.
            if ui.highlight.getSelectedSentence then
                local success, sentence = pcall(function() return ui.highlight:getSelectedSentence() end)
                if success and sentence then
                    -- Find the selected word in the sentence to split it.
                    local word_start, word_end = string.find(sentence, highlightedText, 1, true)
                    if word_start then
                        local prev_part = string.sub(sentence, 1, word_start - 1)
                        local next_part = string.sub(sentence, word_end + 1)

                        -- Check if the sentence context is too short on both sides.
                        if countWords(prev_part) < 50 and countWords(next_part) < 50 then
                            -- The sentence is short, so we'll use the fallback to get more context.
                            use_fallback_context = true
                        else
                            -- The sentence provides enough context, so we'll use it.
                            prev_context = prev_part
                            next_context = next_part
                            use_fallback_context = false
                        end
                    end
                end
            end

            -- Use the fallback method (word count) if we couldn't get a good sentence context.
            if use_fallback_context then
                local success, prev, next = pcall(function()
                    return ui.highlight:getSelectedWordContext(50)
                end)
                if success then
                    prev_context = prev or ""
                    next_context = next or ""
                end
            end
        end
        context_text = prev_context .. highlightedText .. next_context
    end

    -- Get book information (shared by both branches)
    local prop = ui.document:getProps() or {}
    local book_title = prop.title or "Unknown Title"
    local book_author = prop.authors or "Unknown Author"

    -- Choose the appropriate prompt and context based on prompt type
    local user_prompt, context_content, title, loading_message
    if prompt_type == "term_xray" then
        local term_xray_prompts = require("assistant_prompts").builtin_prompts.term_xray
        user_prompt = term_xray_prompts.user_prompt
        context_content = context_text
        title = Prompts.getDisplayText(_("Term X-Ray"),
            term_xray_prompts.use_websearch or false,
            Prompts.isWebSearchEnabled(assistant.settings))
        loading_message = _("Loading Term X-Ray ...")
        local context_message = {
            role = "user",
            content = string.gsub(user_prompt, "{([%w_]+)}", {
                language = dict_language,
                context = context_content,
                context_sentence_count = context_sentence_count,
                coverage = term_xray_coverage,
                highlight = highlightedText,
                title = book_title,
                author = book_author,
                user_input = "",
            }),
        }
        table.insert(message_history, context_message)
    else
        user_prompt = dict_prompts.user_prompt
        context_content = prev_context .. highlightedText .. next_context
        title = _("Dictionary")
        loading_message = _("Loading AI Dictionary ...")
        local context_message = {
            role = "user",
            content = string.gsub(user_prompt, "{([%w_]+)}", {
                language = dict_language,
                context = context_content,
                word = highlightedText,
                title = book_title,
                author = book_author,
            }),
        }
        table.insert(message_history, context_message)
    end

    -- Query the AI with the message history
    local ret, err = Querier:query(message_history, loading_message)
    if err ~= nil then
        assistant.querier:showError(err, message_history)
        return
    end

    local function createResultText(highlightedText, answer)
        -- Limit prev_context to last 100 characters and next_context to first 100 characters
        local prev_context_limited = string.sub(prev_context, -100)
        local next_context_limited = string.sub(next_context, 1, 100)
        local normalized_answer = ASUtils.normalizeMarkdownHeadings(answer, 2, 6) or answer
        return T("... %1 **%2** %3 ...\n\n%4", prev_context_limited, highlightedText, next_context_limited, normalized_answer)
    end

    local result = createResultText(highlightedText, ret)
    local chatgpt_viewer

    local function handleAddToNote()
        if ui.highlight and ui.highlight.saveHighlight then
            local success, index = pcall(function()
                return ui.highlight:saveHighlight(true)
            end)
            if success and index then
                local a = ui.annotation.annotations[index]
                a.note = result
                ui:handleEvent(Event:new("AnnotationsModified",
                                    { a, nb_highlights_added = -1, nb_notes_added = 1 }))
            end
        end

        UIManager:close(chatgpt_viewer)
        if ui.highlight and ui.highlight.onClose then
            ui.highlight:onClose()
        end
    end

    chatgpt_viewer = ChatGPTViewer:new {
        assistant = assistant,
        ui = ui,
        title = title,
        text = result,
        onAddToNote = handleAddToNote,
        default_hold_callback = function ()
            chatgpt_viewer:HoldClose()
        end,
    }

    UIManager:show(chatgpt_viewer)
end

return showDictionaryDialog