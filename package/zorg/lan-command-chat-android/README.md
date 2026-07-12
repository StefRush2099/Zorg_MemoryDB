# LAN Command Chat Android

Android client for LAN Command Chat. The client loads the same responsive
`/chat` surface used by the LAN web application so mobile typography, panels,
gauges, scrolling, light/dark behavior, chat, and the Memory 3D/Gauges toggle
remain one implementation. The device follows its phone system theme through
the `theme=system` route parameter.

The app stores multiple configurable chat profiles on-device. Each profile has
an internet URL plus an optional internal host and port. Requests try the
internal route first and fall back to the internet origin when it is not
reachable. The Android client consumes the LAN Chat contract at
`/api/chat/send`, `/api/chat/history`, and `/api/chat/status`; it does not use
the OpenClaw TUI.

Build defaults are centralized in `gradle.properties`:

```bash
./gradlew assembleDebug \
  -PLAN_CHAT_DEFAULT_NAME="Zorg LAN Command Chat" \
  -PLAN_CHAT_DEFAULT_URL="https://chat.example.net/chat"
```

The app supports HTTP for explicitly configured LAN deployments and HTTPS for
internet deployments. Production internet endpoints should always use HTTPS.

The agent can provide the profile values through the normal LAN Chat
configuration/status flow; no credentials or private scheduler configuration
is embedded in the APK.
