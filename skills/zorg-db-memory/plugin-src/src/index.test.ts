import { describe, expect, it } from "vitest";
import entry from "./index.js";
import { getToolPluginMetadata } from "openclaw/plugin-sdk/tool-plugin";

describe("zorg-memorydb", () => {
  it("declares tool metadata", () => {
    expect(getToolPluginMetadata(entry)?.tools.map((tool) => tool.name)).toEqual([
      "memory_health", "memory_tables", "memory_search", "memory_recent", "memory_master_context", "memory_ann_status", "memory_recall_preflight",
    ]);
  });
});
