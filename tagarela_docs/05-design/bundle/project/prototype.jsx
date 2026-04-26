// Interactive prototype — full pipeline simulation with tweaks.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "light",
  "indicator": "pill",
  "style": "profissional",
  "forceState": "auto"
}/*EDITMODE-END*/;

function Prototype() {
  const [tw, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [state, setState] = React.useState("idle");
  const [seconds, setSeconds] = React.useState(0);
  const [level, setLevel] = React.useState(0.5);
  const [shownText, setShownText] = React.useState("");
  const [refined, setRefined] = React.useState("");
  const [showPrefs, setShowPrefs] = React.useState(false);
  const [menuOpen, setMenuOpen] = React.useState(false);
  const [toast, setToast] = React.useState(null);

  // forceState override
  const effectiveState = tw.forceState !== "auto" ? tw.forceState : state;

  React.useEffect(() => {
    document.documentElement.dataset.theme = tw.theme;
  }, [tw.theme]);

  // sim tick
  React.useEffect(() => {
    let i;
    if (state === "recording") {
      const t0 = Date.now();
      i = setInterval(() => {
        setSeconds((Date.now() - t0) / 1000);
        setLevel(0.4 + Math.random() * 0.5);
      }, 80);
    }
    return () => clearInterval(i);
  }, [state]);

  // hotkey simulation
  React.useEffect(() => {
    const onKey = (e) => {
      if (e.code === "AltRight" || (e.altKey && e.code === "AltRight")) {
        e.preventDefault();
        toggle();
      }
      if (e.key === "Escape" && state !== "idle") cancel();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  const RAW = "então tipo precisa adicionar um pool de conexões pro postgres ali sabe com timeout de uns 30 segundos e tipo um retry exponencial se der erro";
  const REFINED_BY_STYLE = {
    profissional: "Precisamos adicionar um pool de conexões para o Postgres com timeout de 30 segundos e retry exponencial em caso de erro.",
    informal: "Precisa adicionar um pool de conexões pro Postgres, sabe? Com timeout de uns 30 segundos e um retry exponencial se der erro.",
    notas: "- pool de conexões → Postgres\n- timeout: 30s\n- retry: exponencial em caso de erro",
    cru: RAW,
  };

  function toggle() {
    if (state === "idle") {
      setState("recording");
      setSeconds(0);
      setShownText("");
      setRefined("");
    } else if (state === "recording") {
      setState("processing");
      // animate raw text appearing
      setTimeout(() => {
        let i = 0;
        const id = setInterval(() => {
          i += 3;
          setShownText(RAW.slice(0, i));
          if (i >= RAW.length) {
            clearInterval(id);
            if (tw.style === "cru") {
              setRefined(RAW);
              setTimeout(finish, 400);
            } else {
              setState("refining");
              setTimeout(() => {
                let j = 0;
                const target = REFINED_BY_STYLE[tw.style] || REFINED_BY_STYLE.profissional;
                const rid = setInterval(() => {
                  j += 2;
                  setRefined(target.slice(0, j));
                  if (j >= target.length) {
                    clearInterval(rid);
                    setTimeout(finish, 350);
                  }
                }, 30);
              }, 600);
            }
          }
        }, 18);
      }, 700);
    }
  }

  function finish() {
    setState("idle");
    setToast({ tone: "success", icon: "✓", title: "colado em vs code", body: "histórico atualizado." });
    setTimeout(() => setToast(null), 2500);
  }

  function cancel() {
    setState("idle");
    setShownText("");
    setRefined("");
  }

  // pick indicator
  const Indicator = { pill: IndicatorPill, orb: IndicatorOrb, vertical: IndicatorVertical, hud: IndicatorHUD }[tw.indicator] || IndicatorPill;
  const showIndicator = effectiveState === "recording" || effectiveState === "processing" || effectiveState === "refining";

  return (
    <div style={{
      width: "100vw", height: "100vh", overflow: "hidden",
      background: "var(--paper)", color: "var(--ink)",
      display: "flex", flexDirection: "column",
      fontFamily: "var(--font-ui)",
      position: "relative",
    }}>
      {/* mac menu bar */}
      <div style={{
        height: 26,
        background: tw.theme === "dark" ? "rgba(20, 16, 12, 0.85)" : "rgba(244, 237, 224, 0.92)",
        backdropFilter: "blur(20px)",
        borderBottom: "0.5px solid var(--hairline)",
        display: "flex", alignItems: "center", padding: "0 12px",
        fontFamily: "var(--font-ui)", fontSize: 13, color: "var(--ink)",
        gap: 14, position: "relative", zIndex: 10,
      }}>
        <span style={{ fontWeight: 600, fontSize: 14 }}></span>
        <span style={{ fontWeight: 600 }}>VS Code</span>
        <span style={{ opacity: 0.7 }}>File</span>
        <span style={{ opacity: 0.7 }}>Edit</span>
        <span style={{ opacity: 0.7 }}>View</span>
        <span style={{ opacity: 0.7 }}>Go</span>
        <span style={{ opacity: 0.7 }}>Window</span>
        <span style={{ opacity: 0.7 }}>Help</span>
        <div style={{ flex: 1 }} />
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <span style={{ fontSize: 11, opacity: 0.7 }}>89%</span>
          <div onClick={() => setMenuOpen(!menuOpen)} style={{ cursor: "pointer", padding: "0 4px", borderRadius: 4, background: menuOpen ? "var(--paper-3)" : "transparent" }}>
            <Glyph size={14} color="var(--ink)" recording={effectiveState === "recording"} />
          </div>
          <span style={{ fontSize: 11, fontVariantNumeric: "tabular-nums", opacity: 0.85 }}>14:23</span>
        </div>
      </div>

      {/* status bar dropdown */}
      {menuOpen && (
        <div style={{ position: "absolute", top: 30, right: 56, zIndex: 20 }}>
          <MenuBarExtra state={effectiveState === "refining" ? "processing" : effectiveState} />
        </div>
      )}

      {/* fake VS Code */}
      <div style={{ flex: 1, display: "flex", overflow: "hidden", background: tw.theme === "dark" ? "#15110d" : "#f4ede0" }}>
        <FakeVSCode shownText={shownText} refined={refined} state={effectiveState} style={tw.style} onTrigger={toggle} />
      </div>

      {/* indicator near cursor */}
      {showIndicator && (
        <div style={{
          position: "absolute",
          left: "50%", top: "62%",
          transform: "translate(-50%, -50%)",
          zIndex: 30, pointerEvents: "auto",
        }}>
          <Indicator
            state={effectiveState === "refining" ? "processing" : effectiveState}
            level={level}
            seconds={seconds}
            onCancel={cancel}
          />
        </div>
      )}

      {/* hint */}
      {state === "idle" && tw.forceState === "auto" && (
        <div style={{
          position: "absolute", bottom: 24, left: "50%", transform: "translateX(-50%)",
          padding: "8px 14px",
          background: "var(--paper-2)",
          border: "0.5px solid var(--hairline-strong)",
          borderRadius: "var(--r-pill)",
          fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--ink-2)",
          boxShadow: "var(--shadow-md)",
          display: "flex", alignItems: "center", gap: 8,
        }}>
          <kbd style={{ fontFamily: "var(--font-mono)", padding: "1px 6px", background: "var(--paper)", border: "0.5px solid var(--hairline-strong)", borderRadius: 3, fontSize: 10 }}>right ⌥</kbd>
          ou clique no botão pra começar
        </div>
      )}

      {/* toast */}
      {toast && (
        <div style={{ position: "absolute", top: 38, right: 14, zIndex: 25 }}>
          <Toast {...toast} />
        </div>
      )}

      {/* prefs window */}
      {showPrefs && (
        <div style={{
          position: "absolute", inset: 0, zIndex: 40,
          background: "rgba(0,0,0,0.2)",
          display: "flex", alignItems: "center", justifyContent: "center",
        }} onClick={() => setShowPrefs(false)}>
          <div style={{ width: 720, height: 520, boxShadow: "var(--shadow-pop)", borderRadius: 12, overflow: "hidden" }} onClick={e => e.stopPropagation()}>
            <PrefLLM />
          </div>
        </div>
      )}

      {/* tweaks panel */}
      <TweaksPanel title="Tweaks">
        <TweakSection title="Tema">
          <TweakRadio value={tw.theme} onChange={v => setTweak("theme", v)}
            options={[{ value: "light", label: "claro" }, { value: "dark", label: "escuro" }]} />
        </TweakSection>
        <TweakSection title="Indicador">
          <TweakRadio value={tw.indicator} onChange={v => setTweak("indicator", v)}
            options={[
              { value: "pill", label: "pílula" },
              { value: "orb", label: "bolha" },
              { value: "vertical", label: "vertical" },
              { value: "hud", label: "siri" },
            ]} />
        </TweakSection>
        <TweakSection title="Estilo de refino">
          <TweakSelect value={tw.style} onChange={v => setTweak("style", v)}
            options={[
              { value: "profissional", label: "e-mail profissional" },
              { value: "informal", label: "conversa informal" },
              { value: "notas", label: "notas técnicas" },
              { value: "cru", label: "cru — sem refino" },
            ]} />
        </TweakSection>
        <TweakSection title="Forçar estado">
          <TweakSelect value={tw.forceState} onChange={v => setTweak("forceState", v)}
            options={[
              { value: "auto", label: "auto (interativo)" },
              { value: "idle", label: "idle" },
              { value: "recording", label: "recording" },
              { value: "processing", label: "processing" },
              { value: "error", label: "error" },
            ]} />
        </TweakSection>
        <TweakButton onClick={() => setMenuOpen(o => !o)}>menu da status bar</TweakButton>
        <TweakButton onClick={() => setShowPrefs(o => !o)}>abrir preferências</TweakButton>
        <TweakButton onClick={toggle}>simular hotkey (right ⌥)</TweakButton>
      </TweaksPanel>
    </div>
  );
}

// Fake VS Code — minimal
function FakeVSCode({ shownText, refined, state, style: refineStyle, onTrigger }) {
  const showRaw = state === "processing" || state === "refining" || (state === "idle" && refined);
  const showRefined = state === "refining" || (state === "idle" && refined);

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", background: "var(--paper)" }}>
      {/* tab bar */}
      <div style={{
        height: 36, background: "var(--paper-2)",
        borderBottom: "0.5px solid var(--hairline)",
        display: "flex", alignItems: "center", padding: "0 12px", gap: 0,
      }}>
        <div style={{
          padding: "8px 12px",
          background: "var(--paper)",
          borderRight: "0.5px solid var(--hairline)",
          fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--ink)",
          display: "flex", alignItems: "center", gap: 8,
        }}>
          <span style={{ color: "var(--carmine)" }}>●</span>
          notes.md
        </div>
        <div style={{ flex: 1 }} />
      </div>

      {/* editor */}
      <div style={{ flex: 1, padding: "32px 56px", fontFamily: "var(--font-mono)", fontSize: 14, color: "var(--ink)", lineHeight: 1.7, position: "relative" }}>
        <div style={{ color: "var(--ink-3)" }}># PR review · postgres pool</div>
        <div style={{ height: 16 }} />
        <div style={{ color: "var(--ink-2)" }}>de [@marina](#) hoje 13:42</div>
        <div style={{ height: 16 }} />

        {!showRaw && (
          <div style={{ color: "var(--ink-3)", fontStyle: "italic" }}>
            <span style={{ color: "var(--carmine)" }} className="tg-caret">|</span>
          </div>
        )}

        {showRaw && !showRefined && (
          <div style={{ color: "var(--ink-3)" }}>
            <span style={{
              fontFamily: "var(--font-mono)", fontSize: 9,
              padding: "1px 5px", background: "var(--paper-2)",
              border: "0.5px solid var(--hairline)", borderRadius: 2,
              marginRight: 8, letterSpacing: "0.08em", color: "var(--ink-3)",
              textTransform: "uppercase",
            }}>cru</span>
            {shownText}
            {state === "processing" && <span className="tg-caret" style={{ color: "var(--amber)" }}>|</span>}
          </div>
        )}

        {showRefined && (
          <div style={{ color: "var(--ink)", whiteSpace: "pre-wrap" }}>
            {refineStyle === "notas" && refined.includes("\n")
              ? refined.split("\n").map((l, i) => <div key={i}>{l}</div>)
              : refined}
            {state === "refining" && <span className="tg-caret" style={{ color: "var(--carmine)" }}>|</span>}
          </div>
        )}
      </div>

      {/* footer / status */}
      <div style={{
        height: 24, background: "var(--ink)", color: "var(--paper)",
        display: "flex", alignItems: "center", padding: "0 12px",
        fontFamily: "var(--font-mono)", fontSize: 10, gap: 14,
      }}>
        <span>main</span>
        <span style={{ opacity: 0.5 }}>·</span>
        <span>UTF-8</span>
        <span style={{ opacity: 0.5 }}>·</span>
        <span>Markdown</span>
        <div style={{ flex: 1 }} />
        <span style={{ opacity: 0.7 }}>tagarela</span>
        <span style={{
          width: 6, height: 6, borderRadius: "50%",
          background: state === "recording" ? "var(--carmine)" : state === "processing" || state === "refining" ? "var(--amber)" : "var(--moss)",
        }} />
      </div>
    </div>
  );
}

Object.assign(window, { Prototype });
