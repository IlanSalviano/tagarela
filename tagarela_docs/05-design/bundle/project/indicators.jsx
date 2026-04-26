// 4 floating indicator variations for tagarela.
// All accept { state: "recording"|"processing"|"error", level: 0..1, seconds, onCancel }
// Drawn at "real" macOS scale (~88-96px tall). Use --paper, --ink, --carmine.

const ind_pad = { fontFamily: "var(--font-mono)", color: "var(--ink)" };

function fmtTime(s) {
  const m = Math.floor(s / 60);
  const r = Math.floor(s % 60);
  return `${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
}

// shared waveform bars — uses level + per-bar phase
function WaveBars({ count = 14, level = 0.5, color = "var(--carmine)", height = 28, width = 96, gap = 3 }) {
  const t = Math.floor(Date.now() / 80);
  const bars = [];
  for (let i = 0; i < count; i++) {
    const seed = (Math.sin(i * 1.7 + t * 0.4) + 1) / 2;
    const seed2 = (Math.sin(i * 0.9 + t * 0.7 + 2) + 1) / 2;
    const env = Math.sin((i / count) * Math.PI); // taper edges
    const h = Math.max(2, (0.18 + level * 0.7 * (seed * 0.6 + seed2 * 0.4)) * height * (0.5 + env * 0.6));
    bars.push(
      <div key={i} style={{
        width: (width - gap * (count - 1)) / count, height: h,
        background: color, borderRadius: 0, opacity: 0.85 + 0.15 * env,
      }} />
    );
  }
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap, height, width }}>
      {bars}
    </div>
  );
}

function CancelX({ onCancel, color = "var(--ink-3)" }) {
  return (
    <button onClick={onCancel} title="Cancelar (Esc)"
      style={{
        width: 22, height: 22, border: "none", background: "transparent",
        color, cursor: "pointer", padding: 0, borderRadius: "50%",
        display: "flex", alignItems: "center", justifyContent: "center",
      }}>
      <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
        <path d="M2 2l6 6M8 2l-6 6" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
      </svg>
    </button>
  );
}

// Status text by state
function statusLabel(state) {
  if (state === "recording") return "ouvindo";
  if (state === "processing") return "transcrevendo…";
  if (state === "refining") return "refinando…";
  if (state === "error") return "erro";
  return "";
}
function statusColor(state) {
  if (state === "recording") return "var(--carmine)";
  if (state === "processing" || state === "refining") return "var(--amber)";
  if (state === "error") return "var(--carmine-deep)";
  return "var(--ink)";
}

// ── A — pílula horizontal compacta ───────────────────────
function IndicatorPill({ state = "recording", level = 0.6, seconds = 12, onCancel }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "center", gap: 12,
      padding: "10px 14px 10px 14px",
      background: "var(--paper)", color: "var(--ink)",
      borderRadius: "var(--r-pill)",
      boxShadow: "var(--shadow-pop)",
      border: "0.5px solid var(--hairline-strong)",
      fontFamily: "var(--font-mono)",
    }}>
      <div style={{
        width: 8, height: 8, borderRadius: "50%",
        background: statusColor(state),
      }} className={state === "recording" ? "tg-pulse" : ""} />
      <WaveBars level={level} height={22} width={84} count={16}
        color={state === "recording" ? "var(--ink)" : "var(--ink-3)"} />
      <div style={{ fontSize: 11, fontVariantNumeric: "tabular-nums", color: "var(--ink-2)", minWidth: 38 }}>
        {fmtTime(seconds)}
      </div>
      <div style={{ width: 1, height: 16, background: "var(--hairline)" }} />
      <CancelX onCancel={onCancel} />
    </div>
  );
}

// ── B — bolha circular minimalista (waveform radial) ─────
function IndicatorOrb({ state = "recording", level = 0.6, seconds = 12, onCancel }) {
  const size = 92;
  const cx = size / 2, cy = size / 2;
  const baseR = 24;
  const bars = 28;
  const t = Math.floor(Date.now() / 80);
  const color = statusColor(state);
  const lines = [];
  for (let i = 0; i < bars; i++) {
    const a = (i / bars) * Math.PI * 2;
    const seed = (Math.sin(i * 1.3 + t * 0.4) + 1) / 2;
    const len = 4 + level * 14 * (0.4 + seed * 0.8);
    const x1 = cx + Math.cos(a) * baseR;
    const y1 = cy + Math.sin(a) * baseR;
    const x2 = cx + Math.cos(a) * (baseR + len);
    const y2 = cy + Math.sin(a) * (baseR + len);
    lines.push(<line key={i} x1={x1} y1={y1} x2={x2} y2={y2}
      stroke={color} strokeWidth="1.6" strokeLinecap="round" opacity={0.85} />);
  }
  return (
    <div style={{
      width: size, height: size, position: "relative",
      borderRadius: "50%", background: "var(--paper)",
      boxShadow: "var(--shadow-pop)",
      border: "0.5px solid var(--hairline-strong)",
      ...ind_pad,
    }}>
      <svg width={size} height={size} style={{ position: "absolute", inset: 0 }}>
        {lines}
        <circle cx={cx} cy={cy} r={baseR - 2} fill="none" stroke="var(--hairline)" strokeWidth="0.5" />
      </svg>
      <div style={{
        position: "absolute", left: 0, right: 0, top: cy - 8, textAlign: "center",
        fontSize: 10, fontVariantNumeric: "tabular-nums", color: "var(--ink-2)",
      }}>{fmtTime(seconds)}</div>
      <div style={{
        position: "absolute", left: 0, right: 0, top: cy + 4, textAlign: "center",
        fontSize: 8, color: "var(--ink-3)", letterSpacing: "0.1em", textTransform: "uppercase",
      }}>{statusLabel(state)}</div>
      <button onClick={onCancel} style={{
        position: "absolute", top: -4, right: -4,
        width: 20, height: 20, borderRadius: "50%",
        background: "var(--paper-2)", border: "0.5px solid var(--hairline-strong)",
        cursor: "pointer", padding: 0, display: "flex", alignItems: "center", justifyContent: "center",
        color: "var(--ink-2)",
      }}>
        <svg width="8" height="8" viewBox="0 0 8 8"><path d="M1.5 1.5l5 5M6.5 1.5l-5 5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/></svg>
      </button>
    </div>
  );
}

// ── C — barra vertical lateral ───────────────────────────
function IndicatorVertical({ state = "recording", level = 0.6, seconds = 12, onCancel }) {
  const t = Math.floor(Date.now() / 80);
  const bars = 18;
  const color = state === "recording" ? "var(--carmine)" : "var(--amber)";
  return (
    <div style={{
      width: 38, padding: "12px 8px",
      background: "var(--paper)",
      borderRadius: 14,
      boxShadow: "var(--shadow-pop)",
      border: "0.5px solid var(--hairline-strong)",
      display: "flex", flexDirection: "column", alignItems: "center", gap: 8,
      ...ind_pad,
    }}>
      <div style={{ width: 6, height: 6, borderRadius: "50%", background: color }}
        className={state === "recording" ? "tg-pulse" : ""} />
      <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "center" }}>
        {Array.from({ length: bars }).map((_, i) => {
          const seed = (Math.sin(i * 1.1 + t * 0.5) + 1) / 2;
          const env = Math.sin((i / bars) * Math.PI);
          const w = Math.max(3, (0.2 + level * 0.8 * (seed * 0.7 + 0.3)) * 22 * (0.4 + env * 0.7));
          return <div key={i} style={{ width: w, height: 2, background: "var(--ink)", opacity: 0.85 }} />;
        })}
      </div>
      <div style={{
        fontSize: 9, fontVariantNumeric: "tabular-nums", color: "var(--ink-2)",
        writingMode: "vertical-rl", transform: "rotate(180deg)", letterSpacing: "0.05em",
      }}>{fmtTime(seconds)}</div>
      <div style={{ width: 18, height: 1, background: "var(--hairline)" }} />
      <button onClick={onCancel} style={{
        width: 18, height: 18, border: "none", background: "transparent",
        color: "var(--ink-3)", cursor: "pointer", padding: 0,
      }}>
        <svg width="8" height="8" viewBox="0 0 8 8"><path d="M1.5 1.5l5 5M6.5 1.5l-5 5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/></svg>
      </button>
    </div>
  );
}

// ── D — HUD estilo Siri (gradiente animado) ──────────────
function IndicatorHUD({ state = "recording", level = 0.6, seconds = 12, onCancel }) {
  // Inner content dark; outer ring is the animated sweep
  return (
    <div style={{ position: "relative", padding: 3, borderRadius: 18, ...ind_pad }}>
      {/* animated gradient frame */}
      <div style={{
        position: "absolute", inset: 0, borderRadius: 18,
        background: state === "recording"
          ? "linear-gradient(110deg, #c8311c, #e8a040, #c8311c, #8f1d0d, #c8311c)"
          : "linear-gradient(110deg, #c97a14, #e8b86b, #c97a14)",
        backgroundSize: "200% 100%",
        animation: "tg-sweep 3s linear infinite",
        filter: "blur(0.5px)",
      }} />
      <div style={{
        position: "relative",
        display: "flex", alignItems: "center", gap: 14,
        padding: "12px 16px",
        background: "rgba(20, 16, 12, 0.92)",
        backdropFilter: "blur(20px)",
        borderRadius: 15,
        color: "#f4ede0",
      }}>
        <div style={{ width: 8, height: 8, borderRadius: "50%", background: "#e85a3f" }}
          className={state === "recording" ? "tg-pulse" : ""} />
        <WaveBars level={level} color="#f4ede0" height={26} width={104} count={20} />
        <div style={{ fontSize: 11, fontVariantNumeric: "tabular-nums", opacity: 0.8 }}>
          {fmtTime(seconds)}
        </div>
        <div style={{ width: 1, height: 18, background: "rgba(244,237,224,0.18)" }} />
        <button onClick={onCancel} style={{
          width: 22, height: 22, border: "none", background: "transparent",
          color: "#f4ede0", opacity: 0.6, cursor: "pointer", padding: 0,
        }}>
          <svg width="10" height="10" viewBox="0 0 10 10"><path d="M2 2l6 6M8 2l-6 6" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/></svg>
        </button>
      </div>
    </div>
  );
}

Object.assign(window, { IndicatorPill, IndicatorOrb, IndicatorVertical, IndicatorHUD, WaveBars, fmtTime, statusLabel, statusColor });
