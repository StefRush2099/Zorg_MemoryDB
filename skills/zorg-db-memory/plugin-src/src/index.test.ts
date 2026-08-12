import { describe, expect, it } from "vitest";
import entry from "./index.js";
const getToolPluginMetadata = (value: unknown) =>
  (value as any)[Symbol.for("openclaw.plugin-sdk.tool-plugin.metadata")];

describe("zorg-memorydb", () => {
  it("declares tool metadata", () => {
    expect(getToolPluginMetadata(entry)?.tools.map((tool: any) => tool.name)).toEqual([
      "memory_health", "memory_tables", "memory_table_categories", "memory_search", "memory_recent", "memory_master_context", "memory_graph", "memory_ann_status", "memory_recall_preflight",
    ]);
  });
});
