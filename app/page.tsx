"use client";

import { useEffect, useMemo, useState } from "react";

type Screen = "home" | "nearby" | "pending" | "active" | "settings";
type Snack = "hidden" | "active" | "paused" | "error";

const steps: Array<{ id: Screen; label: string }> = [
  { id: "home", label: "Home" },
  { id: "nearby", label: "Find nearby" },
  { id: "pending", label: "Watch approval" },
  { id: "active", label: "Active sync" },
  { id: "settings", label: "Settings" },
];

const initialCategories = [
  { id: "contacts", name: "Contacts", detail: "2 of 5 groups", enabled: true, color: "#c2803a" },
  { id: "calendar", name: "Calendar & Reminders", detail: "3 of 5 selected", enabled: true, color: "#c25a48" },
  { id: "photos", name: "Photos", detail: "2 of 5 albums", enabled: true, color: "#c99326" },
  { id: "files", name: "Files & iCloud Drive", detail: "2 of 4 folders", enabled: true, color: "#7f9a3e" },
  { id: "health", name: "Health", detail: "3 of 5 categories", enabled: true, color: "#c2485a" },
  { id: "wallet", name: "Wallet Passes", detail: "Off", enabled: false, color: "#5a6478" },
];

export default function Home() {
  const [screen, setScreen] = useState<Screen>("home");
  const [snack, setSnack] = useState<Snack>("hidden");
  const [approved, setApproved] = useState(false);
  const [paused, setPaused] = useState(false);
  const [progress, setProgress] = useState(18);
  const [categories, setCategories] = useState(initialCategories);

  const shared = useMemo(() => categories.filter((item) => item.enabled), [categories]);
  const summary = shared.length > 2 ? `${shared[0].name}, ${shared[1].name} +${shared.length - 2}` : shared.map((item) => item.name).join(" & ");

  useEffect(() => {
    if (screen !== "active" || paused || progress >= 100) return;
    const timer = window.setInterval(() => setProgress((value) => Math.min(value + 1, 100)), 500);
    return () => window.clearInterval(timer);
  }, [screen, paused, progress]);

  function beginApproval() {
    setScreen("pending");
    setApproved(false);
  }

  function approve() {
    setApproved(true);
    window.setTimeout(() => {
      setScreen("active");
      setProgress(18);
      setPaused(false);
    }, 900);
  }

  function stop() {
    setScreen("home");
    setSnack("hidden");
    setApproved(false);
    setPaused(false);
  }

  return (
    <main className="partner-page">
      <header className="mac-bar" aria-label="Prototype status bar">
        <strong>Partner</strong><span>File</span><span>Edit</span>
        <div className="mac-right">{screen === "active" && <span className="sync-chip"><i />Syncing · Van</span>}<span>Fri 9:41</span></div>
      </header>

      <section className="workspace">
        <aside className="control-rail">
          <div className="brand"><i className="brand-mark" /><div><h1>Partner</h1><p>Proximity data-sharing.<br />Consent on both wrists.</p></div></div>
          <nav aria-label="Prototype flow"><p className="rail-label">Flow</p>{steps.map((step, index) => <button key={step.id} className={screen === step.id ? "selected" : ""} onClick={() => setScreen(step.id)}><span>{index + 1}</span>{step.label}</button>)}</nav>
          <div><p className="rail-label">Snack-bar states</p><div className="snack-buttons"><button onClick={() => { setScreen("home"); setSnack("active"); }}>Active</button><button onClick={() => { setScreen("home"); setSnack("paused"); }}>Paused</button><button onClick={() => { setScreen("home"); setSnack("error"); }}>Error</button></div><p className="rail-note">Sets the minimized pill on the Home screen.</p></div>
          <div className="scope-note"><strong>Honest scope</strong><p>Partner only reads Apple system frameworks you grant. It can’t pull other apps’ accounts like Instagram or Venmo.</p></div>
        </aside>

        <div className={`phone ${screen === "active" && !paused ? "glowing" : ""}`}>
          <div className="phone-screen">
            <div className="island" /><div className="status"><span>9:41</span><span>● ◒</span></div>

            {screen === "home" && <section className="screen home-screen"><div><h2>Partner</h2><p>Bring your phones together to sync.</p></div><div className="find-wrap"><button className="find-button" onClick={() => setScreen("nearby")}><span>Tap to<br />begin</span></button><p>Or hold your iPhone near Van’s to start automatically.</p></div><button className="settings-link" onClick={() => setScreen("settings")}><b>B</b><span><strong>Sharing settings</strong><small>{summary || "Nothing shared yet"}</small></span><em>›</em></button>{snack !== "hidden" && <div className={`snack ${snack}`}><i /><span><strong>{snack === "active" ? "Syncing with Van" : snack === "paused" ? "Sync paused" : "Sync interrupted"}</strong><small>{snack === "error" ? "Van moved out of range." : snack === "paused" ? "No data moving." : `${summary} · live`}</small></span>{snack === "active" && <button onClick={() => setSnack("paused")}>Ⅱ</button>}<button onClick={() => setSnack("hidden")}>×</button></div>}</section>}

            {screen === "nearby" && <section className="screen centered"><h2>Looking nearby</h2><div className="nearby-phones"><div><i />You</div><span>•••</span><div><i className="van" />Van</div></div><p className="nearby-pill"><i /> Phones are within 2 ft range</p><div className="bottom-actions"><button className="primary" onClick={beginApproval}>Request sync</button><button className="plain" onClick={() => setScreen("home")}>Cancel</button></div></section>}

            {screen === "pending" && <section className="screen pending"><h2>Confirm on your watches</h2><p>Both of you approve on Apple Watch. Sync only starts if you both agree.</p><div className="approval-list"><div><b>B</b><span><strong>You (Brooke)</strong><small>{approved ? "Approved" : "Tap watch"}</small></span></div><div><b>V</b><span><strong>Van</strong><small>{approved ? "Approving…" : "Tap watch"}</small></span></div></div><div className="privacy"><strong>Two people. Two approvals.</strong><p>Nothing moves until consent is clear on both devices.</p></div><button className="plain" onClick={() => setScreen("home")}>Cancel request</button></section>}

            {screen === "active" && <section className="screen active-screen"><div className="active-hero"><div className="orbit"><i /></div><h2>{paused ? "Sync paused" : "Syncing with Van"}</h2><p>{paused ? "No data moving" : "Live · secured end-to-end"}</p></div><div className="share-list">{shared.slice(0, 4).map((item) => <div key={item.id}><i style={{ background: item.color }} /><span><strong>{item.name}</strong><small>{item.detail}</small></span><em>{paused ? "Paused" : "Live"}</em></div>)}</div><div className="progress"><div><i style={{ width: `${progress}%` }} /></div><span>{progress >= 100 ? "Sync complete" : paused ? `Paused at ${progress}%` : `Syncing… ${progress}%`}</span></div><div className="active-actions"><button className="secondary" onClick={() => setPaused(!paused)}>{paused ? "Resume" : "Pause"}</button><button className="danger" onClick={stop}>Stop</button></div><button className="plain" onClick={() => { setScreen("home"); setSnack(paused ? "paused" : "active"); }}>Minimize</button></section>}

            {screen === "settings" && <section className="screen settings-screen"><div className="screen-head"><button onClick={() => setScreen("home")}>‹</button><h2>Sharing settings</h2><span /></div><p>Choose exactly what Van can see. You can change this anytime.</p><div className="category-list">{categories.map((item) => <button key={item.id} onClick={() => setCategories((all) => all.map((cat) => cat.id === item.id ? { ...cat, enabled: !cat.enabled, detail: cat.enabled ? "Off" : "Selected" } : cat))}><i style={{ background: item.color }} /><span><strong>{item.name}</strong><small>{item.detail}</small></span><em className={item.enabled ? "on" : ""}><i /></em></button>)}</div><small className="settings-foot">Only selected Apple system data is shared. Payment cards and third-party app accounts stay private.</small></section>}
          </div>
        </div>

        <aside className="watch-column"><p className="rail-label">Apple Watch</p><div className={`watch ${screen === "active" && !paused ? "watch-glow" : ""}`}><div className="watch-screen">{screen === "pending" ? <div className="watch-request"><div><b>V</b><strong>Van wants to sync</strong></div><small>Will share</small><p>{summary}</p><button onClick={approve}>{approved ? "Approved ✓" : "Approve"}</button><button onClick={() => setScreen("home")}>Decline</button></div> : screen === "active" ? <div className="watch-active"><i /><strong>{paused ? "Paused" : "Syncing"}</strong><span>with Van</span><button onClick={stop}>Stop</button></div> : <div className="watch-idle"><i /><span>Ready when<br />you are</span></div>}</div></div><p className="watch-hint">{screen === "pending" ? "Both partners tap Approve to begin." : screen === "active" ? "Stop from your wrist anytime." : "Approvals appear here on both watches."}</p></aside>
      </section>
    </main>
  );
}
