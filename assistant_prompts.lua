local _ = require("assistant_gettext")
local T = require("ffi/util").template
-- preconfigured prompts for various tasks

-- Custom prompts for the AI
-- Available placeholder for user prompts:
-- {title}  : book title from metadata
-- {author} : book author from metadata
-- {highlight}  : selected texts
-- {language}   : the `response_language` variable defined above
-- {user_input} : user input from the input dialog
-- {progress}   : the progress percentage of the book
--
-- text: text to display on the button in the UI.
-- order: order of the button in the UI, higher number means later in the list.
-- show_on_main_popup: if true, the button will be shown in the main popup dialog.
-- show_suggestions: if true, suggested follow-up questions will be appended (requires global auto_prompt_suggest enabled).

local markdown_format_prompt = [[
### Formatting Constraint
Do not use LaTeX math blocks (like $...$) for standard text or emphasis. Never wrap plain words in $\\textit{...}$ or $\\texttt{...}$. 
Standard Markdown formatting (including quotes, tables, lists) is fully supported and encouraged where appropriate.
]]

-- prompts attributes can be overridden in the configuration file.
local builtin_prompts = {
    term_xray = {
        text = _("Term X-Ray"),
        use_websearch = true,
        use_book_context = false,
        show_suggestions = false,
        order = -20, -- negative number to not show on additional questions dialog
        desc = _("This prompt creates a structured system for generating context-aware definitions of words or phrases from literature by analyzing the highlighted term within its surrounding text to provide nuanced explanations that capture both literal meaning and contextual significance."),
        system_prompt = markdown_format_prompt,
        user_prompt = T([[
## Your Role
You are the "Term X-Ray" of a reading app. Explain what "{highlight}" is in "{title}" by {author}, using ONLY the passages from the book supplied below. They are the passages up to the reader's current position that mention the term ({coverage}), in book order: the first passage is where the term is introduced, the last ones are the most recent.

## Guidelines
1. **Context-bound**: rely only on the passages. Do not use outside knowledge of the book, and never mention anything that could come later in the story.
2. **Pronouns**: resolve he/she/it/they/this carefully to track who does what to "{highlight}".
3. **Chronology**: the passages are in reading order; use that to show how the term develops.
4. **Language**: write the entire response, including headers, in {language}.

## Structure
About 250-400 words of fluent present-tense prose under these headers, no bullet lists:

### %1
What "{highlight}" is: character, object, place, faction or concept, with its core traits, appearance or rules as the passages show them.

### %2
What it does in the story: actions, motives, uses, effects, and its relationships with other characters or elements.

### %3
How the picture of it changes from the first mention to the most recent one, and where it stands right now at the reader's position.

### %4
What the passages leave unclear or unanswered (two or three lines at most).

## Inputs
* **User Input**: {user_input}
* **Passages from the Book** ({coverage}):
{context}
]],
        -- @translators term_xray section headers
            -- @translators term_xray: "What It Is" section header
            _("What It Is"),
            -- @translators term_xray: "Role & Function" section header
            _("Role & Function"),
            -- @translators term_xray: "Evolution & Connections" section header
            _("Evolution & Connections"),
            -- @translators term_xray: "Context Limitations" section header
            _("Context Limitations"))
    },
    dictionary = {
        order = -10, -- negative number indicates a stub prompt
        text = _("Dictionary"),
        use_websearch = false,
        use_book_context = false,
        show_suggestions = false,
        desc = _("This prompt acts as a dictionary for the highlighted text, to a word or phrase."),
        -- this prompt is a stub (will not shown in follow-up questions)
        -- it will be replaced by the actual prompt in the code below
    },
    quick_note = {
        order = 5, --should be visible on additional questions dialog
        text = _("Quick Note"),
        use_book_context = false,
        show_suggestions = false,
        desc = _("This button creates a quick note with highlighted text."),
        user_prompt = "", --dummy prompt
        -- this prompt is a stub
    },
    vocabulary = {
        text = _("Vocabulary"),
        use_websearch = false,
        use_book_context = false,
        show_suggestions = false,
        order = 10,
        desc = _(
            "This prompt analyzes the vocabulary of the highlighted text, identifying complex words and providing definitions, synonyms, and usage examples."),
        user_prompt = [[
**Your Task:** Analyze the Input Text below. Find words/phrases that are B2 level or higher. Ignore common words (B1 level) and proper nouns.

**Output Requirements:**
1.  For each difficult word/phrase found:
    *   Correct any typos.
    *   Convert it to its base form (e.g., "go", "dog", "good", "kick the bucket").
    *   List up to 3 simple synonyms (suitable for B1+ learners). Do not reuse the original word.
    *   Explain its meaning simply **in {language}**, considering its context in the text. Do not reuse the original word in the explanation.
2.  Format: Create a numbered list using this exact structure for each item:
    `index. __base form__: synonym1, synonym2, synonym3 : {language} explanation`
3.  Output Content: **ONLY** provide the numbered list. Do not include the original text, titles, or any extra sentences.

**Input Text:** {highlight} ]],
    },
    grammar = {
        text = _("Grammar"),
        use_websearch = false,
        use_book_context = false,
        show_suggestions = false,
        order = 20,
        desc = _(
            "This prompt analyzes the grammar of the highlighted text, providing a detailed explanation of its structure and any grammatical errors."),
        system_prompt = markdown_format_prompt,
        user_prompt = T([[You are a Grammar Expert. Analyze the text below and output strictly in the following structure. 
        
* **Language**: Render the *entire* response (including headers) completely in {language}.

### 1. %1
* **Sentence Type**: (e.g., Simple, Compound, Complex)
* **Analysis**: Explain the clause relationships and main syntax framework.

### 2. %2
* Break down key phrases, identifying word classes, verb tenses, and morphology.

### 3. %3
* **Error**: "[Incorrect segment]"
* **Correction**: "[Corrected version]"
* **Rule**: Explain the violated grammar rule. *(If flawless, state: "No errors detected.")*

---
**Text to Analyze:**
{highlight}
]],
            -- @translators grammar section headers
            _("Structure & Clauses"),
            _("Parts of Speech & Tenses"),
            _("Error Correction (If Applicable)"))
    },
    translate = {
        order = 30,
        text = _("Translate"),
        use_websearch = false,
        use_book_context = false,
        show_suggestions = false,
        desc = _("This prompt translates the highlighted text to another language."),
        user_prompt = [[You are a professional translator. Translate the text below into {language}.

**Rules:**
* **Fluency**: Focus on natural, idiomatic expression and preserve the original tone (formal/casual/technical) rather than word-for-word translation.
* **Output**: Return ONLY the translated text. Do NOT include any explanations, introduction, or notes.

---
**Source Text:**
{highlight} ]],
    },
    summarize = {
        text = _("Summarize"),
        use_websearch = false,
        use_book_context = true,
        show_suggestions = false,
        order = 40,
        desc = _("This prompt summarizes the highlighted text, capturing its main points and essential details."),
        user_prompt = [[
You are a summarization expert. Provide a concise and clear summary of the text below.

**Rules:**
* **Language**: Render the *entire* response (including headers) completely in {language}.
* **Content**: Capture all main points and essential details while eliminating all fluff and redundant info.
* **Output**: Deliver only the direct summary without any introductory phrases or meta-commentary.

---
**Text to Summarize:**
{highlight}
]],
    },
    simplify = {
        text = _("Simplify"),
        use_websearch = false,
        use_book_context = false,
        show_suggestions = false,
        order = 50,
        desc = _("This prompt simplifies the highlighted text to make it easier to understand."),
        user_prompt = [[ You are a linguistic expert. Simplify the text below to maximize readability and clarity.

**Rules:**
* **Language**: Render the *entire* response (including headers) completely in {language}.
* **Content**: Retain the exact original meaning and all critical info. Do NOT omit key facts.
* **Style**: Remove verbose phrasing and unnecessary jargon. Make it highly accessible, clear, and easy to read.
* **Output**: Return only the simplified text.

---
**Text to Simplify:**
{highlight} ]],
    },
    key_points = {
        text = _("Key Points"),
        use_websearch = false,
        use_book_context = true,
        show_suggestions = true,
        order = 60,
        desc = _(
            "This prompt extracts and lists the key points from the highlighted text, ensuring clarity and organization."),
        user_prompt = T([[ You are a Key Points Expert. Extract the core insights from the text below into a clean list.

**Rules:**
* **Content**: Capture all critical arguments, essential facts, and conclusions. Eliminate all fluff.
* **Format**: Present as a well-organized, easy-to-read bulleted list. Each point must be concise and independent.
* **Language**: Render the *entire* response (including headers) completely in {language}.
* **Output**: Return only the bulleted list without any introductory text.

**Output Structure:**
### %1
* (Key insights and main arguments of the text...)

### %2
* (Crucial data, facts, or final statements...)

---
**Text to Extract:**
{highlight}
]],
            -- @translators key_points section headers
            _("Core Arguments"),
            _("Essential Facts & Conclusions"))
    },
    ELI5 = {
        text = _("ELI5"),
        use_websearch = false,
        use_book_context = true,
        show_suggestions = true,
        order = 70,
        desc = _(
            "This prompt explains the highlighted text as if to a five-year-old, simplifying complex concepts into easily understandable terms."),
        user_prompt = T([[ You are an ELI5 (Explain Like I'm 5) Expert. Explain the concept below as if speaking to a curious child.

**Rules:**
* **Simplicity**: Strip away all jargon and technicalities. Use plain, everyday language and short sentences.
* **Analogy**: Use a simple, relatable real-world analogy to make the core idea instantly clear.
* **Language**: Render the *entire* response (including headers) completely in {language}.
* **Output**: Be direct and concise. Return only the explanation without any conversational filler.

**Output Structure:**
### %1
(Explain the concept in 1-2 very simple, jargon-free sentences.)

### %2
(Provide a relatable, real-world analogy to make the concept instantly clear.)

---
**Concept to Explain:**
{highlight} ]],
            -- @translators ELI5 section headers
            _("Core Idea"),
            _("Fun Analogy"))
    },
    explain = {
        text = _("Explain"),
        use_websearch = true,
        use_book_context = true,
        show_suggestions = true,
        order = 80,
        desc = _("This prompt explains the highlighted text in detail, ensuring clarity and understanding."),
        user_prompt = [[You are an expert Explainer. Provide a clear and comprehensive explanation of the text below.

**Rules:**
* **In the book**: The text is from "{title}" by {author}. Explain it as it works there: resolve who and what it refers to using what the reader has met so far, and never reveal anything later in the book.
* **Depth**: Fully break down the meaning, including complex terms, underlying concepts, and implicit nuances. 
* **Language**: Render the *entire* response (including headers) completely in {language}.
* **Format**: Use a mix of fluid prose and clean Markdown structure (like bullet points) for maximum clarity.
* **Output**: Start directly with the explanation; do not include introductory text or meta-commentary.

---
**Text to Explain:**
{highlight} ]],
    },
    historical_context = {
        text = _("Historical Context"),
        use_websearch = true,
        use_book_context = true,
        show_suggestions = true,
        order = 90,
        desc = _(
            "This prompt provides a detailed historical context for the highlighted text, explaining its significance and background."),
        user_prompt = T([[You are a Historical Context Expert. The text below is from "{title}" by {author}. Analyze it and explain its precise historical framework (the period the book depicts, and the period it was written in when that differs). Do not reveal later events of the book.

**Rules:**
* **Language**: Render the *entire* response (including headers) completely in {language}.
* **Output**: Start directly with the analysis. Avoid introductory phrases or meta-commentary.

**Output Structure:**
### 1. %1
(Identify the historical period, major global/local events, and the societal structures or prevailing ideologies of that time.)

### 2. %2
(Explicitly connect these historical elements to the text's content, characters, themes, or underlying messages.)

### 3. %3
(Explain the cultural environment or evolution that shaped this text and how the text reflects or challenges it.)

---
**Text to Analyze:**
{highlight}]],
            -- @translators historical_context section headers
            _("Era & Background"),
            _("Contextual Connections"),
            _("Cultural Significance"))
    },
    wikipedia = {
        text = _("Wikipedia"),
        use_websearch = true,
        use_book_context = false,
        show_suggestions = true,
        order = 100,
        desc = _(
            "This prompt generates a comprehensive Wikipedia-style article based on the highlighted text, ensuring factual accuracy and neutrality."),
        user_prompt =
[[You are an objective, encyclopedic Informative Assistant in the style of Wikipedia.

**Task:**

* When given a topic, generate a factual, neutral, and comprehensive article.
* Begin with a concise introduction summarizing the topic.
* Cover key aspects: history, concepts, applications, notable events, or impacts.
* Maintain Wikipedia’s tone and structure throughout.

**Research instructions:**

* If your knowledge may be incomplete or outdated, **prioritize retrieving information from web search** to ensure accuracy.
* Verify facts with reputable sources; avoid speculation or unverifiable claims.

**Output:**

* Provide structured, clear, and coherent content.
* Deliver entirely in {language} (including headers).

Topic to cover (from user selection): {highlight}]],
    },
}


local assistant_prompts = {
    default = {
        show_suggestions = true,
        -- fork: a real role for the free "Ask" dialog instead of the bare
        -- formatting note (title/author/position are added by the dialog).
        system_prompt = markdown_format_prompt .. [[
### Role
You are a reading companion inside an e-reader app. The reader is in the middle of a book; its title, author and their position are given when known. Assume they have read only up to that position: never reveal or hint at anything later in the book unless they explicitly ask for spoilers. Be precise and concise (the screen is small), answer the question that was asked, and skip praise, preamble and closing remarks. No emojis.
]],
    },
    recap = {
        -- fork: the book text is the ground truth, a web search only adds latency
        use_websearch = false,
        show_suggestions = true,
        system_prompt = markdown_format_prompt .. [[
You are a careful literary assistant writing a recap for a reader who is returning to a book after time away. No emojis. Never reveal anything past the reader's current position.
]],
        user_prompt = [[
The reader is resuming **"{title}"** by **{author}**. They last opened it {time_away} ago and are **{progress}%** of the way through.

Write a thorough, spoiler-free recap in {language} so they can pick the book up again without re-reading. Scale the depth to how much has been read: short at 10%, long at 60%. Use exactly this structure:

## Where you are
Two or three sentences on the exact situation at the current position: scene, place, who is present, what is unresolved right now.

## The story so far
The whole arc from the beginning to the current position, in order, covering every major plot movement, not only the recent ones. About 150 words per 10% read, up to roughly 900 words. Bold names and places the first time they appear; italicise turning points.

## Recent events in detail
The last few chapters before the current position: what happened, what was revealed, what was decided. 300-500 words.

## People to remember
One line per significant character: who they are, their goal or allegiance, their last known situation. Include minor characters who are likely to reappear.

## Open threads
Unresolved questions, mysteries, promises and dangers to keep in mind going forward.

Rules:
- The book text supplied below is the ground truth for everything it covers. Use your own knowledge of the book only for the part before that text begins, and only what you are sure of.
- Strict no spoilers: nothing past the current position, even if you know the ending.
- Use the chapter list to keep events in the right order. Match the book's tone. No praise, no commentary, no preamble: return only the recap.
]]
    },
    xray = {
        use_websearch = false, -- fork: the book text is the ground truth
        show_suggestions = true,
        system_prompt = markdown_format_prompt,
        user_prompt = T([[
You are the "X-Ray" of a reading app for **{title}** by **{author}**. The reader is **{progress}%** through. Everything you write must be spoiler-free beyond that point, even if you know the rest of the book.

Ground truth: the book text supplied below, with the chapter list. Use your own knowledge of the book only for the part before the excerpt begins, and only what you are sure of. Do not invent characters, places or events.

Required structure, all headers in {language}:

### %1
8-15 bullets, most important first:
- **Name** — who they are and what they want (2-3 sentences), then _relationships_ in italics (e.g. _sister of X, distrusts Y_), and their situation at the current position.

### %2
6-10 bullets:
- **Place** — what it is (1-2 sentences), _what happened there_.

### %3
5-8 bullets:
- **Theme** — how it shows up so far (2 sentences).

### %4
5-10 bullets for in-world terms, factions, technologies, objects and symbols:
- **Term** — concise definition and why it matters.

### %5
8-12 turning points up to the current position, in order, tied to chapters when the chapter list allows:
- **Chapter X:** one sentence.
Only real turning points, not a chapter-by-chapter list.

### %6
* **%7** 2 sentences
* **%8** 1 sentence
* **%9** 1 sentence
* **%10** 1 sentence (object, place or symbol)
* **%11** 1 sentence
* **%12** 1-3 short questions

Rules: nothing past {progress}%; bold names and places; no emojis; answer entirely in {language} and return only the X-Ray.
        ]],
            -- @translators xray section headers
            _("Characters"),
            _("Locations"),
            _("Main Themes"),
            _("Terms & Concepts"),
            _("Timeline"),
            _("Re-immersion"),
            -- @translators xray Re-immersion sub-fields
            _("Where the action stopped:"),
            _("Protagonist's current objective:"),
            _("Open conflict or mystery:"),
            _("Narrative element in focus:"),
            _("Prevailing emotional state/tone:"),
            _("Outstanding questions:"))
    },
    book_info = {
        use_websearch = true,
        show_suggestions = true,
        system_prompt = markdown_format_prompt,
        user_prompt = T([[You are an objective reference assistant inside a reading app. Give structured information about "{title}" by {author}. Write everything, including headers, in {language}.

Sources: use your own knowledge for well-known books and authors. If the book or author is obscure or recent, or you are unsure of a fact, use the web search (one or two queries). If search is unavailable, answer from what you know and mark unconfirmed items "not confirmed". Never invent ratings, dates or publishers.

### 1. %1
* **%2**:
* **%3**: (first publication; original language and title if translated)
* **%4**:
* **Series**: position in a series, or "standalone"
* **Length**: approximate page count and reading time
* **%5**: a back-cover style summary of the premise only, 3-5 sentences, nothing beyond the opening

### 2. %6
* Two or three sentences on the author and their style, and 2-4 notable other works.

### 3. %7
* When and where it was written and set, and how that shapes the themes. Major awards or reception in one line, if known.

### 4. %8
* 3-5 similar books, each with one line on why.

Neutral tone, no emojis, no preamble.]],
            -- @translators book_info section headers and sub-fields
            _("Book Information"),
            _("Genre"),
            _("Publication Date"),
            _("Publisher"),
            _("Plot Summary"),
            _("About the Author"),
            _("Historical and Cultural Context"),
            _("Similar Books Recommendations"))
    },
    annotations = {
        use_websearch = false,
        show_suggestions = false,
        system_prompt = markdown_format_prompt,
        user_prompt = T([[
You are given my highlights and notes from "{title}" by {author}, in reading order. Analyse them and write, in {language}:

Start with a concise **executive summary** (3-5 sentences) of what my highlights show I found important.

1. **%1**
   - The most important insights, lessons or narrative developments, grouped by theme rather than listed one highlight at a time.
   - Recurring themes, turning points, critical information.

2. **%2**
   - Fiction: themes to reflect on, characters to watch, related reading.
   - Non-fiction: concrete actions, habits, ideas to research or apply.

3. **%3**
   - How my highlights connect to the book's larger narrative or argument, and open questions or earlier chapters worth revisiting.

End with **%4** as bullet points. Quote a highlight verbatim only when the wording matters. Do not reveal anything from the book beyond what my highlights cover. Clear, thoughtful, practical tone; no preamble, no emojis.
]],
            -- @translators annotations section headers
            _("Key Takeaways"),
            _("To-Do / Action Items"),
            _("Contextual Notes"),
            _("Contextual Notes / Reflections"))
    },
    summary_using_annotations = {
        use_websearch = false, -- fork: the book text is the ground truth
        show_suggestions = false,
        system_prompt = markdown_format_prompt,
        user_prompt = T([[
You are a meticulous book summarizer and analyst.

INPUTS:
- book_text: the book text up to my current position (it states which part of the book it covers); it is the ground truth, and nothing beyond my position may be revealed
- highlights: a list of highlighted passages and my personal notes

YOUR TASK:
Produce a **structured summary** that integrates the highlights naturally into the book summary.
Do not separate highlights into a final section — instead, use a translated summary of each highlight inside the summary to emphasize them at the right place.

STYLE & RULES:
1. Language → Always respond in {language}.
2. TL;DR → Begin with a 2–3 sentence overall summary of the book’s main message.
3. Integrated Summary:
   - Provide a clear, logical summary of the book.
   - Each time you encounter a highlight, render the exact highlighted text in **bold**.
   - Immediately after the bold text, paraphrase it and explain why it matters in the context of the book.
   - If a highlight has a note, include it in *italic parentheses* right after your explanation.
   - Maintain flow: highlights must feel naturally embedded, not forced.
4. Key Points:
   - After the integrated summary, list the 8–12 most important insights in bullet form.
   - Incorporate highlights into the list (again in **bold**), paraphrased where helpful.
5. Actionable Takeaways:
   - Provide 5–8 clear, practical lessons or insights the reader can apply.
6. Tone:
   - Clear, thoughtful, and practical.
   - Never copy the entire book verbatim; focus on essence and integration of highlights.
7. Contradictions:
   - If a highlight conflicts with the book text, mark it with **[!]** and briefly note the possible interpretation.
   - If a highlight is not related to the book text (if it is not in the book text), ignore it.

OUTPUT STRUCTURE:
- %1
- %2
- %3
- %4
- %5 (if any)

IMPORTANT:
- Always weave highlights *inline*, never at the end.
- Keep formatting consistent (Markdown headings, bold highlights, italic notes).
- If the text is extremely long, compress intelligently while still reflecting highlights.

Now begin the analysis with the provided book_text and highlights.]],
            -- @translators summary_using_annotations output structure sections
            _("TL;DR"),
            _("Integrated Summary"),
            _("Key Points"),
            _("Actionable Takeaways"),
            _("Contradictions / Open Questions"))
    },

    dict = {
        use_websearch = true,
        show_suggestions = false,
        system_prompt = markdown_format_prompt,
        user_prompt = T([[
## Task
Explain "{word}" as used in "{title}" by {author}, based on the context below. The selection may be inflected, derived, misspelled or part of a phrase.

## Context from the Book
{context}

## Rules
1. Write everything, including headers, in {language}; the example sentence in "%6" may stay in the language of the book.
2. Lead with the meaning that fits this sentence. Keep every section short: this is read on a small e-ink screen.
3. Analyse the word form: surface form, part of speech and grammatical features, lemma (infinitive / singular / positive), and the morphological base for derived words (e.g. `recognition` is the noun of the verb `recognize` + `-tion`). Correct an obvious misspelling or OCR error and say so; never derive from a misspelling, and say when the intended word is uncertain.
4. Contrast the general meaning with how this book uses the word (narrative, tone, worldbuilding) without revealing anything later in the book.
5. Start directly with the first section; no preamble or closing remarks.

## Output Structure
Use a normal Markdown heading (`###`) for every section and bullets (`-`) only for lists.

### %3
The meaning that fits here in one or two sentences, then the general dictionary meaning if it differs.

### %2
Up to three simple synonyms; mark the one that best fits the book's usage.

### %1
Surface form, correction if any, part of speech and features, lemma, morphological base.

### %4
The whole sentence containing the word, translated, with **{word}** in bold (no spaces inside the markers).

### %5
How "{word}" works in this book and what it suggests about the character, tone or theme.

### %6
One original example sentence, preferably in the same genre.

### %7
Etymology in two or three lines; say when it is uncertain.
]],
            -- @translators used in the dictionary.
            _("Word Form & Lemma"),
            _("Synonyms"),
            _("Meaning"),
            _("Translation"),
            _("Book Usage"),
            _("Example"),
            _("Word Origin"))
    },
    suggestions_prompt = [[

### Suggested Questions
Write your full answer FIRST. At the very end of your response, provide 2-3 follow-up questions based on your answer that the user might want to ask next. This MUST be the LAST section of your response. NEVER put suggestions at the beginning. Nothing must appear after the closing `</suggestions>` tag.
Wrap this entire section inside a `<suggestions>` tag, with each question on a new line starting with a dash (-).

<suggestions>
- [Question 1]
- [Question 2]
- [Question 3]
</suggestions>

]],
    maximum_tool_use_prompt = [[

## Force Final Answer After Max Web Search Limit

You have already used the assistant_web_search tool the maximum allowed times. You must now STOP making any further assistant_web_search calls or any other tool calls that would require additional external searches.

Synthesize a complete, helpful, and well-structured final answer using ONLY the information you have already gathered from previous searches and your internal knowledge. 

Do not mention tool limits, search counts, or the fact that you stopped searching. Present the response naturally as a confident, comprehensive answer to the user's original question. If some aspects remain uncertain due to limited search results, briefly acknowledge that and provide the best possible response based on available data.

Begin writing the final answer now.

]],
    -- fork: text-protocol search for providers without function calling
    -- (see Querier:query / ToolExecutor.parseTextSearch)
    text_search_prompt = [[


---
Web search is available to you in this app: if answering needs current, recent or niche facts you do not know, make your ENTIRE reply exactly one line, `SEARCH: <concise query>`, and nothing else. The app will run the search and send you the results in the next message, after which you answer in full. Do not search for well-known books, authors or facts, and never say you lack internet access: search instead.]]
}


local function table_merge(t1, t2)
    local result = {}
    for k, v in pairs(t1) do
        result[k] = v
    end
    for k, v in pairs(t2) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = table_merge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end


local function table_sort(t, key)
    table.sort(t, function(a, b)
        if a[key] == nil or b[key] == nil then
            return false
        end
        return a[key] < b[key]
    end)
end


local WEBSEARCH_ICON = "🌐"

local M = {
    builtin_prompts = builtin_prompts,       -- Built-in prompts for the AI
    assistant_prompts = assistant_prompts, -- Preconfigured prompts for the AI
    merged_prompts = nil,                  -- Merged prompts from builtin and configuration
    sorted_prompts = nil,                  -- Sorted merged prompts
    WEBSEARCH_ICON = WEBSEARCH_ICON,
}

M.isWebSearchEnabled = function(settings)
    return settings:readSetting("use_websearch", "none") ~= "none"
end

M.isSuggestionsEnabled = function(settings, prompt_config)
    if not settings:readSetting("auto_prompt_suggest", false) then return false end
    if prompt_config ~= nil and prompt_config.show_suggestions ~= nil then
        return prompt_config.show_suggestions and true or false
    end
    local def = M.assistant_prompts and M.assistant_prompts.default and M.assistant_prompts.default.show_suggestions
    if def ~= nil then
        return def and true or false
    end
    return true
end

M.getDisplayText = function(text, use_websearch, web_search_enabled)
    if use_websearch and web_search_enabled then
        return WEBSEARCH_ICON .. text
    end
    return text
end

M.invalidateCache = function()
    M.merged_prompts = nil
    M.sorted_prompts = nil
end

-- Func description:
-- This function returns the merged prompts from the configuration and builtin prompts.
-- It merges the builtin prompts with the configuration prompts, if available.
-- return table of merged prompts
-- Example: { translate = { text = "Translate", user_prompt = "...", order = 1, show_on_main_popup = true }, ... }
M.getMergedPrompts = function(conf_prompts)
    if M.merged_prompts then
        return M.merged_prompts
    end

    -- Merge builtin prompts with configuration prompts
    if conf_prompts then
        M.merged_prompts = table_merge(builtin_prompts, conf_prompts)
    else
        M.merged_prompts = builtin_prompts
    end

    return M.merged_prompts
end

-- Func description:
-- This function returns a list of merged prompts sorted by their order.
-- filter_func: optional function to filter prompts, if it returns false, the prompt will be skipped.
-- web_search_enabled: optional boolean, if true and a prompt has use_websearch=true,
--                     the 🌐 icon is prepended to the display text.
-- return list item: {idx, order, text}
M.getSortedPrompts = function(filter_func, web_search_enabled)
    if M.sorted_prompts then
        return M.sorted_prompts
    end

    -- Sort the merged prompts by order
    local sorted_prompts = {}
    for prompt_index, prompt in pairs(M.merged_prompts or builtin_prompts) do
        -- Only add the prompt if there is no filter, or if the filter function returns true.
        if not filter_func or filter_func(prompt, prompt_index) == true then
            local display_text = prompt.text or prompt_index
            if web_search_enabled and prompt.use_websearch then
                display_text = WEBSEARCH_ICON .. display_text
            end
            table.insert(sorted_prompts,
                {
                    idx = prompt_index,
                    order = prompt.order or 1000,
                    text = display_text,
                    desc = prompt
                        .desc or ""
                })
        end
    end
    table_sort(sorted_prompts, "order")

    return sorted_prompts
end

return M
