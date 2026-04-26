// Wordmark + small logo glyph for tagarela.
// Mixed type: mono "tagarela" with a serif italic 'a' as the brand quirk +
// a small carmine speech-bubble dot above the second 'a'. The dot doubles
// as the recording indicator.

function Wordmark({ size = 32, color = "var(--ink)", accent = "var(--carmine)", glyph = true }) {
  const fs = size;
  return (
    <span style={{
      display: "inline-flex", alignItems: "baseline", gap: 0,
      fontFamily: "var(--font-mono)", fontWeight: 500,
      fontSize: fs, color, letterSpacing: "-0.02em", lineHeight: 1,
      position: "relative",
    }}>
      <span>tag</span>
      <span style={{
        fontFamily: "var(--font-display)", fontStyle: "italic",
        fontWeight: 400, fontSize: fs * 1.18,
        color: accent, lineHeight: 1, position: "relative",
        marginRight: -fs * 0.04,
      }}>a</span>
      <span>rel</span>
      <span style={{ position: "relative" }}>
        a
        {glyph && (
          <span style={{
            position: "absolute",
            top: -fs * 0.18, right: -fs * 0.24,
            width: fs * 0.16, height: fs * 0.16,
            borderRadius: "50%", background: accent,
          }} />
        )}
      </span>
    </span>
  );
}

// Compact mark — just the glyph, used in dock / status bar
function Glyph({ size = 18, color = "var(--ink)", recording = false }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={{ display: "block" }}>
      {/* speech bubble */}
      <path
        d="M4 5h16v11h-9l-5 4v-4H4z"
        stroke={color}
        strokeWidth="1.6"
        strokeLinejoin="round"
        fill={recording ? "var(--carmine)" : "none"}
      />
      {/* three dots inside */}
      <circle cx="9" cy="10.5" r="1" fill={recording ? "white" : color} />
      <circle cx="12" cy="10.5" r="1" fill={recording ? "white" : color} />
      <circle cx="15" cy="10.5" r="1" fill={recording ? "white" : color} />
    </svg>
  );
}

Object.assign(window, { Wordmark, Glyph });
