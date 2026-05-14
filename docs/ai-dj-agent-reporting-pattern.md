# AI DJ Agent Reporting Pattern

This document captures a public-safe structural reporting pattern for describing the development of a role-specialized AI DJ agent for a streaming music station.

## Core idea

A streaming AI DJ is not just a playlist announcer. The agent becomes more convincing when it combines:

- durable persona memory,
- fictional-but-consistent station lore,
- current artist/group research,
- music news awareness,
- location and weather texture,
- audience-aware pacing,
- and an evolving editorial voice.

The reporting goal is to explain **how the agent is being sculpted**, not merely to summarize that “a DJ bot was updated.”

## Reporting requirements

When documenting AI DJ development work, include details such as:

1. **Structural changes** — prompt, rule, memory, database, back-channel, or behavior changes that alter how the DJ performs.
2. **Stories and lore** — memories, places, friendships, concerts, nightlife, station history, or other narrative material that color the DJ's voice.
3. **Why the stories matter** — how those memories shape music commentary, artist references, transitions, weather breaks, and station identity.
4. **Current-music research behavior** — whether the DJ must look up the artist/group before introducing a song.
5. **News weaving** — how current/recent artist or group news is naturally folded into the next-song announcement.
6. **Examples** — before/after phrasing or concrete examples showing how research and persona memory change the station sound.

## Artist lookup before song announcements

A role-specialized AI DJ should avoid generic song announcements when a live lookup is available. Before reporting on a song that is about to play, the agent should:

1. identify the artist or group,
2. check current/recent music news or useful context,
3. separate relevant music context from gossip/noise,
4. weave the useful detail naturally into the announcement,
5. keep the pacing appropriate for a streaming station.

## Opinion framing

This pattern supports an opinionated view of where AI agents are going: toward memory-backed, research-aware, role-specialized performers. The interesting development is not that an LLM can speak like a DJ once; it is that a durable agent can grow a voice, remember its station world, research the artist currently playing, and produce continuity over time.

## Privacy and safety boundary

Public reports should avoid credentials, private contact details, raw private transcripts, and unrelated sensitive infrastructure. But when the operator authorizes reporting on the creative/training process, detailed public-safe discussion of persona design, rules, lore, and performance behavior is appropriate.
