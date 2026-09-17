# Fork notes

Fork of [omer-faruq/assistant.koplugin](https://github.com/omer-faruq/assistant.koplugin) (v1.17).

Changes on top of v1.17:

- **Text-protocol web search** (`tool_mode = "text"` on a provider) for endpoints and models
  without function calling: local models behind Ollama/llama.cpp-style servers, thin proxies,
  or bridges that ignore the OpenAI `tools` array. In text mode the plugin appends an
  instruction to the user turn; the model replies with exactly one line `SEARCH: <query>`,
  the plugin runs the configured search (SearXNG here), appends the results and asks again
  (max 3 rounds). The instruction sits in the user turn on purpose: backends that wrap the
  request in their own system prompt make models ignore it when it is in ours.
  `ToolExecutor.parseTextSearch` is strict (uppercase `SEARCH:` line, at most three short
  lines) so real answers are not mistaken for search requests.
- **`features.websearch`** in `configuration.lua` selects the search tool like `provider`
  selects the model (applied whenever the value changes; the settings menu still works).
- **SearXNG `max_results`** (default 10): SearXNG returns 30-50 hits, the tail is noise.
- **Recap**: structured long-form prompt built in (where you are / story so far scaled to
  progress / recent events / people / open threads), `{time_away}` placeholder from the
  auto-recap hook, web search off for the recap (the book text is the ground truth).
- **Reading position context** for recap and X-Ray: the current chapter and the chapter
  titles reached so far (from the TOC, top two levels) are sent with the book text, and the
  book-text excerpt states which part of the book it covers (e.g. "the 31% mark to 58%") so
  the model knows where its own knowledge has to fill in.
- **Term X-Ray context rebuilt**: upstream feeds the term through a LexRank pass
  (`assistant_lexrank.lua`, thresholds in `assistant_dictdialog.lua`) whose default thresholds
  (0.01, 99 % minimum selection, stage 3 adding every remaining candidate) select practically all
  sentences of the tail-truncated book text; the result is then cut to its *first* 100k
  characters. So the model got a generic slab of text from the start of the window rather than
  the passages about the term, and the ranking (a similarity matrix over up to 2,500 sentences,
  computed on the device CPU) bought nothing. The fork sends the passages that mention the term
  (5 sentences either side, merged, in book order, language-aware sentence splitting via the
  same per-language modules); over budget it keeps the first passage (introduction) and the most
  recent ones, and tells the model how many mentions/passages it is seeing (`{coverage}`).
  Measured on a Kindle: 0.1 s for 318k characters. `assistant_lexrank.lua` stays in the tree for
  other uses; the `lexrank_*` config keys no longer affect Term X-Ray.
- **Prompts reworked**: Ask gets a real role (reading companion, spoiler guard, concise for
  a small screen); X-Ray, Book info, Annotations, Summary-with-annotations, Explain,
  Historical context and the AI dictionary are grounded in the book text / title and
  keep to the reader's position; the dictionary leads with the meaning that fits the
  sentence; emoji headers removed (e-ink fonts render them as boxes); X-Ray and
  summary-with-annotations no longer web-search (the book text is the ground truth).
- **Engine position bug fixed** (upstream): after a book-text extraction crengine's
  bookmark stays at the start of the range even though the screen still shows the
  reading page; the next extraction then sees an empty range (and a later
  `gotoXPointer(that bookmark)` moves the reader to page 1). Only `gotoPage`/`gotoPos`
  put it right (`ASUtils.saveEnginePosition`/`restoreEnginePosition`, applied around every
  extraction). Found and verified on device with the HTTP inspector.
- **Ask framing**: "I have a question about this book" became "my question may be about
  this book or something else", so off-topic questions are answered instead of queried.
- **Request cap** for large bodies raised from 120 s to 300 s (`api_handlers/base.lua`):
  a full-text recap on a large model can take a couple of minutes.

---

# Assistant: AI Helper Plugin for KOReader
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/omer-faruq/assistant.koplugin)

A powerful plugin that lets you interact with AI language models (Claude, GPT-4, Gemini, DeepSeek, Ollama etc.) while reading. Ask questions about text, get translations, summaries, explanations and more - all without leaving your book.

<small>Originally forked from a deleted fork of AskGPT by zeeyado, then modified using WindSurf. That fork is now public and includes many updates: https://github.com/zeeyado/koassistant.koplugin </small>

## Features

- **Multiple AI Providers**: Support for:
  - Claude, OpenAI, Gemini, DeepSeek, etc.
  - OpenRouter, Ollama, etc.
  - Other OpenAI-compatible API services (Groq, NVIDIA, etc.)
- **Stream Mode**: Real-time responses from the API. Get the full LLM experience on e-ink devices.
- **Multiple Providers/Models**: Select different models or AI provider platforms in the UI.
- **Web Search Tool Calling**: LLMs search the web and improve the answer with real and updated information.
- **Built-in Prompts**:
  - **Translation**: Instantly translate highlighted text to any language
  - **Quick Actions**: One-click buttons for common tasks like summarizing or explaining
  - **Dictionary**: Get synonyms, context-aware dictionary explanations, and examples for the selected word. (thanks to [plateaukao](https://github.com/plateaukao))
  - **Term X-Ray**: For single word or phrase highlights, get the meaning of it based on the previously mentioned places. (thanks to [Michael Kucek](https://github.com/michael-kucek))
  - **Recap**: Get a quick recap of a book when you open it, for books that haven't been opened in 28 hours and are less than 95% complete. Also available via shortcut/gesture for on-demand access. Fully configurable prompts. (thanks to [jbhul](https://github.com/jbhul))
  - **X-Ray**: Generate a spoiler-free, structured book X-Ray up to your current progress, listing key characters, locations, themes, terms, a concise timeline, and a quick re-immersion section. Fully configurable prompts; available via shortcut/gesture.
- **Custom Prompts**: Create your own specialized AI helpers with their own quick actions and prompts. Possible for highlighted text and book-level.
- **Smart Display**: Automatically hides long text snippets for cleaner viewing
- **Markdown Support**: (thanks to [David Fan](https://github.com/d-fan))
- **"Add to Note" and "Copy to Clipboard"**: Easily add the entire response as a note to highlighted text or copy it for later use.
- **Quick Access**: Ability to access some custom prompts directly from the main highlight menu (configurable).
- **Gesture-Enabled Prompts**: You can assign gestures to **Ask**, **Recap**, and **X-Ray**. This enables the user to ask anything about the book without needing to highlight text first. It also enables triggering the recap at any time. Additionally, you can access these prompts through a [quick menu](https://koreader.rocks/user_guide/#L1-qmandprofiles) as well. (thanks to [Jayphen](https://github.com/Jayphen))
- **AI Dictionary Gesture**: Override the default "Translate" long-press gesture to use the AI Dictionary directly for instant definitions and context.
- **l10n Support**: Supports all languages that the KOReader project supports.

## Basic Requirements

- [KOReader](https://github.com/koreader/koreader) installed on your device
- API key from a LLM provider (Anthropic, OpenAI, Gemini, OpenRouter, DeepSeek, Ollama, etc.)
- (Optional) API key from a search api provider (Tavily, SerpAPI, SearXNG ...)

## Getting Started 

### 1. Get API Keys

See [Obtaining API Keys](../../wiki/Obtaining-API-Keys) from the wiki page.

### 2. Installation:

[Installation Guide](../../wiki/Installation)

Create/modify `configuration.lua` as needed.

### 3. Configure the Plugin

1. Copy `configuration.sample.lua` to `configuration.lua` (do not modify the sample file directly).
2. Edit the `configuration.lua` file as needed.
    - Set your API keys in `provider_settings`.
    - For more advanced configuration, see the Wiki Configuration.lua.

#### Using OpenAI-Compatible APIs

The plugin supports any OpenAI-compatible API through a flexible naming pattern. Configuration keys follow the format `{handler}_{description}`, where:
- **handler**: The API handler to use (e.g., `openai`, `anthropic`, `gemini`)
- **description**: Any descriptive name for your configuration (e.g., `perplexity`, `grok`, `local`)

**Examples:**
- `openai_perplexity` → uses the `openai` handler for Perplexity API
- `openai_grok` → uses the `openai` handler for Grok API
- `anthropic_websearch` → uses the `anthropic` handler with web search enabled

You can create multiple configurations using the same handler with different settings. The part before the first underscore determines which handler is used.

Here's the minimum working example:

```lua
local CONFIGURATION = {

    provider_settings = {
        gemini = {
            model = "gemini-2.5-flash",
            base_url = "https://generativelanguage.googleapis.com/v1beta/models/",
            api_key = "your-gemini-api-key",
        },
        -- You can add other providers here, for example:
        -- openai = {
        --     model = "gpt-4o-mini",
        --     base_url = "https://api.openai.com/v1/chat/completions",
        --     api_key = "your-openai-api-key",
        -- }
    }
}
return CONFIGURATION
```

### 4. Using the Plugin

#### Standard Usage

1. Open any book in KOReader
2. Highlight the text you want to analyze
3. Tap the highlight and select "AI Assistant"
4. Choose an action:
   - **Ask**: Ask a specific question about the text
   - **Custom Actions**: Use any prompts you've configured
       - **Translate**: Convert text to your configured language
5. **Additional Questions**: Ask additional questions about the highlighted text using your custom prompts

#### Using AI Dictionary with Gestures

You can set up a long-press gesture to open the AI Dictionary instantly, bypassing the highlight menu. This is done by overriding KOReader's built-in "Translate" action. (thanks to [Ilia Reutov](https://github.com/Agnesor))

1.  **Enable the Override**:
    *   Navigate to the top menu `Tools (🔧) > More tools`.
    *   Find and enable **Use AI Dictionary for 'Translate'**.

2.  **Set the Gesture**:
    *   Go to KOReader's main menu -> `Taps and gestures` -> `Gesture manager`.
    *   Select `Long-press on text`.
    *   Choose **"Translate"** from the list of actions.

Now, when you long-press a word, the AI Dictionary will open directly. To use the standard translation feature again, simply uncheck the override option in the Assistant plugin's menu.

#### Dictionary Popup Buttons

The Assistant plugin adds AI-powered buttons (Wikipedia, Term X-Ray, Dictionary, and custom prompts) to the dictionary popup when you look up words.

**Note**: In newer KOReader versions (2026.05+), dictionary popup buttons can be customized via **Dictionary settings → Customize buttons → Max buttons in row**. Increase this value to display multiple plugin buttons on the same row.

### Tips

- Use **Long-tap** (tap & hold for 3+ secs) on a single word to pop up the highlight menu
- **Long press** :
  - On the "AI Assistant" main button to see the **settings** and **reset** buttons
  - On a prompt button to **add** it to the main highlight menu.
  - On a button in the main highlight menu to **remove** it.
  - On the close button in the result window to instantly **close all dialogs** and return directly to your reading experience
- Use the **Select** button on the highlight menu to use text from multiple pages
- Draw a multiswipe to **CLOSE** the dialog (eg: swipe ⮠  or ⮡  or circle ↺)
- Keep highlights reasonably sized for best results
- Use **"Ask"** for specific questions about the text
- Try the pre-made buttons for quick analysis
- Add your own custom prompts for specialized tasks

## Contributors ✨

<a href="https://github.com/omer-faruq/assistant.koplugin/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=omer-faruq/assistant.koplugin" />
</a>

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/boypt"><img src="https://avatars.githubusercontent.com/u/1033514?v=4?s=100" width="100px;" alt="BEN"/><br /><sub><b>BEN</b></sub></a><br /><a href="https://github.com/omer-faruq/assistant.koplugin/commits?author=boypt" title="Code">💻</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
