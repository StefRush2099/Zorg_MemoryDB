import {describe,expect,it,vi} from "vitest";
import {registerZorgMemoryHooks} from "./turn-gate.js";

const fakeApi=()=>{const hooks=new Map<string,Function>();return {hooks,api:{
  on:(name:string,fn:Function)=>hooks.set(name,fn),
  logger:{error:vi.fn(),info:vi.fn(),warn:vi.fn(),debug:vi.fn()}
} as any};};

describe("Zorg MemoryDB turn gate",()=>{
  it("writes a receipt and injects authoritative recall",async()=>{
    const a=fakeApi();
    const query=vi.fn(async()=>[]);
    const recall=vi.fn(async()=>Array.from({length:8},(_,i)=>({row_data:{i}})));
    registerZorgMemoryHooks(a.api,{query:query as any,recall});
    const out=await a.hooks.get("agent_turn_prepare")!(
      {prompt:"hello",messages:[],queuedInjections:[]},{runId:"r1",sessionKey:"s1"});
    expect(recall).toHaveBeenCalledWith("hello",20);
    expect(out.prependContext).toContain("ZORG MEMORYDB RECEIPT");
  });

  it("prepares Codex llm_input turns and allows the matching tool call",async()=>{
    const a=fakeApi();
    const query=vi.fn(async()=>[]);
    const recall=vi.fn(async()=>Array.from({length:8},(_,i)=>({row_data:{i}})));
    registerZorgMemoryHooks(a.api,{query:query as any,recall});
    await a.hooks.get("llm_input")!(
      {prompt:"codex",runId:"r-codex"},{runId:"r-codex",sessionKey:"s-codex"});
    const gate=a.hooks.get("before_tool_call")!;
    expect(await gate(
      {toolName:"memory_search",params:{},runId:"r-codex"},
      {runId:"r-codex",sessionKey:"s-codex"})).toBeUndefined();
  });

  it("waits for an in-flight Codex receipt before allowing tools",async()=>{
    const a=fakeApi();
    let release!:()=>void;
    const recall=vi.fn(()=>new Promise<any[]>(resolve=>{
      release=()=>resolve(Array.from({length:8},(_,i)=>({row_data:{i}})));
    }));
    registerZorgMemoryHooks(a.api,{query:vi.fn(async()=>[]) as any,recall});
    const preparing=a.hooks.get("llm_input")!(
      {prompt:"slow",runId:"r-slow"},{runId:"r-slow",sessionKey:"s-slow"});
    const gated=a.hooks.get("before_tool_call")!(
      {toolName:"memory_search",params:{},runId:"r-slow"},
      {runId:"r-slow",sessionKey:"s-slow"});
    await vi.waitFor(()=>expect(recall).toHaveBeenCalledOnce());
    release();
    await preparing;
    expect(await gated).toBeUndefined();
  });

  it("blocks a recovery tool when no receipt state exists",async()=>{
    const a=fakeApi();
    registerZorgMemoryHooks(a.api,{query:vi.fn() as any,recall:vi.fn()});
    const gate=a.hooks.get("before_tool_call")!;
    expect((await gate(
      {toolName:"memory_search",params:{},runId:"missing"},
      {runId:"missing",sessionKey:"missing"})).block).toBe(true);
  });

  it("allows one down alert and blocks ordinary work",async()=>{
    const a=fakeApi();
    const failed=vi.fn(async()=>{throw Object.assign(new Error("connect refused"),{code:"08006"});});
    registerZorgMemoryHooks(a.api,{query:failed as any,recall:vi.fn()});
    const prepare=a.hooks.get("agent_turn_prepare")!;
    const out=await prepare({prompt:"held",messages:[],queuedInjections:[]},{runId:"r1",sessionKey:"s1"});
    expect(out.prependContext).toContain("connection_failed");
    const gate=a.hooks.get("before_tool_call")!;
    expect(await gate({toolName:"message",params:{},runId:"r1"},{runId:"r1"})).toBeUndefined();
    expect((await gate({toolName:"message",params:{},runId:"r1"},{runId:"r1"})).block).toBe(true);
    expect((await gate({toolName:"publish",params:{},runId:"r1"},{runId:"r1"})).block).toBe(true);
  });
});
