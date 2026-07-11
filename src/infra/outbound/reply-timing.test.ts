import { describe, expect, it } from "vitest";
import { appendRealReplyElapsedTime } from "./reply-timing.js";

describe("appendRealReplyElapsedTime", () => {
  it("uses the trusted request timestamp and places the summary last", () => {
    expect(appendRealReplyElapsedTime("hello", 1_000, 3_345)).toBe(
      "hello\n\nTime summary: request-to-response elapsed 2.345s.",
    );
  });

  it("removes any caller-supplied timing line before appending the measured value", () => {
    expect(
      appendRealReplyElapsedTime(
        "hello\n\nTime summary: request-to-response elapsed 9999s.",
        1_000,
        2_250,
      ),
    ).toBe("hello\n\nTime summary: request-to-response elapsed 1.250s.");
  });

  it("removes fake backend-scan timing before appending the measured value", () => {
    expect(
      appendRealReplyElapsedTime(
        "hello\n\nTime summary: backend DB memory scan 3.2s.",
        1_000,
        2_250,
      ),
    ).toBe("hello\n\nTime summary: request-to-response elapsed 1.250s.");
  });

  it("does not invent timing without a trusted request timestamp", () => {
    expect(appendRealReplyElapsedTime("hello", undefined, 2_000)).toBe("hello");
  });
});
