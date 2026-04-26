// Preferences window — 7 tabs.
// Each tab is a separate component so we can render them as artboards.

function PrefShell({ activeTab = "general", children }) {
  const tabs = [
    { id: "general", label: "geral" },
    { id: "hotkey", label: "atalho" },
    { id: "model", label: "modelo" },
    { id: "llm", label: "llm" },
    { id: "styles", label: "estilos" },
    { id: "vocab", label: "vocab" },
    { id: "history", label: "histórico" },
  ];
  return (
    <div style={{
      width: "100%", height: "100%",
      background: "var(--paper)",
      display: "flex", flexDirection: "column",
      fontFamily: "var(--font-ui)",
    }}>
      {/* titlebar */}
      <div style={{
        height: 44, padding: "0 14px", display: "flex", alignItems: "center", gap: 12,
        borderBottom: "0.5px solid var(--hairline)",
      }}>
        <div style={{ display: "flex", gap: 7 }}>
          <div style={{ width: 12, height: 12, borderRadius: "50%", background: "#ff6058", border: "0.5px solid rgba(0,0,0,0.1)" }} />
          <div style={{ width: 12, height: 12, borderRadius: "50%", background: "#ffbd2e", border: "0.5px solid rgba(0,0,0,0.1)" }} />
          <div style={{ width: 12, height: 12, borderRadius: "50%", background: "#27c93f", border: "0.5px solid rgba(0,0,0,0.1)" }} />
        </div>
        <div style={{ flex: 1, textAlign: "center", fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--ink-2)" }}>
          preferências — tagarela
        </div>
        <Wordmark size={14} glyph={false} />
      </div>

      {/* tabs */}
      <div style={{
        display: "flex", padding: "0 14px", gap: 2,
        borderBottom: "0.5px solid var(--hairline)",
        background: "var(--paper-2)",
      }}>
        {tabs.map(t => (
          <div key={t.id} style={{
            padding: "10px 12px",
            fontFamily: "var(--font-mono)", fontSize: 11,
            color: t.id === activeTab ? "var(--ink)" : "var(--ink-3)",
            borderBottom: t.id === activeTab ? "2px solid var(--carmine)" : "2px solid transparent",
            marginBottom: -1,
            cursor: "default",
          }}>{t.label}</div>
        ))}
      </div>

      {/* content */}
      <div style={{ flex: 1, overflow: "auto", padding: "20px 24px" }}>
        {children}
      </div>
    </div>
  );
}

function Field({ label, hint, children, inline }) {
  return (
    <div style={{ marginBottom: 18, display: inline ? "flex" : "block", alignItems: "center", gap: 12 }}>
      <div style={{ flex: inline ? "0 0 130px" : "auto", marginBottom: inline ? 0 : 6 }}>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--ink)", fontWeight: 500 }}>{label}</div>
        {hint && <div style={{ fontFamily: "var(--font-ui)", fontSize: 10.5, color: "var(--ink-3)", marginTop: 3, lineHeight: 1.45 }}>{hint}</div>}
      </div>
      <div style={{ flex: inline ? 1 : "auto" }}>{children}</div>
    </div>
  );
}

function Toggle({ on }) {
  return (
    <div style={{
      width: 32, height: 18, borderRadius: 9,
      background: on ? "var(--carmine)" : "var(--paper-3)",
      position: "relative", display: "inline-block",
      transition: "background .15s",
    }}>
      <div style={{
        position: "absolute", top: 2, left: on ? 16 : 2,
        width: 14, height: 14, borderRadius: "50%",
        background: "white", boxShadow: "0 1px 2px rgba(0,0,0,0.3)",
        transition: "left .15s",
      }} />
    </div>
  );
}

function Select({ value, opts = [] }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "center", gap: 6,
      padding: "5px 8px 5px 10px",
      background: "var(--paper-2)",
      border: "0.5px solid var(--hairline-strong)",
      borderRadius: "var(--r-2)",
      fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--ink)",
      minWidth: 140,
    }}>
      <span style={{ flex: 1 }}>{value}</span>
      <svg width="9" height="9" viewBox="0 0 9 9"><path d="M2 3l2.5 2.5L7 3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" fill="none"/></svg>
    </div>
  );
}

function TextInput({ value, mono = true, width = "100%" }) {
  return (
    <div style={{
      padding: "6px 8px",
      background: "var(--paper-2)",
      border: "0.5px solid var(--hairline-strong)",
      borderRadius: "var(--r-2)",
      fontFamily: mono ? "var(--font-mono)" : "var(--font-ui)",
      fontSize: 11, color: "var(--ink)",
      width,
    }}>{value}<span className="tg-caret" style={{ color: "var(--carmine)" }}></span></div>
  );
}

// ── Geral ────────────────────────────────────────────────
function PrefGeneral() {
  return (
    <PrefShell activeTab="general">
      <Field label="abrir no login" hint="inicia tagarela automaticamente quando o Mac liga." inline>
        <Toggle on={true} />
      </Field>
      <Field label="indicador flutuante" hint="janela perto do cursor com waveform e timer." inline>
        <Toggle on={true} />
      </Field>
      <Field label="estilo do indicador" inline>
        <Select value="pílula horizontal" />
      </Field>
      <Field label="tema" inline>
        <div style={{ display: "flex", gap: 6, fontFamily: "var(--font-mono)", fontSize: 11 }}>
          {["sistema", "claro", "escuro"].map((t, i) => (
            <div key={t} style={{
              padding: "5px 10px", borderRadius: "var(--r-2)",
              background: i === 0 ? "var(--ink)" : "transparent",
              color: i === 0 ? "var(--paper)" : "var(--ink-3)",
              border: "0.5px solid var(--hairline-strong)",
            }}>{t}</div>
          ))}
        </div>
      </Field>
      <Field label="nível de log" hint="informações no arquivo ~/Library/Logs/tagarela/." inline>
        <Select value=".info" />
      </Field>
      <div style={{
        marginTop: 32, padding: "14px 16px",
        background: "var(--paper-2)", borderRadius: "var(--r-3)",
        border: "0.5px solid var(--hairline)",
      }}>
        <div className="t-eyebrow" style={{ marginBottom: 6 }}>privacidade</div>
        <div style={{ fontFamily: "var(--font-ui)", fontSize: 12, color: "var(--ink-2)", lineHeight: 1.5 }}>
          tagarela não coleta telemetria. áudio nunca é salvo. as únicas requisições externas são as que você configurou explicitamente (openai, ollama).
        </div>
      </div>
    </PrefShell>
  );
}

// ── Atalho ───────────────────────────────────────────────
function PrefHotkey() {
  return (
    <PrefShell activeTab="hotkey">
      <Field label="atalho global"
        hint="aperte uma tecla pra começar. aperte de novo pra parar. ⌥ direita por padrão.">
        <div style={{
          padding: 14, background: "var(--paper-2)",
          border: "0.5px solid var(--hairline-strong)", borderRadius: "var(--r-3)",
          display: "flex", alignItems: "center", justifyContent: "center", gap: 10,
        }}>
          <kbd style={{
            fontFamily: "var(--font-mono)", fontSize: 18,
            padding: "10px 18px", background: "var(--paper)",
            border: "0.5px solid var(--ink)", borderRadius: "var(--r-2)",
            color: "var(--ink)", fontWeight: 500,
            boxShadow: "var(--shadow-sm)",
          }}>right ⌥</kbd>
          <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)" }}>clique pra alterar</div>
        </div>
      </Field>
      <Field label="modo" inline hint="toggle: aperta-fala-aperta. push-to-talk: segura enquanto fala.">
        <div style={{ display: "flex", gap: 6, fontFamily: "var(--font-mono)", fontSize: 11 }}>
          {["toggle", "push-to-talk"].map((t, i) => (
            <div key={t} style={{
              padding: "5px 10px", borderRadius: "var(--r-2)",
              background: i === 0 ? "var(--ink)" : "transparent",
              color: i === 0 ? "var(--paper)" : "var(--ink-3)",
              border: "0.5px solid var(--hairline-strong)",
            }}>{t}</div>
          ))}
        </div>
      </Field>
      <Field label="bipe ao iniciar/parar" inline>
        <Toggle on={false} />
      </Field>
      <Field label="cancelar com Esc" inline>
        <Toggle on={true} />
      </Field>
    </PrefShell>
  );
}

// ── Modelo whisper ───────────────────────────────────────
function PrefModel() {
  return (
    <PrefShell activeTab="model">
      <div style={{ marginBottom: 16 }}>
        <div className="t-eyebrow" style={{ marginBottom: 8 }}>whisper · transcrição local</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <ModelPick name="large-v3" size="2.9 GB" ram="≥ 16 GB" recommended selected />
          <ModelPick name="medium" size="1.4 GB" ram="≥ 8 GB" />
          <ModelPick name="small" size="466 MB" ram="≥ 4 GB" />
          <ModelPick name="base" size="142 MB" ram="≥ 2 GB" />
        </div>
      </div>
      <Field label="idioma" hint="forçado em pt-br. desligue só se for ditar em outros idiomas." inline>
        <Select value="pt — português" />
      </Field>
      <Field label="prompt inicial"
        hint="contexto que vai junto da transcrição. o vocabulário técnico (próxima aba) é incluído automaticamente.">
        <TextInput value="contexto: dev brasileiro, pt-br, termos técnicos em inglês ok" />
      </Field>
      <Field label="duração mínima" hint="capturas mais curtas que isso são descartadas em silêncio." inline>
        <Select value="0.5 s" />
      </Field>
      <Field label="duração máxima" hint="acima disso aparece um aviso de que vai demorar." inline>
        <Select value="5 min" />
      </Field>
    </PrefShell>
  );
}

// ── LLM ──────────────────────────────────────────────────
function BackendCard({ name, status, model, selected }) {
  const dot = status === "online" ? "var(--moss)" : status === "offline" ? "var(--carmine)" : "var(--ink-4)";
  return (
    <div style={{
      flex: 1,
      padding: "14px 14px 12px",
      background: selected ? "var(--paper-2)" : "transparent",
      border: `0.5px solid ${selected ? "var(--ink)" : "var(--hairline-strong)"}`,
      borderRadius: "var(--r-3)",
      display: "flex", flexDirection: "column", gap: 8,
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <div style={{
          width: 12, height: 12, borderRadius: "50%",
          border: "1.2px solid var(--ink)",
          display: "flex", alignItems: "center", justifyContent: "center",
        }}>
          {selected && <div style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--ink)" }} />}
        </div>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 12, fontWeight: 500, color: "var(--ink)" }}>{name}</div>
        <div style={{ flex: 1 }} />
        <div style={{ width: 6, height: 6, borderRadius: "50%", background: dot }} />
      </div>
      <div style={{ fontFamily: "var(--font-mono)", fontSize: 9, color: "var(--ink-3)", letterSpacing: "0.05em" }}>
        {model}
      </div>
    </div>
  );
}

function PrefLLM() {
  return (
    <PrefShell activeTab="llm">
      <Field label="backend" hint="pós-processamento opcional do texto cru.">
        <div style={{ display: "flex", gap: 8 }}>
          <BackendCard name="ollama" status="online" model="qwen3.5:9b · local" selected />
          <BackendCard name="openai" status="online" model="gpt-5.4-mini · cloud" />
          <BackendCard name="sem llm" status="—" model="texto cru do whisper" />
        </div>
      </Field>

      <div style={{
        margin: "20px 0 16px", padding: "12px 14px",
        background: "var(--paper-2)", borderRadius: "var(--r-3)",
        border: "0.5px solid var(--hairline)",
      }}>
        <div className="t-eyebrow" style={{ marginBottom: 8 }}>config ollama</div>
        <Field label="endpoint" inline>
          <TextInput value="http://localhost:11434" />
        </Field>
        <Field label="modelo" inline>
          <TextInput value="qwen3.5:9b-nvfp4" />
        </Field>
        <div style={{ display: "flex", gap: 8, alignItems: "center", marginTop: 4, fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)" }}>
          <div style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--moss)" }} />
          <span>conectado · 14 modelos disponíveis</span>
          <div style={{ flex: 1 }} />
          <span style={{ color: "var(--ink-2)" }}>testar conexão</span>
        </div>
      </div>

      <div style={{
        padding: "12px 14px",
        background: "var(--paper-2)", borderRadius: "var(--r-3)",
        border: "0.5px solid var(--hairline)",
      }}>
        <div className="t-eyebrow" style={{ marginBottom: 8 }}>config openai</div>
        <Field label="api key" inline>
          <TextInput value="sk-•••••••••••••••••••••••••••• 4c2a" />
        </Field>
        <Field label="modelo" inline>
          <TextInput value="gpt-5.4-mini" />
        </Field>
        <Field label="endpoint" inline>
          <TextInput value="https://api.openai.com/v1" />
        </Field>
      </div>

      <Field label="timeout" inline hint="se exceder, fallback automático pro texto cru." >
        <Select value="30 s" />
      </Field>
    </PrefShell>
  );
}

// ── Estilos ──────────────────────────────────────────────
function StyleRow({ name, builtin, selected, preview }) {
  return (
    <div style={{
      padding: "10px 12px",
      background: selected ? "var(--paper-2)" : "transparent",
      border: `0.5px solid ${selected ? "var(--ink)" : "var(--hairline)"}`,
      borderRadius: "var(--r-2)",
      display: "flex", alignItems: "center", gap: 10,
      marginBottom: 6,
    }}>
      <div style={{
        width: 12, height: 12, borderRadius: "50%",
        border: "1.2px solid var(--ink)",
        display: "flex", alignItems: "center", justifyContent: "center",
      }}>
        {selected && <div style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--ink)" }} />}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--ink)", fontWeight: 500 }}>{name}</span>
          {builtin && <span style={{
            fontFamily: "var(--font-mono)", fontSize: 8, padding: "1px 4px",
            background: "var(--paper-3)", color: "var(--ink-3)", borderRadius: 2,
            letterSpacing: "0.08em", textTransform: "uppercase",
          }}>preset</span>}
        </div>
        <div style={{ fontFamily: "var(--font-ui)", fontSize: 10.5, color: "var(--ink-3)", marginTop: 2, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {preview}
        </div>
      </div>
    </div>
  );
}

function PrefStyles() {
  return (
    <PrefShell activeTab="styles">
      <div style={{ display: "flex", gap: 14, height: "100%" }}>
        <div style={{ flex: "0 0 220px" }}>
          <div className="t-eyebrow" style={{ marginBottom: 8 }}>presets</div>
          <StyleRow name="conversa informal" builtin preview="mantém oralidade, gírias" />
          <StyleRow name="e-mail profissional" builtin selected preview="formal, conciso, sem muletas" />
          <StyleRow name="notas técnicas" builtin preview="preserva código, listas, blocos" />
          <StyleRow name="cru — sem reescrita" builtin preview="texto direto do whisper" />
          <StyleRow name="bullet points" preview="resume em itens curtos" />
          <div style={{
            marginTop: 8, padding: "8px 10px",
            border: "0.5px dashed var(--hairline-strong)", borderRadius: "var(--r-2)",
            fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)",
            textAlign: "center", cursor: "default",
          }}>+ novo estilo</div>
        </div>
        <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 12 }}>
          <Field label="nome">
            <TextInput value="e-mail profissional" />
          </Field>
          <Field label="prompt do sistema" hint="instruções pro LLM. as regras de code-switching são anexadas automaticamente.">
            <div style={{
              padding: "10px 12px",
              background: "var(--paper-2)",
              border: "0.5px solid var(--hairline-strong)",
              borderRadius: "var(--r-2)",
              fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--ink)",
              lineHeight: 1.6, minHeight: 100,
            }}>
              Reescreva o texto em português brasileiro formal mas natural.<br/>
              Remova muletas (tipo, então, né), mantenha intenção.<br/>
              Adicione pontuação. Não invente conteúdo.<br/>
              Não ultrapasse o tamanho original em mais de 10%.
            </div>
          </Field>
          <Field label="preservar oralidade" inline hint="mantém 'tô', 'pra', 'cê', regionalismos.">
            <Toggle on={false} />
          </Field>
        </div>
      </div>
    </PrefShell>
  );
}

// ── Vocabulário ──────────────────────────────────────────
function VocabChip({ word }) {
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", gap: 4,
      padding: "3px 7px",
      background: "var(--paper-2)",
      border: "0.5px solid var(--hairline-strong)",
      borderRadius: "var(--r-pill)",
      fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink)",
    }}>
      {word}
      <span style={{ color: "var(--ink-4)", cursor: "pointer", lineHeight: 1 }}>×</span>
    </span>
  );
}

function PrefVocab() {
  const words = [
    "Postgres", "deploy", "rebase", "PR", "Kubernetes", "mutex", "WhisperKit",
    "SwiftData", "Ollama", "endpoint", "claim", "JWT", "stash", "rollback",
    "hotfix", "TypeScript", "container", "build", "pipeline", "schema",
    "Marina", "tagarela", "clipboard", "context window",
  ];
  return (
    <PrefShell activeTab="vocab">
      <Field label="vocabulário técnico"
        hint="palavras que o whisper costuma errar. injetadas no initialPrompt da transcrição. nomes próprios, termos em inglês, jargão.">
        <div style={{
          padding: 12,
          background: "var(--paper-2)",
          border: "0.5px solid var(--hairline-strong)",
          borderRadius: "var(--r-3)",
          display: "flex", flexWrap: "wrap", gap: 6,
          minHeight: 120,
        }}>
          {words.map(w => <VocabChip key={w} word={w} />)}
          <span style={{
            display: "inline-flex", alignItems: "center",
            padding: "3px 7px",
            fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)",
          }}>
            adicionar<span className="tg-caret" style={{ color: "var(--carmine)" }}>|</span>
          </span>
        </div>
      </Field>
      <div style={{
        padding: "10px 12px",
        background: "var(--paper-2)", borderRadius: "var(--r-2)",
        border: "0.5px solid var(--hairline)",
        display: "flex", alignItems: "center", gap: 10,
        fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-3)",
      }}>
        <span style={{ color: "var(--moss)" }}>●</span>
        <span>{words.length} palavras · ~118 tokens · cabe no prompt</span>
        <div style={{ flex: 1 }} />
        <span>importar de arquivo</span>
      </div>
    </PrefShell>
  );
}

// ── Histórico ────────────────────────────────────────────
function HistRowFull({ time, app, kind, raw, refined }) {
  return (
    <div style={{
      padding: "12px 14px",
      borderBottom: "0.5px solid var(--hairline)",
      display: "grid", gridTemplateColumns: "100px 1fr 1fr", gap: 14,
    }}>
      <div>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-2)" }}>{time}</div>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 9, color: "var(--ink-3)", marginTop: 3 }}>{app}</div>
        <div style={{
          marginTop: 6,
          fontFamily: "var(--font-mono)", fontSize: 9, color: kind === "openai" ? "var(--moss)" : kind === "none" ? "var(--ink-4)" : "var(--amber)",
          letterSpacing: "0.05em",
        }}>{kind}</div>
      </div>
      <div>
        <div className="t-eyebrow" style={{ marginBottom: 4, fontSize: 8 }}>cru</div>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 10.5, color: "var(--ink-3)", lineHeight: 1.5 }}>{raw}</div>
      </div>
      <div>
        <div className="t-eyebrow" style={{ marginBottom: 4, fontSize: 8, color: "var(--carmine)" }}>refinado</div>
        <div style={{ fontFamily: "var(--font-ui)", fontSize: 11, color: "var(--ink)", lineHeight: 1.5 }}>{refined}</div>
      </div>
    </div>
  );
}

function PrefHistory() {
  return (
    <PrefShell activeTab="history">
      <div style={{ display: "flex", gap: 16, marginBottom: 16 }}>
        <Field label="manter no máximo" inline>
          <Select value="200 itens" />
        </Field>
        <Field label="por até" inline>
          <Select value="30 dias" />
        </Field>
      </div>

      <div style={{
        padding: "10px 12px",
        background: "var(--paper-2)", borderRadius: "var(--r-2)",
        display: "flex", alignItems: "center", gap: 12,
        marginBottom: 12,
        fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--ink-2)",
      }}>
        <span>137 transcrições · mais antiga há 12 dias · 0 áudios salvos</span>
        <div style={{ flex: 1 }} />
        <span style={{ color: "var(--carmine)", cursor: "default" }}>limpar tudo</span>
      </div>

      <div style={{
        border: "0.5px solid var(--hairline)",
        borderRadius: "var(--r-3)",
        overflow: "hidden",
        background: "var(--paper)",
      }}>
        <HistRowFull time="14:21" app="vscode" kind="ollama"
          raw="então tipo precisa adicionar um pool de conexões pro postgres ali sabe com timeout de uns 30 segundos e tipo um retry exponencial"
          refined="Precisamos adicionar um pool de conexões para o Postgres com timeout de 30 segundos e retry exponencial." />
        <HistRowFull time="13:58" app="slack" kind="ollama"
          raw="vou pegar um café e já volto pra revisar o PR aí pode mandar bem"
          refined="Vou pegar um café e já volto para revisar o PR — pode mandar bem!" />
        <HistRowFull time="13:42" app="notes" kind="openai"
          raw="reunião com a marina amanhã às dez da manhã sobre o roadmap do q3 preparar slides"
          refined="Reunião com a Marina amanhã às 10h sobre roadmap do Q3 — preparar slides." />
        <HistRowFull time="10:14" app="terminal" kind="none"
          raw="git rebase main e depois git push force with lease origin feature auth"
          refined="git rebase main e depois git push force with lease origin feature auth" />
      </div>
    </PrefShell>
  );
}

Object.assign(window, { PrefShell, PrefGeneral, PrefHotkey, PrefModel, PrefLLM, PrefStyles, PrefVocab, PrefHistory, Field, Toggle, Select, TextInput });
