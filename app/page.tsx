"use client";

import { useEffect, useMemo, useState } from "react";

type MeetingHealth = "well" | "okay" | "poor";
type ScenarioKey = "paradox" | "momentum" | "recovery";

type TranscriptEvent = {
  speaker: "You" | "Maya" | "Devon";
  parts: Array<{ text: string; highlight?: boolean }>;
  coach: string;
  expertise?: string;
};

const events: TranscriptEvent[] = [
  {
    speaker: "Maya",
    parts: [
      {
        text: "Before we add another initiative, I need a sharper reason to prioritize this now.",
      },
    ],
    coach: "Listen for the real objection before you make the case.",
  },
  {
    speaker: "You",
    parts: [
      { text: "The " },
      { text: "adoption curve", highlight: true },
      { text: " is already moving; a " },
      { text: "focused pilot", highlight: true },
      { text: " lets us learn before the market sets the pace." },
    ],
    coach: "Strong framing. You connected urgency to a bounded action.",
    expertise: "Market strategy",
  },
  {
    speaker: "Devon",
    parts: [
      {
        text: "I understand the signal, but we are already overcommitted this quarter.",
      },
    ],
    coach: "Your point landed. The room is still protecting capacity.",
  },
  {
    speaker: "You",
    parts: [
      { text: "We can isolate the " },
      { text: "four-week pilot", highlight: true },
      { text: " to two teams, protect the roadmap, and name " },
      { text: "Product Ops", highlight: true },
      { text: " as the single owner." },
    ],
    coach: "Clear and specific. Do not mistake clarity for agreement.",
    expertise: "Operating model",
  },
  {
    speaker: "Maya",
    parts: [
      {
        text: "The ownership is better. I am still not convinced the upside offsets the distraction.",
      },
    ],
    coach: "Meeting health is falling even as your delivery stays strong.",
  },
  {
    speaker: "You",
    parts: [
      { text: "Success is a " },
      { text: "15% faster handoff", highlight: true },
      { text: ", measured weekly. If we miss it at " },
      { text: "week four", highlight: true },
      { text: ", we stop." },
    ],
    coach: "All four points are covered. Ask what evidence would change the decision.",
    expertise: "Measurement",
  },
  {
    speaker: "Devon",
    parts: [
      { text: "Your plan is clear. " },
      { text: "I’m not ready to move the team yet.", highlight: true },
    ],
    coach: "Strong meeting performance. Poor meeting outcome. Surface the blocker.",
  },
];

const points = [
  { short: "Scope", label: "Scope a four-week pilot", hitAt: 3 },
  { short: "Signal", label: "Prove the adoption signal", hitAt: 1 },
  { short: "Owner", label: "Name an owner + guardrails", hitAt: 3 },
  { short: "Metric", label: "Set a 15% success metric", hitAt: 5 },
];

const scenarios: Record<
  ScenarioKey,
  {
    label: string;
    eyebrow: string;
    description: string;
    health: MeetingHealth[];
    clarity: number[];
  }
> = {
  paradox: {
    label: "Strong / Tense",
    eyebrow: "THE CORE PARADOX",
    description: "You land every point. The room still resists.",
    health: ["okay", "okay", "poor", "poor", "poor", "poor", "poor"],
    clarity: [68, 78, 81, 86, 89, 94, 94],
  },
  momentum: {
    label: "Strong / Aligned",
    eyebrow: "MOMENTUM",
    description: "Clear delivery and room alignment rise together.",
    health: ["okay", "okay", "okay", "well", "well", "well", "well"],
    clarity: [68, 78, 81, 86, 89, 94, 94],
  },
  recovery: {
    label: "Recover the room",
    eyebrow: "RECOVERY",
    description: "The room starts cold, then the evidence earns trust.",
    health: ["poor", "poor", "poor", "okay", "okay", "well", "well"],
    clarity: [54, 66, 69, 76, 82, 88, 91],
  },
};

const healthCopy: Record<
  MeetingHealth,
  { label: string; short: string; value: string }
> = {
  well: { label: "Going well", short: "Aligned", value: "82" },
  okay: { label: "Going okay", short: "Mixed", value: "57" },
  poor: { label: "Going poorly", short: "Resistant", value: "28" },
};

function formatTime(totalSeconds: number) {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return minutes + ":" + String(seconds).padStart(2, "0");
}

export default function Home() {
  const [scenarioKey, setScenarioKey] = useState<ScenarioKey>("paradox");
  const [step, setStep] = useState(0);
  const [running, setRunning] = useState(true);
  const [elapsed, setElapsed] = useState(18 * 60 + 12);

  const scenario = scenarios[scenarioKey];
  const event = events[step];
  const health = scenario.health[step];
  const clarity = scenario.clarity[step];
  const hitCount = points.filter((point) => step >= point.hitAt).length;
  const isFinished = step === events.length - 1;

  const speakerStrength = useMemo(() => {
    if (clarity >= 88) return "Strong";
    if (clarity >= 72) return "Steady";
    return "Building";
  }, [clarity]);

  useEffect(() => {
    if (!running) return;

    const timer = window.setInterval(() => {
      setElapsed((value) => value + 1);
    }, 1000);

    return () => window.clearInterval(timer);
  }, [running]);

  useEffect(() => {
    if (!running) return;

    const timer = window.setTimeout(() => {
      if (step >= events.length - 1) {
        setRunning(false);
        return;
      }
      setStep((value) => value + 1);
    }, 4100);

    return () => window.clearTimeout(timer);
  }, [running, step, scenarioKey]);

  function selectScenario(key: ScenarioKey) {
    setScenarioKey(key);
    setStep(0);
    setElapsed(18 * 60 + 12);
    setRunning(true);
  }

  function restart() {
    setStep(0);
    setElapsed(18 * 60 + 12);
    setRunning(true);
  }

  function togglePlayback() {
    if (isFinished && !running) {
      restart();
      return;
    }
    setRunning((value) => !value);
  }

  return (
    <main className="prototype-shell">
      <section className="phone-stage" aria-label="Meeting Coach iPhone prototype">
        <div className="phone-frame">
          <div className="phone-screen">
            <div className="ambient ambient-one" />
            <div className="ambient ambient-two" />

            <div className="system-bar" aria-hidden="true">
              <span>9:41</span>
              <div className="dynamic-island" />
              <span className="system-icons">▮▮▮ ◒ ▰</span>
            </div>

            <div className="lock-heading" aria-hidden="true">
              <p>Thursday, July 10</p>
              <h2>9:41</h2>
            </div>

            <article
              className={"coach-card health-" + health}
              aria-label={"Live meeting coach. Meeting is " + healthCopy[health].label}
            >
              <header className="card-header">
                <div className="live-lockup">
                  <span className="live-dot" />
                  <span>{isFinished ? "REVIEW READY" : "LIVE COACH"}</span>
                </div>
                <span className="meeting-time">{formatTime(elapsed)}</span>
              </header>

              <div className="meeting-title-row">
                <div>
                  <p className="overline">Q3 PRODUCT REVIEW</p>
                  <h1>Meeting Coach</h1>
                </div>
                <span className="waveform" aria-label={running ? "Listening" : "Paused"}>
                  <i />
                  <i />
                  <i />
                  <i />
                  <i />
                </span>
              </div>

              <div className="signal-row">
                <div className="signal signal-meeting">
                  <span className="signal-kicker">MEETING</span>
                  <strong>{healthCopy[health].short}</strong>
                </div>
                <div className="signal signal-you">
                  <span className="signal-kicker">YOUR DELIVERY</span>
                  <strong>{speakerStrength}</strong>
                </div>
              </div>

              <section className="transcript-window" aria-live="polite">
                <div className="transcript-meta">
                  <span className={event.speaker === "You" ? "speaker-you" : ""}>
                    {event.speaker}
                  </span>
                  <span>{step + 1} / {events.length}</span>
                </div>
                <div className="ticker-mask">
                  <p className="ticker-track" key={scenarioKey + "-" + step}>
                    {event.parts.map((part, index) =>
                      part.highlight ? (
                        <mark key={index}>{part.text}</mark>
                      ) : (
                        <span key={index}>{part.text}</span>
                      ),
                    )}
                  </p>
                </div>
                {event.expertise ? (
                  <div className="expertise-chip">
                    <span>EXPERTISE</span>
                    {event.expertise}
                  </div>
                ) : (
                  <div className="listening-chip">LISTENING FOR RESISTANCE</div>
                )}
              </section>

              <section className="coach-note">
                <span>COACH NOTE</span>
                <p>{event.coach}</p>
              </section>

              <div className="metric-row">
                <div className="clarity-block">
                  <div className="clarity-label">
                    <span>COMMUNICATION CLARITY</span>
                    <strong>{clarity}%</strong>
                  </div>
                  <div
                    className="clarity-track"
                    role="progressbar"
                    aria-valuenow={clarity}
                    aria-valuemin={10}
                    aria-valuemax={100}
                    aria-label="Communication clarity"
                  >
                    <span style={{ width: clarity + "%" }} />
                  </div>
                </div>

                <div className="point-count">
                  <strong>{hitCount}/{points.length}</strong>
                  <span>POINTS</span>
                </div>
              </div>

              <div className="point-row" aria-label="Predetermined meeting points">
                {points.map((point, index) => {
                  const complete = step >= point.hitAt;
                  return (
                    <div className="point-item" key={point.label}>
                      <span
                        className={"point-circle " + (complete ? "complete" : "")}
                        title={point.label}
                      >
                        {complete ? "✓" : String(index + 1).padStart(2, "0")}
                      </span>
                      <span>{point.short}</span>
                    </div>
                  );
                })}
              </div>
            </article>

            <div className="lock-actions" aria-hidden="true">
              <span>◐</span>
              <span>●</span>
            </div>
            <div className="home-indicator" />
          </div>
        </div>
      </section>

      <aside className="demo-panel" aria-label="Prototype controls and concept">
        <div className="concept-badge">
          <span />
          MEETING COACH · CONCEPT
        </div>

        <p className="panel-overline">{scenario.eyebrow}</p>
        <h2>Hit every point.<br />Still read the room.</h2>
        <p className="panel-lede">
          The border scores meeting health. Lime scores your own performance.
          They are intentionally independent.
        </p>

        <div className="status-explainer">
          <div>
            <span className="legend-dot good" />
            <p><strong>Green</strong><small>Room is aligned</small></p>
          </div>
          <div>
            <span className="legend-dot okay" />
            <p><strong>Yellow</strong><small>Signals are mixed</small></p>
          </div>
          <div>
            <span className="legend-dot poor" />
            <p><strong>Red</strong><small>Room is resisting</small></p>
          </div>
        </div>

        <div className="scenario-picker">
          <div className="control-label">
            <span>DEMO STORY</span>
            <span>{step + 1} / {events.length}</span>
          </div>
          <div className="scenario-buttons" role="group" aria-label="Demo scenario">
            {(Object.keys(scenarios) as ScenarioKey[]).map((key) => (
              <button
                key={key}
                className={scenarioKey === key ? "selected" : ""}
                onClick={() => selectScenario(key)}
                aria-pressed={scenarioKey === key}
              >
                {scenarios[key].label}
              </button>
            ))}
          </div>
        </div>

        <div className="story-progress" aria-hidden="true">
          {events.map((_, index) => (
            <span
              key={index}
              className={index < step ? "past" : index === step ? "current" : ""}
            />
          ))}
        </div>

        <div className="story-caption">
          <p>{scenario.description}</p>
          <div className="playback-controls">
            <button onClick={togglePlayback}>
              {running ? "Pause" : isFinished ? "Replay" : "Resume"}
            </button>
            <button onClick={restart}>Restart</button>
          </div>
        </div>

        <footer className="panel-footer">
          <span>LOCK SCREEN LIVE ACTIVITY</span>
          <span>HTML-READY PROTOTYPE</span>
        </footer>
      </aside>
    </main>
  );
}
