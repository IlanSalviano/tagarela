// Toasts and error states for tagarela.

function Toast({ tone = "warn", icon, title, body, hint }) {
  const tones = {
    warn:    { bg: "var(--paper)", accent: "var(--amber)" },
    error:   { bg: "var(--paper)", accent: "var(--carmine)" },
    info:    { bg: "var(--paper)", accent: "var(--ink)" },
    success: { bg: "var(--paper)", accent: "var(--moss)" },
  };
  const t = tones[tone];
  return (
    <div style={{
      width: 320, padding: "12px 14px",
      background: t.bg,
      borderRadius: "var(--r-3)",
      boxShadow: "var(--shadow-pop)",
      border: "0.5px solid var(--hairline-strong)",
      borderLeft: `3px solid ${t.accent}`,
      display: "flex", gap: 10, alignItems: "flex-start",
      fontFamily: "var(--font-ui)",
    }}>
      <div style={{
        width: 18, height: 18, borderRadius: "50%",
        background: t.accent, color: "var(--paper)",
        display: "flex", alignItems: "center", justifyContent: "center",
        flexShrink: 0, fontSize: 11, fontWeight: 600, fontFamily: "var(--font-mono)",
      }}>{icon}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 11, fontWeight: 500, color: "var(--ink)" }}>{title}</div>
        <div style={{ fontSize: 11.5, color: "var(--ink-2)", marginTop: 3, lineHeight: 1.45 }}>{body}</div>
        {hint && (
          <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)", marginTop: 6 }}>
            {hint}
          </div>
        )}
      </div>
    </div>
  );
}

function ToastStack() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10, padding: 24 }}>
      <Toast tone="warn" icon="!" title="ollama offline"
        body="usando texto cru do whisper. próxima captura tenta de novo."
        hint="GET /api/tags · timeout 2s" />
      <Toast tone="error" icon="✕" title="api key inválida"
        body="o openai recusou a key configurada. abrindo preferências…"
        hint="HTTP 401 · invalid_api_key" />
      <Toast tone="warn" icon="↑" title="texto longo"
        body="excedeu a janela do modelo. truncado pra refinar — trecho meio omitido."
        hint="20.4k tokens > 16k context" />
      <Toast tone="info" icon="⌘" title="não foi possível colar"
        body="o app de destino não aceitou ⌘V. texto está na área de transferência — cole manual."
        hint="frontmost: figma" />
      <Toast tone="success" icon="✓" title="modelo baixado"
        body="whisper large-v3 pronto pra uso. próxima transcrição usa ele."
        hint="2.9 GB · stored in ~/Library/Application Support/" />
    </div>
  );
}

// Permission denied amber state — shown attached to status bar
function PermDeniedDropdown() {
  return (
    <div style={{
      width: 300,
      background: "var(--paper)",
      borderRadius: 10,
      boxShadow: "var(--shadow-pop)",
      border: "0.5px solid var(--hairline-strong)",
      overflow: "hidden",
      fontFamily: "var(--font-ui)",
    }}>
      <div style={{
        padding: "12px 14px",
        background: "linear-gradient(180deg, rgba(201,122,20,0.12), transparent)",
        borderBottom: "0.5px solid var(--hairline)",
        display: "flex", alignItems: "center", gap: 10,
      }}>
        <div style={{ width: 8, height: 8, borderRadius: "50%", background: "var(--amber)" }} />
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--ink)", fontWeight: 500 }}>
            permissões faltando
          </div>
          <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)", marginTop: 2 }}>
            hotkey global desativada
          </div>
        </div>
      </div>

      <div style={{ padding: "10px 14px" }}>
        {[
          { name: "microfone", ok: true },
          { name: "acessibilidade", ok: false },
          { name: "input monitoring", ok: false },
        ].map(p => (
          <div key={p.name} style={{
            display: "flex", alignItems: "center", gap: 8,
            padding: "6px 0",
            fontFamily: "var(--font-mono)", fontSize: 11,
            color: p.ok ? "var(--ink-2)" : "var(--ink)",
          }}>
            <div style={{
              width: 6, height: 6, borderRadius: "50%",
              background: p.ok ? "var(--moss)" : "var(--carmine)",
            }} />
            <span style={{ flex: 1 }}>{p.name}</span>
            {!p.ok && (
              <span style={{ fontSize: 10, color: "var(--carmine)", letterSpacing: "0.05em" }}>
                conceder →
              </span>
            )}
          </div>
        ))}
      </div>

      <div style={{
        padding: "10px 14px",
        borderTop: "0.5px solid var(--hairline)",
        background: "var(--paper-2)",
      }}>
        <div style={{ fontFamily: "var(--font-ui)", fontSize: 11, color: "var(--ink-2)", lineHeight: 1.45 }}>
          enquanto isso você pode iniciar gravação clicando aqui no menu.
        </div>
        <div style={{
          marginTop: 8, padding: "6px 10px",
          background: "var(--ink)", color: "var(--paper)",
          borderRadius: "var(--r-2)",
          fontFamily: "var(--font-mono)", fontSize: 11, textAlign: "center",
        }}>iniciar gravação</div>
      </div>
    </div>
  );
}

Object.assign(window, { Toast, ToastStack, PermDeniedDropdown });
