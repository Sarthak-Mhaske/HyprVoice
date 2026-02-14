pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions as CF
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services.ai

/**
 * Basic service to handle LLM chats. Supports Google's and OpenAI's API formats.
 * Supports Gemini and OpenAI models.
 * Limitations:
 * - For now functions only work with Gemini API format
 */
Singleton {
    id: root

    property Component aiMessageComponent: AiMessageData {}
    property Component aiModelComponent: AiModel {}
    property Component geminiApiStrategy: GeminiApiStrategy {}
    property Component openaiApiStrategy: OpenAiApiStrategy {}
    property Component mistralApiStrategy: MistralApiStrategy {}
    readonly property string interfaceRole: "interface"
    readonly property string apiKeyEnvVarName: "API_KEY"

    signal responseFinished()

    property string systemPrompt: {
        let prompt = Config.options?.ai?.systemPrompt ?? "";
        for (let key in root.promptSubstitutions) {
            prompt = prompt.split(key).join(root.promptSubstitutions[key]);
        }
        return prompt;
    }
    property var messageIDs: []
    property var messageByID: ({})
    readonly property var apiKeys: KeyringStorage.keyringData?.apiKeys ?? {}
    readonly property var apiKeysLoaded: KeyringStorage.loaded
    readonly property bool currentModelHasApiKey: {
        const model = models[currentModelId];
        if (!model || !model.requires_key) return true;
        if (!apiKeysLoaded) return false;
        const key = apiKeys[model.key_id];
        return (key?.length > 0);
    }
    property var postResponseHook
    property real temperature: Persistent.states?.ai?.temperature ?? 0.5
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        property int total: -1
    }

    function idForMessage(message) {
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 8);
    }

    function safeModelName(modelName) {
        return modelName.replace(/:/g, "_").replace(/ /g, "-").replace(/\//g, "-")
    }

    property list<var> defaultPrompts: []
    property list<var> userPrompts: []
    property list<var> promptFiles: [...defaultPrompts, ...userPrompts]
    property list<var> savedChats: []

    property var promptSubstitutions: {
        "{DISTRO}": SystemInfo.distroName,
        "{DATETIME}": `${DateTime.time}, ${DateTime.collapsedCalendarFormat}`,
        "{WINDOWCLASS}": ToplevelManager.activeToplevel?.appId ?? "Unknown",
        "{DE}": `${SystemInfo.desktopEnvironment} (${SystemInfo.windowingSystem})` 
    }

    property string currentTool: "functions"
    property var tools: {
        "gemini": {
            "functions": [{"functionDeclarations": [
                {
                    "name": "switch_to_search_mode",
                    "description": "Search the web",
                },
                {
                    "name": "get_shell_config",
                    "description": "Get the desktop shell config file contents",
                },
                {
                    "name": "set_shell_config",
                    "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "key": {
                                "type": "string",
                                "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                            },
                            "value": {
                                "type": "string",
                                "description": "The value to set, e.g. `true`"
                            }
                        },
                        "required": ["key", "value"]
                    }
                },
                {
                    "name": "run_shell_command",
                    "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "The bash command to run",
                            },
                        },
                        "required": ["command"]
                    }
                },
            ]}],
            "search": [{
                "google_search": {}
            }],
            "none": []
        },
        "openai": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {}
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "google_search",
                        "description": "Open a Google search in the browser (safe)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": {
                                    "type": "string",
                                    "description": "Search query",
                                },
                            },
                            "required": ["query"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "screenshot_workspace",
                        "description": "Switch to a specific workspace and take a screenshot",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "number": {
                                    "type": "string",
                                    "description": "Workspace number",
                                },
                            },
                            "required": ["number"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "screenshot_area",
                        "description": "Take an area screenshot using grimblast",
                        "parameters": { "type": "object", "properties": {}, "required": [] }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "screenshot_screen",
                        "description": "Take a full screen screenshot using grimblast",
                        "parameters": { "type": "object", "properties": {}, "required": [] }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "screenshot_window",
                        "description": "Take an active window screenshot using grimblast",
                        "parameters": { "type": "object", "properties": {}, "required": [] }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_audio_output",
                        "description": "Switch audio output device (safe presets)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "target": {
                                    "type": "string",
                                    "enum": ["speakers", "hdmi", "bluetooth"],
                                    "description": "Which output to switch to",
                                },
                            },
                            "required": ["target"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "remind_in",
                        "description": "Send a notification after N minutes (safe reminder)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "minutes": {
                                    "type": "string",
                                    "minimum": 1,
                                    "maximum": 1440,
                                    "description": "How many minutes from now (1 to 1440)",
                                },
                                "title": {
                                    "type": "string",
                                    "description": "Reminder title",
                                },
                                "body": {
                                    "type": "string",
                                    "description": "Reminder body",
                                },
                                "urgency": {
                                    "type": "string",
                                    "enum": ["low", "normal", "critical"],
                                    "description": "Urgency level",
                                },
                            },
                            "required": ["minutes", "title"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "notify",
                        "description": "Send a desktop notification",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "title": {
                                    "type": "string",
                                    "description": "Notification title",
                                },
                                "body": {
                                    "type": "string",
                                    "description": "Notification body",
                                },
                                "urgency": {
                                    "type": "string",
                                    "enum": ["low", "normal", "critical"],
                                    "description": "Urgency level",
                                },
                                "timeout_ms": {
                                    "type": "string",
                                    "description": "Timeout in milliseconds",
                                },
                            },
                            "required": ["title", "body"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "open_url",
                        "description": "Open a URL in the default browser (http/https only)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": {
                                    "type": "string",
                                    "description": "URL to open (must start with http:// or https://)",
                                },
                            },
                            "required": ["url"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "open_url_in_brave",
                        "description": "Open a URL in Brave (http/https only)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": {
                                    "type": "string",
                                    "description": "URL to open in Brave (must start with http:// or https://)",
                                },
                            },
                            "required": ["url"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "media_control",
                        "description": "Control media playback (play, pause, play-pause, next, previous, stop)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": {
                                    "type": "string",
                                    "enum": ["play", "pause", "play-pause", "next", "previous", "stop"],
                                    "description": "The action to perform",
                                },
                            },
                            "required": ["action"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_volume",
                        "description": "Set system volume (0-100)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "level": {
                                    "type": "string",
                                    "minimum": 0,
                                    "maximum": 100,
                                    "description": "Volume level from 0 to 100",
                                },
                            },
                            "required": ["level"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_brightness",
                        "description": "Set brightness (0-100)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "level": {
                                    "type": "string",
                                    "minimum": 0,
                                    "maximum": 100,
                                    "description": "Brightness level from 0 to 100",
                                },
                            },
                            "required": ["level"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "switch_model",
                        "description": "Switch to a different AI model. Use when: 1) User asks to switch, 2) Task needs more power, 3) Need faster response. Shortcuts: 70b/best, maverick/thinking, scout/balanced, 120b/big, 8b/fast, qwen, kimi, allam",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "model": {
                                    "type": "string",
                                    "description": "Model: 70b, maverick, scout, 120b, 8b, qwen, kimi, allam"
                                }
                            },
                            "required": ["model"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "open_app",
                        "description": "Open a known safe app (allowlist)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "app": {
                                    "type": "string",
                                    "enum": ["brave", "brave_autoplay", "firefox", "kitty", "dolphin", "thunar", "pavucontrol", "systemsettings", "spotify"],
                                    "description": "App to open",
                                },
                            },
                            "required": ["app"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "play_song",
                        "description": "Search and play a song/video (opens a YouTube search)",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": {
                                    "type": "string",
                                    "description": "Song name, artist, or search query",
                                },
                            },
                            "required": ["query"]
                        }
                    },
                },
            ],
            "search": [],
            "none": [],
        },
        "mistral": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {}
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
            ],
            "search": [],
            "none": [],
        }
    }
    property list<var> availableTools: Object.keys(root.tools[models[currentModelId]?.api_format] ?? {})
    property var toolDescriptions: {
        "functions": Translation.tr("Commands, edit configs, search.\nTakes an extra turn to switch to search mode if that's needed"),
        "search": Translation.tr("Gives the model search capabilities (immediately)"),
        "none": Translation.tr("Disable tools")
    }

    property var models: Config.options.policies.ai === 2 ? {} : {
        // Tier 1: Best Overall (default choice)
        "groq-llama-3-3-70b": aiModelComponent.createObject(this, {
            "name": "Groq: Llama 3.3 70B ⭐",
            "icon": "spark-symbolic",
            "description": Translation.tr("Groq | Best quality | 1K req/day, 100K tokens/day"),
            "homepage": "https://console.groq.com",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "llama-3.3-70b-versatile",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: Free tier available\n\n**Instructions**: Sign up at Groq, go to API Keys, create new key"),
            "api_format": "openai",
        }),
        
        // Tier 2: Heavy Thinking (128 experts)
        "groq-llama-4-maverick": aiModelComponent.createObject(this, {
            "name": "Groq: Llama 4 Maverick 17B 🧠",
            "icon": "spark-symbolic",
            "description": Translation.tr("Groq | 128 experts, powerful reasoning | 1K req/day, 500K tokens/day"),
            "homepage": "https://console.groq.com",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "meta-llama/llama-4-maverick-17b-128e-instruct",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: Free tier available\n\n**Instructions**: Sign up at Groq, go to API Keys, create new key"),
            "api_format": "openai",
        }),
        
        // Tier 3: Balanced Speed + Quality
        "groq-llama-4-scout": aiModelComponent.createObject(this, {
            "name": "Groq: Llama 4 Scout 17B ⚡",
            "icon": "spark-symbolic",
            "description": Translation.tr("Groq | Balanced | 1K req/day, 500K tokens/day, 30K TPM"),
            "homepage": "https://console.groq.com",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "meta-llama/llama-4-scout-17b-16e-instruct",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: Free tier available\n\n**Instructions**: Sign up at Groq, go to API Keys, create new key"),
            "api_format": "openai",
        }),
        
        // Tier 4: Nuclear Option (biggest)
        "groq-gpt-oss-120b": aiModelComponent.createObject(this, {
            "name": "Groq: GPT-OSS 120B 💪",
            "icon": "spark-symbolic",
            "description": Translation.tr("Groq | Largest model | 1K req/day, 200K tokens/day"),
            "homepage": "https://console.groq.com",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "openai/gpt-oss-120b",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: Free tier available\n\n**Instructions**: Sign up at Groq, go to API Keys, create new key"),
            "api_format": "openai",
        }),
        
        // Tier 5: Ultra Fast (for quick tasks)
        "groq-llama-3-1-8b": aiModelComponent.createObject(this, {
            "name": "Groq: Llama 3.1 8B 🚀",
            "icon": "spark-symbolic",
            "description": Translation.tr("Groq | Ultra fast | 14.4K req/day, 500K tokens/day"),
            "homepage": "https://console.groq.com",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "llama-3.1-8b-instant",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: Free tier available\n\n**Instructions**: Sign up at Groq, go to API Keys, create new key"),
            "api_format": "openai",
        }),
        
        // Tier 6: Alternatives
        "groq-qwen3-32b": aiModelComponent.createObject(this, {
            "name": "Groq: Qwen 3 32B 🔄",
            "icon": "spark-symbolic",
            "description": Translation.tr("Groq | Alternative | 1K req/day, 500K tokens/day"),
            "homepage": "https://console.groq.com",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "qwen/qwen3-32b",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: Free tier available\n\n**Instructions**: Sign up at Groq, go to API Keys, create new key"),
            "api_format": "openai",
        }),
        
        "groq-kimi-k2": aiModelComponent.createObject(this, {
            "name": "Groq: Kimi K2 🔄",
            "icon": "spark-symbolic",
            "description": Translation.tr("Groq | Moonshot AI | 60 RPM backup | 1K req/day, 300K tokens/day"),
            "homepage": "https://console.groq.com",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "moonshotai/kimi-k2-instruct",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: Free tier available\n\n**Instructions**: Sign up at Groq, go to API Keys, create new key"),
            "api_format": "openai",
        }),
        
        // Tier 7: Specialized (Arabic + lightweight)
        /*
        "groq-allam-7b": aiModelComponent.createObject(this, {
            "name": "Groq: Allam 2 7B 🌍",
            "icon": "spark-symbolic",
            "description": Translation.tr("Groq | Lightweight + Arabic | 7K req/day, 500K tokens/day"),
            "homepage": "https://console.groq.com",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "allam-2-7b",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: Free tier available\n\n**Instructions**: Sign up at Groq, go to API Keys, create new key"),
            "api_format": "openai",
        }),
        */
    }
    property var modelList: Object.keys(root.models)
    property var currentModelId: {
        const saved = (Persistent.states?.ai?.model ?? "").toString();
        if (saved.length > 0 && root.models[saved]) return saved;

        const list = Object.keys(root.models ?? {});
        return (list.length > 0) ? list[0] : "";
    }

    property var apiStrategies: {
        "openai": openaiApiStrategy.createObject(this),
        "gemini": geminiApiStrategy.createObject(this),
        "mistral": mistralApiStrategy.createObject(this),
    }
    property ApiStrategy currentApiStrategy: apiStrategies[models[currentModelId]?.api_format || "openai"]

    Connections {
        target: Config
        function onReadyChanged() {
            if (!Config.ready) return;
            (Config?.options.ai?.extraModels ?? []).forEach(model => {
                const safeModelName = root.safeModelName(model["model"]);
                root.addModel(safeModelName, model)
            });
        }
    }

    property string requestScriptFilePath: "/tmp/quickshell/ai/request.sh"
    property string pendingFilePath: ""

    Component.onCompleted: {
        setModel(currentModelId, false, false);
    }

    function guessModelLogo(model) {
        if (model.includes("llama")) return "ollama-symbolic";
        if (model.includes("gemma")) return "google-gemini-symbolic";
        if (model.includes("deepseek")) return "deepseek-symbolic";
        if (/^phi\d*:/i.test(model)) return "microsoft-symbolic";
        return "ollama-symbolic";
    }

    function guessModelName(model) {
        const replaced = model.replace(/-/g, ' ').replace(/:/g, ' ');
        let words = replaced.split(' ');
        words[words.length - 1] = words[words.length - 1].replace(/(\d+)b$/, (_, num) => `${num}B`)
        words = words.map((word) => {
            return (word.charAt(0).toUpperCase() + word.slice(1))
        });
        if (words[words.length - 1] === "Latest") words.pop();
        else words[words.length - 1] = `(${words[words.length - 1]})`;
        const result = words.join(' ');
        return result;
    }

    function addModel(modelName, data) {
        root.models[modelName] = aiModelComponent.createObject(this, data);
    }

    Process {
        id: getOllamaModels
        running: true
        command: ["bash", "-c", `${Directories.scriptPath}/ai/show-installed-ollama-models.sh`.replace(/file:\/\//, "")]
        stdout: SplitParser {
            onRead: data => {
                try {
                    if (data.length === 0) return;
                    const dataJson = JSON.parse(data);
                    root.modelList = [...root.modelList, ...dataJson];
                    dataJson.forEach(model => {
                        const safeModelName = root.safeModelName(model);
                        root.addModel(safeModelName, {
                            "name": guessModelName(model),
                            "icon": guessModelLogo(model),
                            "description": Translation.tr("Local Ollama model | %1").arg(model),
                            "homepage": `https://ollama.com/library/${model}`,
                            "endpoint": "http://localhost:11434/v1/chat/completions",
                            "model": model,
                            "requires_key": false,
                        })
                    });

                    root.modelList = Object.keys(root.models);

                } catch (e) {
                    console.log("Could not fetch Ollama models:", e);
                }
            }
        }
    }

    Process {
        id: getDefaultPrompts
        running: true
        command: ["ls", "-1", Directories.defaultAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.defaultPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.defaultAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getUserPrompts
        running: true
        command: ["ls", "-1", Directories.userAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.userPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.userAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getSavedChats
        running: true
        command: ["ls", "-1", Directories.aiChats]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.savedChats = text.split("\n")
                    .filter(fileName => fileName.endsWith(".json"))
                    .map(fileName => `${Directories.aiChats}/${fileName}`)
            }
        }
    }

    FileView {
        id: promptLoader
        watchChanges: false;
        onLoadedChanged: {
            if (!promptLoader.loaded) return;
            Config.options.ai.systemPrompt = promptLoader.text();
            root.addMessage(Translation.tr("Loaded the following system prompt\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
        }
    }

    function printPrompt() {
        root.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
    }

    function loadPrompt(filePath) {
        promptLoader.path = ""
        promptLoader.path = filePath;
        promptLoader.reload();
    }

    function addMessage(message, role) {
        if (message.length === 0) return;
        const aiMessage = aiMessageComponent.createObject(root, {
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
        });
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function removeMessage(index) {
        if (index < 0 || index >= messageIDs.length) return;
        const id = root.messageIDs[index];
        root.messageIDs.splice(index, 1);
        root.messageIDs = [...root.messageIDs];
        delete root.messageByID[id];
    }

    function addApiKeyAdvice(model) {
        root.addMessage(
            Translation.tr('To set an API key, pass it with the %4 command\n\nTo view the key, pass "get" with the command<br/>\n\n### For %1:\n\n**Link**: %2\n\n%3')
                .arg(model.name).arg(model.key_get_link).arg(model.key_get_description ?? Translation.tr("<i>No further instruction provided</i>")).arg("/key"), 
            Ai.interfaceRole
        );
    }

    function getModel() {
        return models[currentModelId];
    }

    function setModel(modelId, feedback = true, setPersistentState = true) {
        if (!modelId) modelId = ""
        modelId = modelId.toLowerCase()
        if (modelList.indexOf(modelId) !== -1) {
            const model = models[modelId]
            if (Config.options.policies.ai === 2 && !model.endpoint.includes("localhost")) {
                root.addMessage(
                    Translation.tr("Online models disallowed\n\nControlled by `policies.ai` config option"),
                    root.interfaceRole
                );
                return;
            }
            if (setPersistentState) Persistent.states.ai.model = modelId;
            if (feedback) root.addMessage(Translation.tr("Model set to %1").arg(model.name), root.interfaceRole);
            if (model.requires_key) {
                if (root.apiKeysLoaded && (!root.apiKeys[model.key_id] || root.apiKeys[model.key_id].length === 0)) {
                    root.addApiKeyAdvice(model)
                }
            }
        } else {
            if (feedback) root.addMessage(Translation.tr("Invalid model. Supported: \n```\n") + modelList.join("\n```\n```\n"), Ai.interfaceRole) + "\n```"
        }
    }

    function setTool(tool) {
        if (!root.tools[models[currentModelId]?.api_format] || !(tool in root.tools[models[currentModelId]?.api_format])) {
            root.addMessage(Translation.tr("Invalid tool. Supported tools:\n- %1").arg(root.availableTools.join("\n- ")), root.interfaceRole);
            return false;
        }
        Config.options.ai.tool = tool;
        return true;
    }
    
    function getTemperature() {
        return root.temperature;
    }

    function setTemperature(value) {
        if (value == NaN || value < 0 || value > 2) {
            root.addMessage(Translation.tr("Temperature must be between 0 and 2"), Ai.interfaceRole);
            return;
        }
        Persistent.states.ai.temperature = value;
        root.temperature = value;
        root.addMessage(Translation.tr("Temperature set to %1").arg(value), Ai.interfaceRole);
    }

    function setApiKey(key) {
        const model = models[currentModelId];
        if (!model.requires_key) {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
            return;
        }
        if (!key || key.length === 0) {
            const model = models[currentModelId];
            root.addApiKeyAdvice(model)
            return;
        }
        KeyringStorage.setNestedField(["apiKeys", model.key_id], key.trim());
        root.addMessage(Translation.tr("API key set for %1").arg(model.name), Ai.interfaceRole);
    }

    function printApiKey() {
        const model = models[currentModelId];
        if (model.requires_key) {
            const key = root.apiKeys[model.key_id];
            if (key) {
                root.addMessage(Translation.tr("API key:\n\n```txt\n%1\n```").arg(key), Ai.interfaceRole);
            } else {
                root.addMessage(Translation.tr("No API key set for %1").arg(model.name), Ai.interfaceRole);
            }
        } else {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
        }
    }

    function printTemperature() {
        root.addMessage(Translation.tr("Temperature: %1").arg(root.temperature), Ai.interfaceRole);
    }

    function clearMessages() {
        root.messageIDs = [];
        root.messageByID = ({});
        root.tokenCount.input = -1;
        root.tokenCount.output = -1;
        root.tokenCount.total = -1;
    }

    FileView {
        id: requesterScriptFile
    }

    Process {
        id: requester
        property list<string> baseCommand: ["bash"]
        property AiMessageData message
        property ApiStrategy currentStrategy
        
        // Per-request voice state tracking
        property bool isVoice: false
        property int voiceSeq: 0
        property string voiceLang: "english"

        function markDone() {
            requester.message.done = true;
            if (root.postResponseHook) {
                root.postResponseHook();
                root.postResponseHook = null;
            }
            root.saveChat("lastSession")
            root.responseFinished()
        }

        function makeRequest() {
            // Capture voice state for THIS request at the start
            requester.isVoice = (root.activeVoiceSeq === root.voiceSeq && root.voiceSeq > 0);
            requester.voiceSeq = root.voiceSeq;
            requester.voiceLang = root.voiceInputLang;
            
            const model = models[currentModelId];

            if (model?.requires_key && !KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
            
            requester.currentStrategy = root.currentApiStrategy;
            requester.currentStrategy.reset();

            if (model.requires_key) {
                const keysStr = root.apiKeys ? (root.apiKeys[model.key_id] ?? "") : "";
                const keys = keysStr.split(",").map(k => k.trim()).filter(k => k !== "");
                const selectedKey = keys.length > 0 ? keys[Math.floor(Math.random() * keys.length)] : "";
                requester.environment[`${root.apiKeyEnvVarName}`] = selectedKey;
            }

            const endpoint = root.currentApiStrategy.buildEndpoint(model);
            const messageArray = root.messageIDs.map(id => root.messageByID[id]);
            const MAX_CONTEXT_MSG = 10;
            let filteredMessageArray = messageArray.filter(message => message.role !== Ai.interfaceRole);
            if (filteredMessageArray.length > MAX_CONTEXT_MSG) {
                filteredMessageArray = filteredMessageArray.slice(filteredMessageArray.length - MAX_CONTEXT_MSG);
            }
            const data = root.currentApiStrategy.buildRequestData(model, filteredMessageArray, root.systemPrompt, root.temperature, root.tools[model.api_format][root.currentTool], root.pendingFilePath);
            // Force the model to use tools
            data.tool_choice = "auto";

            let requestHeaders = {
                "Content-Type": "application/json",
            }
            
            requester.message = root.aiMessageComponent.createObject(root, {
                "role": "assistant",
                "model": currentModelId,
                "content": "",
                "rawContent": "",
                "thinking": true,
                "done": false,
            });
            const id = idForMessage(requester.message);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = requester.message;

            let headerString = Object.entries(requestHeaders)
                .filter(([k, v]) => v && v.length > 0)
                .map(([k, v]) => `-H '${k}: ${v}'`)
                .join(' ');

            const authHeader = requester.currentStrategy.buildAuthorizationHeader(root.apiKeyEnvVarName);
            
            const scriptShebang = "#!/usr/bin/env bash\n";

            let scriptFileSetupContent = ""
            if (root.pendingFilePath && root.pendingFilePath.length > 0) {
                requester.message.localFilePath = root.pendingFilePath;
                scriptFileSetupContent = requester.currentStrategy.buildScriptFileSetup(root.pendingFilePath);
                root.pendingFilePath = ""
            }

            let scriptRequestContent = ""
            scriptRequestContent += `curl --no-buffer "${endpoint}"`
                + ` ${headerString}`
                + (authHeader ? ` ${authHeader}` : "")
                + ` --data '${CF.StringUtils.shellSingleQuoteEscape(JSON.stringify(data))}'`
                + "\n"
            
            const scriptContent = requester.currentStrategy.finalizeScriptContent(scriptShebang + scriptFileSetupContent + scriptRequestContent)
            const shellScriptPath = CF.FileUtils.trimFileProtocol(root.requestScriptFilePath)
            requesterScriptFile.path = Qt.resolvedUrl(shellScriptPath)
            requesterScriptFile.setText(scriptContent)
            requester.command = baseCommand.concat([shellScriptPath]);
            requester.running = true
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.length === 0) return;
                if (requester.message.thinking) requester.message.thinking = false;

                console.log("[AI] Raw data chunk:", data);

                try {
                    const result = requester.currentStrategy.parseResponseLine(data, requester.message);

                    console.log("[AI] Parse result:", JSON.stringify(result));  // ADD THIS
                    console.log("[AI] Function call:", result?.functionCall);

                    if (result.functionCall) {
                        console.log("[AI] Executing function:", result.functionCall.name); 
                        requester.message.functionCall = result.functionCall;
                        root.handleFunctionCall(result.functionCall.name, result.functionCall.args, requester.message);
                    }
                    if (result.tokenUsage) {
                        root.tokenCount.input = result.tokenUsage.input;
                        root.tokenCount.output = result.tokenUsage.output;
                        root.tokenCount.total = result.tokenUsage.total;
                    }
                    if (result.finished) {
                        requester.markDone();
                    }
                    
                } catch (e) {
                    console.log("[AI] Could not parse response: ", e);
                    requester.message.rawContent += data;
                    requester.message.content += data;
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            const result = requester.currentStrategy.onRequestFinished(requester.message);
            
            if (result.finished) {
                requester.markDone();
            } else if (!requester.message.done) {
                requester.markDone();
            }
            
            if (requester.message.content.includes("API key not valid")) {
                root.addApiKeyAdvice(models[requester.message.model]);
            }
            
            // AUTO-FALLBACK ON RATE LIMIT - CHECK THIS FIRST!
            console.log("[AI] Checking for rate limit in:", requester.message.content.substring(0, 200));
            
            if (requester.message.content.includes("rate_limit") || 
                requester.message.content.includes("Rate limit") ||
                requester.message.content.includes("429") ||
                requester.message.content.includes("token") && requester.message.content.includes("limit") ||
                requester.message.content.includes("quota")) {
                
                console.log("[AI] Rate limit hit, attempting fallback...");
                
                const fallbackChain = [
                    "groq-llama-3-3-70b",
                    "groq-llama-4-scout", 
                    "groq-llama-4-maverick",
                    "groq-qwen3-32b",
                    "groq-kimi-k2",
                    "groq-llama-3-1-8b",
                    "groq-gpt-oss-120b"
                ];
                
                const currentIndex = fallbackChain.indexOf(root.currentModelId);
                const nextIndex = (currentIndex + 1) % fallbackChain.length;
                
                if (nextIndex !== currentIndex) {
                    const nextModel = fallbackChain[nextIndex];
                    root.currentModelId = nextModel;
                    root.addMessage(`⚠️ Rate limit hit. Switching to: ${root.models[nextModel].name}`, root.interfaceRole);
                    
                    // Notify via TTS if voice mode
                    if (requester.isVoice && requester.voiceSeq === root.activeVoiceSeq) {
                        Quickshell.execDetached(["notify-send", "🔄 Switching model", root.models[nextModel].name]);
                    }
                    
                    // Retry with new model
                    requester.makeRequest();
                    return;
                }
            }

            // VOICE MODE: Notify and speak the response
            // Only speak if this request is still the active voice request
            if (requester.isVoice && requester.voiceSeq === root.activeVoiceSeq && requester.message) {
                let response = requester.message.content || "";
                console.log("[VOICE] Response content:", response.substring(0, 100));
                
                // Skip TTS for errors
                if (response.includes("Failed to call") || 
                    response.includes("Error:") ||
                    response.includes("❌") ||
                    response.includes("event: error") ||
                    response.length === 0) {
                    console.log("[VOICE] Skipped - error response");
                    return;
                }
                
                if (response.length > 0) {
                    console.log("[VOICE] Triggering TTS for voiceSeq:", requester.voiceSeq);
                    
                    console.log("[VOICE] Triggering TTS for voiceSeq:", requester.voiceSeq);
                    console.log("[VOICE] Raw response:", response.substring(0, 100));

                    // Clean response for display/TTS
                    let displayResponse = response;

                    // Remove properly closed thinking tags
                    displayResponse = displayResponse.replace(/<think>[\s\S]*?<\/think>/gi, "");
                    displayResponse = displayResponse.replace(/<thinking>[\s\S]*?<\/thinking>/gi, "");

                    // Handle unclosed thinking tags - more aggressive approach
                    // Check for unclosed tags (case-insensitive)
                    const lower = displayResponse.toLowerCase();
                    const thinkIndex = lower.indexOf("<think");
                    const thinkCloseIndex = lower.indexOf("</think");

                    if (thinkIndex !== -1 && (thinkCloseIndex === -1 || thinkCloseIndex < thinkIndex)) {
                        // Found unclosed <think> tag - remove everything from that point
                        displayResponse = displayResponse.substring(0, thinkIndex);
                        console.log("[VOICE] Removed unclosed think tag at index:", thinkIndex);
                    }

                    // Same for <thinking>
                    const thinkingIndex = lower.indexOf("<thinking");
                    const thinkingCloseIndex = lower.indexOf("</thinking");

                    if (thinkingIndex !== -1 && (thinkingCloseIndex === -1 || thinkingCloseIndex < thinkingIndex)) {
                        displayResponse = displayResponse.substring(0, thinkingIndex);
                        console.log("[VOICE] Removed unclosed thinking tag at index:", thinkingIndex);
                    }

                    // Remove error messages
                    displayResponse = displayResponse.replace(/event: error.*/gi, "");
                    displayResponse = displayResponse.replace(/\*\*Error\*\*:.*/gi, "");
                    displayResponse = displayResponse.replace(/Failed to call.*/gi, "");
                    displayResponse = displayResponse.trim();

                    console.log("[VOICE] Cleaned response:", displayResponse.substring(0, 50));
                    
                    if (displayResponse.length === 0) {
                        console.log("[VOICE] Skipped - only thinking/error content");
                        return;
                    }
                    
                    // Clean for TTS
                    let ttsResponse = displayResponse.replace(/\*\*/g, "");
                    ttsResponse = ttsResponse.replace(/##/g, "");
                    ttsResponse = ttsResponse.replace(/`/g, "");
                    ttsResponse = ttsResponse.replace(/\n/g, " ");
                    ttsResponse = ttsResponse.replace(/"/g, "");
                    ttsResponse = ttsResponse.replace(/'/g, "");
                    ttsResponse = ttsResponse.replace(/\s+/g, " ").trim();
                    
                    // Show notification
                    let notifyText = displayResponse.substring(0, 150);
                    if (displayResponse.length > 150) notifyText += "...";
                    Quickshell.execDetached(["notify-send", "🤖 HyprVoice:", notifyText]);
                    
                    console.log("[VOICE] Speaking:", ttsResponse.substring(0, 50));
                    
                    // Send to TTS script (handles language detection & translation)
                    Quickshell.execDetached(["bash", "-c",
                        `VOICE_LANG="${requester.voiceLang}" $HOME/.config/hypr/scripts/text-to-speech.sh <<< "${ttsResponse}"`
                    ]);
                }
            } else if (requester.isVoice) {
                console.log("[VOICE] Skipped - superseded by newer voice request (seq:", requester.voiceSeq, "vs active:", root.activeVoiceSeq, ")");
            }
        }
    }

    function switchModel(modelId: string): bool {
        let normalized = modelId.toLowerCase().trim();
        
        normalized = normalized.replace(/lama/g, "llama");
        normalized = normalized.replace(/\s+/g, "");
        normalized = normalized.replace(/-/g, "");
        
        const aliases = {
            "70b": "groq-llama-3-3-70b",
            "llama70b": "groq-llama-3-3-70b",
            "llama33": "groq-llama-3-3-70b",
            "llama3.3": "groq-llama-3-3-70b",
            "best": "groq-llama-3-3-70b",
            
            "maverick": "groq-llama-4-maverick",
            "llama4maverick": "groq-llama-4-maverick",
            "thinking": "groq-llama-4-maverick",
            
            "scout": "groq-llama-4-scout",
            "llama4scout": "groq-llama-4-scout",
            "balanced": "groq-llama-4-scout",
            
            "120b": "groq-gpt-oss-120b",
            "gpt": "groq-gpt-oss-120b",
            "big": "groq-gpt-oss-120b",
            
            "8b": "groq-llama-3-1-8b",
            "llama8b": "groq-llama-3-1-8b",
            "llama31": "groq-llama-3-1-8b",
            "llama3.1": "groq-llama-3-1-8b",
            "flash": "groq-llama-3-1-8b",
            "fast": "groq-llama-3-1-8b",
            
            "qwen": "groq-qwen3-32b",
            "qwen3": "groq-qwen3-32b",
            "qwen32b": "groq-qwen3-32b",
            
            "kimi": "groq-kimi-k2",
            "kimik2": "groq-kimi-k2",
            
            
        };
        
        if (aliases[normalized]) normalized = aliases[normalized];
        
        if (!root.models[normalized]) {
            const available = Object.keys(root.models);
            for (let key of available) {
                if (key.includes(normalized) || normalized.includes(key.replace("groq-", ""))) {
                    normalized = key;
                    break;
                }
            }
        }
        
        if (!root.models[normalized]) {
            root.addMessage(`❌ Model not found: ${modelId}. Try: 70b, 8b, maverick, scout`, root.interfaceRole);
            return false;
        }
        
        root.currentModelId = normalized;
        root.addMessage(`✅ Switched to: ${root.models[normalized].name}`, root.interfaceRole);
        return true;
    }

    function sendUserMessage(message) {
        if (message.length === 0) return;
        root.addMessage(message, "user");
        requester.makeRequest();
    }

    function sendTranslatedRequest(translatedText: string) {
        const model = models[currentModelId];
        const messageArray = root.messageIDs.map(id => root.messageByID[id]);
        
        const lastId = root.messageIDs[root.messageIDs.length - 1];
        const lastMsg = root.messageByID[lastId];
        const originalContent = lastMsg.content;
        lastMsg.content = translatedText;
        
        requester.makeRequest();
        
        lastMsg.content = originalContent;
    }

    function attachFile(filePath: string) {
        root.pendingFilePath = CF.FileUtils.trimFileProtocol(filePath);
    }

    function regenerate(messageIndex) {
        if (messageIndex < 0 || messageIndex >= messageIDs.length) return;
        const id = root.messageIDs[messageIndex];
        const message = root.messageByID[id];
        if (message.role !== "assistant") return;
        for (let i = root.messageIDs.length - 1; i >= messageIndex; i--) {
            root.removeMessage(i);
        }
        requester.makeRequest();
    }

    function createFunctionOutputMessage(name, output, includeOutputInChat = true) {
        return aiMessageComponent.createObject(root, {
            "role": "user",
            "content": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "rawContent": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "functionName": name,
            "functionResponse": output,
            "thinking": false,
            "done": true,
        });
    }

    function addFunctionOutputMessage(name, output) {
        const aiMessage = createFunctionOutputMessage(name, output);
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function rejectCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false;
        addFunctionOutputMessage(message.functionName, Translation.tr("Command rejected by user"))
    }

    function approveCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false;

        const responseMessage = createFunctionOutputMessage(message.functionName, "", false);
        const id = idForMessage(responseMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = responseMessage;

        commandExecutionProc.message = responseMessage;
        commandExecutionProc.baseMessageContent = responseMessage.content;
        commandExecutionProc.shellCommand = message.functionCall.args.command;
        commandExecutionProc.running = true;
    }

    Process {
        id: commandExecutionProc
        property string shellCommand: ""
        property AiMessageData message
        property string baseMessageContent: ""
        command: ["bash", "-c", shellCommand]
        stdout: SplitParser {
            onRead: (output) => {
                commandExecutionProc.message.functionResponse += output + "\n\n";
                const updatedContent = commandExecutionProc.baseMessageContent + `\n\n<think>\n<tt>${commandExecutionProc.message.functionResponse}</tt>\n</think>`;
                commandExecutionProc.message.rawContent = updatedContent;
                commandExecutionProc.message.content = updatedContent;
            }
        }
        onExited: (exitCode, exitStatus) => {
            commandExecutionProc.message.functionResponse += `[[ Command exited with code ${exitCode} (${exitStatus}) ]]\n`;
        }
    }

    function handleFunctionCall(name, args: var, message: AiMessageData) {
        if (name === "switch_to_search_mode") {
            const modelId = root.currentModelId;
            root.currentTool = "search"
            root.postResponseHook = () => { root.currentTool = "functions" }
            addFunctionOutputMessage(name, Translation.tr("Switched to search mode. Continue with the user's request."))
            requester.makeRequest();
        } else if (name === "get_shell_config") {
            const configJson = CF.ObjectUtils.toPlainObject(Config.options)
            addFunctionOutputMessage(name, JSON.stringify(configJson));
            requester.makeRequest();
        } else if (name === "set_shell_config") {
            if (!args.key || !args.value) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `key` and `value`."));
                return;
            }
            const key = args.key;
            const value = args.value;
            Config.setNestedValue(key, value);
        } else if (name === "run_shell_command") {
            if (!args.command || args.command.length === 0) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `command`."));
                return;
            }
            const contentToAppend = `\n\n**Command execution request**\n\n\`\`\`command\n${args.command}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            message.functionName = name;
            message.functionPending = true;
        } 
        // =========================
        // SAFE AUTO-EXECUTE TOOLS
        // =========================
        else if (name === "media_control") {
            const action = (args.action ?? "").toLowerCase();
            const allowed = ["play", "pause", "play-pause", "next", "previous", "stop"];
            if (allowed.indexOf(action) === -1) {
                root.addMessage(`Invalid media action: ${action}`, root.interfaceRole);
                return;
            }
            
            if (action === "previous") {
                Quickshell.execDetached(["bash", "-c", "playerctl previous && sleep 0.1 && playerctl previous"]);
                root.addMessage(`✅ Media: previous (double tap)`, root.interfaceRole);
            } else {
                Quickshell.execDetached(["playerctl", action]);
                root.addMessage(`✅ Media: ${action}`, root.interfaceRole);
            }
            return;
        }
        else if (name === "screenshot_area") {
            const file = "$HOME/Pictures/Screenshots/shot-area-" + Date.now() + ".png";
            const cmd = `mkdir -p $HOME/Pictures/Screenshots && sleep 1 && grimblast save area "${file}" && notify-send "Screenshot" "Saved area to ${file}"`;
            Quickshell.execDetached(["bash", "-c", cmd]);
            root.addMessage("✅ Selecting area in 1s (Close sidebar)...", root.interfaceRole);
            return;
        }
        else if (name === "screenshot_screen") {
            const file = "$HOME/Pictures/Screenshots/shot-screen-" + Date.now() + ".png";
            const cmd = `mkdir -p $HOME/Pictures/Screenshots && sleep 1 && grimblast save screen "${file}" && notify-send "Screenshot" "Saved fullscreen to ${file}"`;
            Quickshell.execDetached(["bash", "-c", cmd]);
            root.addMessage("✅ Taking fullscreen shot in 1s...", root.interfaceRole);
            return;
        }
        else if (name === "screenshot_window") {
            const file = "$HOME/Pictures/Screenshots/shot-window-" + Date.now() + ".png";
            const cmd = `mkdir -p $HOME/Pictures/Screenshots && sleep 1 && grimblast save active "${file}" && notify-send "Screenshot" "Saved window to ${file}"`;
            Quickshell.execDetached(["bash", "-c", cmd]);
            root.addMessage("✅ Capturing active window in 1s...", root.interfaceRole);
            return;
        }
        else if (name === "screenshot_monitor") {
            const mon = (args.monitor ?? "active").toLowerCase();
            const file = "$HOME/Pictures/Screenshots/shot-" + mon + "-" + Date.now() + ".png";
            let grimArg = "output";
            
            if (mon === "all") grimArg = "screen";
            else if (mon === "laptop") grimArg = "output eDP-1";
            else if (mon === "external") grimArg = "output HDMI-A-1";
            
            const cmd = `mkdir -p $HOME/Pictures/Screenshots && sleep 1 && grimblast save ${grimArg} "${file}" && notify-send "Screenshot" "Saved ${mon} to ${file}"`;
            
            Quickshell.execDetached(["bash", "-c", cmd]);
            root.addMessage(`✅ Capturing ${mon} monitor in 1s...`, root.interfaceRole);
            return;
        }
        else if (name === "set_volume") {
            let level = Number(args.level);
            if (isNaN(level)) level = 50;
            level = Math.max(0, Math.min(100, level));
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", `${level}%`]);
            root.addMessage(`✅ Volume set to ${level}%`, root.interfaceRole);
            return;
        }
        else if (name === "set_brightness") {
            let level = Number(args.level);
            if (isNaN(level)) level = 50;
            level = Math.max(0, Math.min(100, level));
            Quickshell.execDetached(["brightnessctl", "set", `${level}%`]);
            root.addMessage(`✅ Brightness set to ${level}%`, root.interfaceRole);
            return;
        }
        else if (name === "switch_model") {
            const modelId = (args.model ?? "").toString().trim();
            console.log("[AI] Self-switching to:", modelId);
            
            if (root.switchModel(modelId)) {
                if (requester.isVoice && requester.voiceSeq === root.activeVoiceSeq) {
                    Quickshell.execDetached(["notify-send", "🔄 Model:", root.models[root.currentModelId].name]);
                }
            }
            return;
        }
        else if (name === "open_app" || name === "launch_app") {
            let app = "";
            if (name === "open_app") app = (args.app ?? "").toString().trim().toLowerCase();
            else app = (args.command ?? "").toString().trim().toLowerCase();

            if (!app || app.includes(" ") || app.includes(";") || app.includes("&") || app.includes("|") || app.includes(">") || app.includes("<")) {
                root.addMessage("❌ Refusing: only allowlisted apps can be opened.", root.interfaceRole);
                return;
            }

            const apps = {
                "brave": ["brave", "--new-tab"],
                "brave_autoplay": ["brave", "--autoplay-policy=no-user-gesture-required", "--new-tab"],
                "firefox": ["firefox"],
                "kitty": ["kitty"],
                "dolphin": ["dolphin"],
                "thunar": ["thunar"],
                "pavucontrol": ["pavucontrol"],
                "systemsettings": ["systemsettings"],
                "spotify": ["spotify"],
            };

            const cmd = apps[app];
            if (!cmd) {
                root.addMessage(`❌ Not allowed: ${app}`, root.interfaceRole);
                return;
            }

            Quickshell.execDetached(cmd);
            root.addMessage(`✅ Opened: ${app}`, root.interfaceRole);
            return;
        }

        else if (name === "play_song") {
            const query = (args.query ?? "").toString().trim().slice(0, 120);
            if (!query) {
                root.addMessage("No query provided to play_song", root.interfaceRole);
                return;
            }

            Quickshell.execDetached([
                "bash", "-c",
                `~/.config/hypr/scripts/play-music.sh '${query.replace(/'/g, "'\\''")}'`
            ]);

            root.addMessage(`✅ Playing: ${query}`, root.interfaceRole);
            return;
        }

        else if (name === "open_url") {
            const url = (args.url ?? "").toString().trim();
            if (!url) {
                root.addMessage("No url provided to open_url", root.interfaceRole);
                return;
            }
            if (!(url.startsWith("https://") || url.startsWith("http://"))) {
                root.addMessage("❌ Refusing: only http(s) URLs are allowed.", root.interfaceRole);
                return;
            }
            Quickshell.execDetached(["xdg-open", url]);
            root.addMessage(`✅ Opened URL: ${url}`, root.interfaceRole);
            return;
        }
        else if (name === "open_url_in_brave") {
            const url = (args.url ?? "").toString().trim();
            if (!url) {
                root.addMessage("No url provided to open_url_in_brave", root.interfaceRole);
                return;
            }
            if (!(url.startsWith("https://") || url.startsWith("http://"))) {
                root.addMessage("❌ Refusing: only http(s) URLs are allowed.", root.interfaceRole);
                return;
            }
            Quickshell.execDetached(["brave", "--new-tab", url]);
            root.addMessage(`✅ Opened in Brave: ${url}`, root.interfaceRole);
            return;
        }
        else if (name === "notify") {
            const title = (args.title ?? "").toString();
            const body = (args.body ?? "").toString();
            const urgency = ((args.urgency ?? "normal").toString()).toLowerCase();
            const timeout = Number(args.timeout_ms);

            const u = (urgency === "low" || urgency === "critical") ? urgency : "normal";
            const t = isNaN(timeout) ? 3000 : Math.max(500, Math.min(60000, timeout));

            Quickshell.execDetached(["notify-send", "-u", u, "-t", `${t}`, title, body]);
            root.addMessage(`✅ Notified: ${title}`, root.interfaceRole);
            return;
        }
        else if (name === "remind_in") {
            let minutes = Number(args.minutes);
            if (isNaN(minutes)) minutes = 5;
            minutes = Math.max(1, Math.min(1440, Math.floor(minutes)));

            const title = (args.title ?? "Reminder").toString().slice(0, 120);
            const body = (args.body ?? "").toString().slice(0, 300);
            const urgency = ((args.urgency ?? "normal").toString()).toLowerCase();
            const u = (urgency === "low" || urgency === "critical") ? urgency : "normal";

            const unit = `qs-remind-${Date.now()}`;

            Quickshell.execDetached([
                "systemd-run",
                "--user",
                "--unit", unit,
                "--on-active", `${minutes}m`,
                "/usr/bin/notify-send",
                "-u", u,
                "-t", "8000",
                title,
                body
            ]);

            root.addMessage(`✅ Reminder set in ${minutes} min: ${title}`, root.interfaceRole);
            return;
        }
        else if (name === "google_search") {
            const query = (args.query ?? "").toString().trim();
            if (!query) {
                root.addMessage("No query provided to google_search", root.interfaceRole);
                return;
            }
            const enc = encodeURIComponent(query);
            Quickshell.execDetached(["xdg-open", `https://www.google.com/search?q=${enc}`]);
            root.addMessage(`✅ Google search opened: ${query}`, root.interfaceRole);
            return;
        }
        else if (name === "set_audio_output") {
            const target = ((args.target ?? "speakers").toString()).toLowerCase();
            if (!(target === "speakers" || target === "hdmi" || target === "bluetooth")) {
                root.addMessage(`Invalid audio output target: ${target}`, root.interfaceRole);
                return;
            }

            Quickshell.execDetached(["/usr/local/bin/qs-set-audio-output", target]);
            root.addMessage(`✅ Switching audio output: ${target}`, root.interfaceRole);
            return;
        }           
        else root.addMessage(Translation.tr("Unknown function call: %1").arg(name), "assistant");
    }

    function chatToJson() {
        return root.messageIDs.map(id => {
            const message = root.messageByID[id]
            return ({
                "role": message.role,
                "rawContent": message.rawContent,
                "fileMimeType": message.fileMimeType,
                "fileUri": message.fileUri,
                "localFilePath": message.localFilePath,
                "model": message.model,
                "thinking": false,
                "done": true,
                "annotations": message.annotations,
                "annotationSources": message.annotationSources,
                "functionName": message.functionName,
                "functionCall": message.functionCall,
                "functionResponse": message.functionResponse,
                "visibleToUser": message.visibleToUser,
            })
        })
    }

    FileView {
        id: chatSaveFile
        property string chatName: ""
        path: chatName.length > 0 ? `${Directories.aiChats}/${chatName}.json` : ""
        blockLoading: true
    }

    function saveChat(chatName) {
        chatSaveFile.chatName = chatName.trim()
        const saveContent = JSON.stringify(root.chatToJson())
        chatSaveFile.setText(saveContent)
        getSavedChats.running = true;
    }

    function loadChat(chatName) {
        try {
            chatSaveFile.chatName = chatName.trim()
            chatSaveFile.reload()
            const saveContent = chatSaveFile.text()
            const saveData = JSON.parse(saveContent)
            root.clearMessages()
            root.messageIDs = saveData.map((_, i) => {
                return i
            })
            for (let i = 0; i < saveData.length; i++) {
                const message = saveData[i];
                root.messageByID[i] = root.aiMessageComponent.createObject(root, {
                    "role": message.role,
                    "rawContent": message.rawContent,
                    "content": message.rawContent,
                    "fileMimeType": message.fileMimeType,
                    "fileUri": message.fileUri,
                    "localFilePath": message.localFilePath,
                    "model": message.model,
                    "thinking": message.thinking,
                    "done": message.done,
                    "annotations": message.annotations,
                    "annotationSources": message.annotationSources,
                    "functionName": message.functionName,
                    "functionCall": message.functionCall,
                    "functionResponse": message.functionResponse,
                    "visibleToUser": message.visibleToUser,
                });
            }
        } catch (e) {
            console.log("[AI] Could not load chat: ", e);
        } finally {
            getSavedChats.running = true;
        }
    }

    // Voice Assistant IPC Bridge
    IpcHandler {
        target: "ai"

        function voiceMessage(transcription: string): void {
            root.voiceSeq++;
            root.activeVoiceSeq = root.voiceSeq;
            root.voiceInputLang = "english";
            root.sendUserMessage(transcription);
        }
        
        function voiceMessageTranslated(original: string, translated: string, lang: string): void {
            root.voiceSeq++;
            root.activeVoiceSeq = root.voiceSeq;

            const langNorm = (lang && lang.length > 0)
                ? lang.toString().trim().toLowerCase()
                : "english";

            root.voiceInputLang = langNorm;
        
            // Add original to sidebar (user sees their language)
            const aiMessage = aiMessageComponent.createObject(root, {
                "role": "user",
                "content": original,
                "rawContent": original,
                "thinking": false,
                "done": true,
            });
            const id = idForMessage(aiMessage);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = aiMessage;
            
            // Now override last message content for API call only
            aiMessage.content = "#voice " + translated;
            requester.makeRequest();
            
            // Restore for display after request starts
            Qt.callLater(() => { aiMessage.content = original; });
        }

        function getLastResponse(): string {
            if (root.messageIDs.length === 0) return "";
            const lastId = root.messageIDs[root.messageIDs.length - 1];
            const lastMsg = root.messageByID[lastId];
            return lastMsg?.content ?? "";
        }
        
        function setModel(modelId: string): void {
            root.switchModel(modelId);
        }
    }

    // Voice mode tracking - per-request sequence to prevent race conditions
    property int voiceSeq: 0           // Increments on each new voice request
    property int activeVoiceSeq: 0     // The sequence number we're waiting for
    property string voiceInputLang: "english"
}
