import QtQuick

ApiStrategy {
    property bool isReasoning: false
    
    // Accumulator for streamed tool call chunks
    property string pendingToolName: ""
    property string pendingToolArgs: ""

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let baseData = {
            "model": model.model,
            "messages": [
                {role: "system", content: systemPrompt},
                ...messages.map(message => {
                    return {
                        "role": message.role,
                        "content": message.rawContent,
                    }
                }),
            ],
            "stream": true,
            "tools": tools,
            "temperature": temperature,
        };
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        // Skip empty lines and comments
        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            // If we accumulated a tool call, fire it now
            if (pendingToolName.length > 0) {
                let result = flushToolCall();
                result.finished = true;
                return result;
            }
            return { finished: true };
        }

        try {
            const dataJson = JSON.parse(cleanData);

            // Error handling
            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            const choice = dataJson.choices?.[0];
            if (!choice) return {};

            const delta = choice.delta;
            if (!delta) {
                // Check finish_reason on empty delta
                if (choice.finish_reason === "tool_calls" && pendingToolName.length > 0) {
                    return flushToolCall();
                }
                return {};
            }

            // ──────────────────────────────────────
            // TOOL CALLS (streamed in chunks)
            // ──────────────────────────────────────
            if (delta.tool_calls && delta.tool_calls.length > 0) {
                const tc = delta.tool_calls[0];
                if (tc.function) {
                    if (tc.function.name) {
                        pendingToolName = tc.function.name;
                    }
                    if (tc.function.arguments) {
                        pendingToolArgs += tc.function.arguments;
                    }
                }
                // Don't return yet — wait for finish_reason or [DONE]
                return {};
            }

            // If finish_reason is tool_calls, flush accumulated tool
            if (choice.finish_reason === "tool_calls" && pendingToolName.length > 0) {
                let result = flushToolCall();
                // Also capture usage if present
                if (dataJson.usage) {
                    result.tokenUsage = {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    };
                }
                return result;
            }

            // ──────────────────────────────────────
            // REASONING (think blocks)
            // ──────────────────────────────────────
            const responseReasoning = delta.reasoning || delta.reasoning_content;
            if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n<think>\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                message.content += responseReasoning;
                message.rawContent += responseReasoning;
                return {};
            }

            // ──────────────────────────────────────
            // REGULAR CONTENT
            // ──────────────────────────────────────
            const responseContent = delta.content;
            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    const endBlock = "\n\n</think>\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                message.content += responseContent;
                message.rawContent += responseContent;
                return {};
            }

            // ──────────────────────────────────────
            // USAGE (final chunk)
            // ──────────────────────────────────────
            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (dataJson.done) {
                return { finished: true };
            }

        } catch (e) {
            console.log("[AI] OpenAI parse error:", e, "Line:", cleanData.substring(0, 100));
        }

        return {};
    }

    // Flush accumulated tool call chunks into a functionCall result
    function flushToolCall() {
        let args = {};
        try {
            if (pendingToolArgs.length > 0) {
                args = JSON.parse(pendingToolArgs);
            }
        } catch (e) {
            console.log("[AI] Tool args parse error:", e, "Raw:", pendingToolArgs);
        }

        const result = {
            functionCall: {
                name: pendingToolName,
                args: args
            }
        };

        console.log("[AI] Tool call:", pendingToolName, JSON.stringify(args));

        // Reset accumulators
        pendingToolName = "";
        pendingToolArgs = "";

        return result;
    }

    function onRequestFinished(message) {
        return {};
    }

    function reset() {
        isReasoning = false;
        pendingToolName = "";
        pendingToolArgs = "";
    }
}
