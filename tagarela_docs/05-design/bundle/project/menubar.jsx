// MenuBarExtra — tagarela's status bar dropdown.
// Shown attached to a fake menu bar at the top of an artboard.

function MenuBar({ state = "idle", recording = false }) {
  return (
    <div style={{
      height: 26,
      background: "rgba(244, 237, 224, 0.92)",
      backdropFilter: "blur(20px)",
      borderBottom: "0.5px solid var(--hairline)",
      display: "flex", alignItems: "center", padding: "0 12px",
      fontFamily: "var(--font-ui)", fontSize: 13, color: "var(--ink)",
      gap: 14,
    }}>
      <span style={{ fontWeight: 600 }}></span>
      <span>VS Code</span>
      <span style={{ opacity: 0.7 }}>File</span>
      <span style={{ opacity: 0.7 }}>Edit</span>
      <span style={{ opacity: 0.7 }}>View</span>
      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", alignItems: "center", gap: 14, opacity: 0.85 }}>
        <Glyph size={14} color="var(--ink)" recording={recording} />
        <span style={{ fontSize: 11 }}>89%</span>
        <span style={{ fontSize: 11, fontVariantNumeric: "tabular-nums" }}>14:23</span>
      </div>
    </div>
  );
}

function StateRow({ state }) {
  const map = {
    idle:       { dot: "var(--moss)",   label: "pronto",          sub: "right ⌥ pra começar" },
    recording:  { dot: "var(--carmine)",label: "gravando",        sub: "00:14 · 16 kHz mono" },
    processing: { dot: "var(--amber)",  label: "transcrevendo",   sub: "whisper large-v3" },
    refining:   { dot: "var(--amber)",  label: "refinando",       sub: "ollama · qwen3.5:9b" },
    error:      { dot: "var(--carmine-deep)", label: "ollama offline", sub: "fallback: texto cru" },
  };
  const m = map[state] || map.idle;
  const pulsing = state === "recording" || state === "processing" || state === "refining";
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 14px" }}>
      <div style={{ width: 8, height: 8, borderRadius: "50%", background: m.dot }}
        className={pulsing ? "tg-pulse" : ""} />
      <div style={{ flex: 1 }}>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 13, color: "var(--ink)" }}>{m.label}</div>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)", marginTop: 2 }}>{m.sub}</div>
      </div>
    </div>
  );
}

function HistRow({ time, app, text, kind = "ollama" }) {
  return (
    <div style={{
      padding: "8px 14px",
      display: "flex", flexDirection: "column", gap: 3,
      borderTop: "0.5px solid var(--hairline)",
      cursor: "default",
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, fontFamily: "var(--font-mono)", fontSize: 9, color: "var(--ink-3)", letterSpacing: "0.05em" }}>
        <span>{time}</span>
        <span>·</span>
        <span style={{ textTransform: "uppercase" }}>{app}</span>
        <span>·</span>
        <span style={{ color: kind === "none" ? "var(--ink-4)" : kind === "openai" ? "var(--moss)" : "var(--amber)" }}>
          {kind}
        </span>
      </div>
      <div style={{
        fontFamily: "var(--font-ui)", fontSize: 12, color: "var(--ink-2)",
        lineHeight: 1.35,
        overflow: "hidden",
        display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical",
      }}>{text}</div>
    </div>
  );
}

function MenuBarExtra({ state = "idle", title = "tagarela" }) {
  return (
    <div style={{
      width: 320,
      background: "var(--paper)",
      borderRadius: 10,
      boxShadow: "var(--shadow-pop)",
      border: "0.5px solid var(--hairline-strong)",
      overflow: "hidden",
      fontFamily: "var(--font-ui)",
    }}>
      {/* header */}
      <div style={{
        padding: "12px 14px 10px",
        display: "flex", alignItems: "baseline", justifyContent: "space-between",
        borderBottom: "0.5px solid var(--hairline)",
      }}>
        <Wordmark size={18} />
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 9, color: "var(--ink-3)", letterSpacing: "0.05em" }}>
          v1.0.0
        </div>
      </div>

      <StateRow state={state} />

      {/* divider with eyebrow */}
      <div style={{
        padding: "8px 14px 4px",
        fontFamily: "var(--font-mono)", fontSize: 9, letterSpacing: "0.14em",
        textTransform: "uppercase", color: "var(--ink-3)",
        borderTop: "0.5px solid var(--hairline)",
      }}>últimas 5</div>

      <HistRow time="14:21" app="vscode"
        text="precisa adicionar um pool de conexões pro postgres com timeout de 30 segundos e retry exponencial"
        kind="ollama" />
      <HistRow time="13:58" app="slack"
        text="vou pegar um café e já volto pra revisar o PR — pode mandar bem"
        kind="ollama" />
      <HistRow time="13:42" app="notes"
        text="reunião com a Marina amanhã às 10h sobre roadmap do Q3 — preparar slides"
        kind="openai" />
      <HistRow time="11:30" app="mail"
        text="oi tudo bem? segue em anexo o relatório que pediu, qualquer coisa me avisa"
        kind="ollama" />
      <HistRow time="10:14" app="terminal"
        text="git rebase main && git push --force-with-lease origin feature/auth"
        kind="none" />

      {/* footer */}
      <div style={{
        borderTop: "0.5px solid var(--hairline)",
        padding: "8px 14px",
        display: "flex", alignItems: "center", gap: 14,
        fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--ink-2)",
      }}>
        <span style={{ cursor: "default" }}>preferências…</span>
        <div style={{ flex: 1 }} />
        <span style={{ color: "var(--ink-3)", cursor: "default" }}>sair</span>
      </div>
    </div>
  );
}

Object.assign(window, { MenuBar, MenuBarExtra });
