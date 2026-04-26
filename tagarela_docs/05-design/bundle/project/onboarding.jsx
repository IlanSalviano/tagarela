// Onboarding — first-run flow.
// 3 permission cards + Whisper model picker + Ollama scan.

function PermCard({ name, status, why, action }) {
  // status: "needed" | "granted" | "denied"
  const dotColor = status === "granted" ? "var(--moss)" : status === "denied" ? "var(--carmine)" : "var(--ink-3)";
  return (
    <div style={{
      padding: "16px 18px",
      border: "0.5px solid var(--hairline-strong)",
      borderRadius: "var(--r-3)",
      background: "var(--paper-2)",
      display: "flex", flexDirection: "column", gap: 10,
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ width: 8, height: 8, borderRadius: "50%", background: dotColor }} />
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--ink)", fontWeight: 500 }}>
          {name}
        </div>
        <div style={{ flex: 1 }} />
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 9, letterSpacing: "0.1em",
          textTransform: "uppercase", color: dotColor,
        }}>
          {status === "granted" ? "concedida" : status === "denied" ? "negada" : "necessária"}
        </div>
      </div>
      <div style={{ fontFamily: "var(--font-ui)", fontSize: 12, lineHeight: 1.45, color: "var(--ink-2)" }}>
        {why}
      </div>
      {status !== "granted" && (
        <button style={{
          alignSelf: "flex-start",
          fontFamily: "var(--font-mono)", fontSize: 11,
          padding: "6px 10px",
          background: "var(--ink)", color: "var(--paper)",
          border: "none", borderRadius: "var(--r-2)", cursor: "pointer",
        }}>{action}</button>
      )}
    </div>
  );
}

function ModelPick({ name, size, ram, recommended, selected }) {
  return (
    <div style={{
      padding: "10px 12px",
      border: `0.5px solid ${selected ? "var(--ink)" : "var(--hairline-strong)"}`,
      background: selected ? "var(--paper-2)" : "transparent",
      borderRadius: "var(--r-2)",
      display: "flex", alignItems: "center", gap: 10,
      fontFamily: "var(--font-mono)", fontSize: 12,
    }}>
      <div style={{
        width: 12, height: 12, borderRadius: "50%",
        border: "1.2px solid var(--ink)",
        display: "flex", alignItems: "center", justifyContent: "center",
      }}>
        {selected && <div style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--ink)" }} />}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ color: "var(--ink)", fontWeight: 500 }}>{name}</div>
        <div style={{ fontSize: 10, color: "var(--ink-3)", marginTop: 2 }}>
          {size} · {ram} RAM
        </div>
      </div>
      {recommended && (
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 9, letterSpacing: "0.1em",
          textTransform: "uppercase", color: "var(--carmine)",
          padding: "2px 6px", border: "0.5px solid var(--carmine)", borderRadius: "var(--r-1)",
        }}>recom.</div>
      )}
    </div>
  );
}

// ── Step 1 — Welcome ──────────────────────────────────────
function OnboardWelcome() {
  return (
    <div style={{ padding: "48px 56px", height: "100%", display: "flex", flexDirection: "column" }}>
      <div style={{ marginBottom: 32 }}>
        <Wordmark size={48} />
      </div>
      <div style={{ fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 32, color: "var(--ink)", lineHeight: 1.2, letterSpacing: "-0.01em", marginBottom: 16, textWrap: "pretty" }}>
        ditado por voz para qualquer coisa que você escreva.
      </div>
      <div style={{ fontFamily: "var(--font-ui)", fontSize: 14, color: "var(--ink-2)", lineHeight: 1.5, maxWidth: 460, textWrap: "pretty" }}>
        aperte <kbd style={{ fontFamily: "var(--font-mono)", padding: "1px 5px", background: "var(--paper-2)", border: "0.5px solid var(--hairline-strong)", borderRadius: 3, fontSize: 11 }}>right ⌥</kbd> em qualquer app, fale, aperte de novo. o texto refinado aparece onde estiver o cursor. funciona offline. fala português.
      </div>

      <div style={{ flex: 1 }} />

      <div style={{ display: "flex", gap: 8, marginTop: 32 }}>
        <div style={{ flex: 1 }} />
        <button style={{
          fontFamily: "var(--font-mono)", fontSize: 12,
          padding: "9px 18px",
          background: "var(--ink)", color: "var(--paper)",
          border: "none", borderRadius: "var(--r-2)", cursor: "pointer",
        }}>continuar →</button>
      </div>

      <div style={{
        marginTop: 16, fontFamily: "var(--font-mono)", fontSize: 9,
        letterSpacing: "0.1em", textTransform: "uppercase", color: "var(--ink-3)",
        display: "flex", gap: 8,
      }}>
        <span>passo 1 / 3</span>
        <span>·</span>
        <span>boas-vindas</span>
      </div>
    </div>
  );
}

// ── Step 2 — Permissions ──────────────────────────────────
function OnboardPerms({ states = ["needed", "needed", "granted"] }) {
  return (
    <div style={{ padding: "40px 48px", height: "100%", display: "flex", flexDirection: "column", gap: 16 }}>
      <div>
        <div className="t-eyebrow" style={{ marginBottom: 6 }}>passo 2 / 3</div>
        <div style={{ fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 26, color: "var(--ink)", lineHeight: 1.15 }}>
          três permissões.
        </div>
        <div style={{ fontFamily: "var(--font-ui)", fontSize: 12, color: "var(--ink-2)", marginTop: 6, lineHeight: 1.5 }}>
          o macOS exige isso pra app capturar áudio e atalhos globais. nada vai pra fora da máquina.
        </div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <PermCard name="microfone" status={states[0]}
          why="captura sua voz pra transcrever. áudio nunca é salvo, só processado em memória."
          action="abrir configurações" />
        <PermCard name="acessibilidade" status={states[1]}
          why="necessário pra registrar o atalho global e simular ⌘V no app de destino."
          action="abrir configurações" />
        <PermCard name="input monitoring" status={states[2]}
          why="pra ouvir a tecla right ⌥ mesmo quando outro app está em foco."
          action="abrir configurações" />
      </div>

      <div style={{ flex: 1 }} />

      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)" }}>
          continuar sem hotkey global
        </div>
        <div style={{ flex: 1 }} />
        <button style={{
          fontFamily: "var(--font-mono)", fontSize: 12, padding: "8px 16px",
          background: "var(--paper-2)", color: "var(--ink-3)",
          border: "0.5px solid var(--hairline-strong)", borderRadius: "var(--r-2)", cursor: "default",
        }}>← voltar</button>
        <button style={{
          fontFamily: "var(--font-mono)", fontSize: 12, padding: "8px 16px",
          background: "var(--ink)", color: "var(--paper)",
          border: "none", borderRadius: "var(--r-2)", cursor: "pointer",
        }}>continuar →</button>
      </div>
    </div>
  );
}

// ── Step 3 — Model + Ollama ───────────────────────────────
function OnboardModel({ ollama = "found" }) {
  // ollama: "found" | "scanning" | "missing"
  return (
    <div style={{ padding: "40px 48px", height: "100%", display: "flex", flexDirection: "column", gap: 18 }}>
      <div>
        <div className="t-eyebrow" style={{ marginBottom: 6 }}>passo 3 / 3</div>
        <div style={{ fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 26, color: "var(--ink)", lineHeight: 1.15 }}>
          modelos.
        </div>
      </div>

      {/* whisper picker */}
      <div>
        <div className="t-eyebrow" style={{ marginBottom: 8 }}>whisper · transcrição</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <ModelPick name="large-v3" size="2.9 GB" ram="≥ 16 GB" recommended selected />
          <ModelPick name="medium" size="1.4 GB" ram="≥ 8 GB" />
          <ModelPick name="small" size="466 MB" ram="≥ 4 GB" />
        </div>
        <div style={{
          marginTop: 8, fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)",
          display: "flex", alignItems: "center", gap: 8,
        }}>
          <div style={{
            flex: 1, height: 4, background: "var(--paper-2)", borderRadius: 2, overflow: "hidden",
          }}>
            <div style={{ width: "62%", height: "100%", background: "var(--carmine)" }} />
          </div>
          <span>baixando 1.8 / 2.9 GB</span>
        </div>
      </div>

      {/* ollama scan */}
      <div>
        <div className="t-eyebrow" style={{ marginBottom: 8 }}>ollama · refino opcional</div>
        <div style={{
          padding: "12px 14px",
          background: "var(--paper-2)",
          border: "0.5px solid var(--hairline-strong)",
          borderRadius: "var(--r-3)",
          display: "flex", alignItems: "center", gap: 12,
        }}>
          <div style={{ width: 8, height: 8, borderRadius: "50%",
            background: ollama === "found" ? "var(--moss)" : ollama === "scanning" ? "var(--amber)" : "var(--ink-4)" }}
            className={ollama === "scanning" ? "tg-pulse" : ""} />
          <div style={{ flex: 1, fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--ink)" }}>
            {ollama === "found" && "ollama detectado em localhost:11434"}
            {ollama === "scanning" && "procurando ollama…"}
            {ollama === "missing" && "ollama não encontrado"}
          </div>
          {ollama === "found" && (
            <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)" }}>
              qwen3.5:9b ✓
            </div>
          )}
          {ollama === "missing" && (
            <button style={{
              fontFamily: "var(--font-mono)", fontSize: 10, padding: "5px 9px",
              background: "transparent", color: "var(--ink)",
              border: "0.5px solid var(--ink)", borderRadius: "var(--r-1)", cursor: "pointer",
            }}>como instalar</button>
          )}
        </div>
        <div style={{ fontFamily: "var(--font-ui)", fontSize: 11, color: "var(--ink-3)", marginTop: 6, lineHeight: 1.5 }}>
          sem ollama você ainda usa tagarela — texto vem cru do whisper, ou você configura openai depois.
        </div>
      </div>

      <div style={{ flex: 1 }} />

      <div style={{ display: "flex", gap: 8 }}>
        <div style={{ flex: 1 }} />
        <button style={{
          fontFamily: "var(--font-mono)", fontSize: 12, padding: "9px 18px",
          background: "var(--ink)", color: "var(--paper)",
          border: "none", borderRadius: "var(--r-2)", cursor: "pointer",
        }}>começar →</button>
      </div>
    </div>
  );
}

Object.assign(window, { OnboardWelcome, OnboardPerms, OnboardModel });
