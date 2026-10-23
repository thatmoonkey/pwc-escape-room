---
name: iom-rebuild
overview: >-
  Rebuild the Adamant Verity experience around the Intelligent Operating Model:
  the player configures and activates a new operating model rather than
  repairing a broken AI.
createdAt: '2026-10-21T09:10:35.443Z'
todos:
  - id: mandate-spine
    content: >-
      Build the decision spine: an OperatingModel data layer, the boot mandate
      (objective + risk appetite), a spectrum decision component in the
      terminal, and Navigation as the first migrated bay with its guardrail and
      consistency verdict.
    status: completed
  - id: four-bays
    content: >-
      Re-theme the other four bays as autonomy-spectrum decisions with their own
      trade-off, guardrail options, consequence tag and reflection card: Life
      Support, Comms, Cargo, Engineering.
    status: completed
  - id: legacy-contrast
    content: >-
      Show each bay's scenario running under the legacy model before the player
      configures, so the old model is demonstrated rather than narrated.
    status: pending
  - id: brand-layer
    content: >-
      Apply the PwC brand system to the whole 2D layer from one constants
      source: terminal, HUD, cards, launch and summary screens, Georgia and
      Arial type scale, 12-column layout, logo and Momentum Mark only on title
      and closing summary.
    status: pending
  - id: private-profile
    content: >-
      Build the private operating-model profile: archetype name, spectrum
      positions, consistency and coherence readout, and the host conversation
      opener.
    status: pending
  - id: collective-screen
    content: >-
      Build the anonymised collective-patterns screen with offline-first
      aggregation: cohort distribution, most-divided decisions, category
      leaders, callsigns.
    status: pending
  - id: full-run-check
    content: >-
      Run the full five-decision experience end to end, check save, retry and
      resume paths, the three input layers, and the profile as the deliverable.
    status: pending
  - id: governance-decisions
    content: >-
      Add the three governance decisions beyond the five bays, on consoles the
      ship already has: the deck 1 junction kiosk (human authority), the deck 2
      junction kiosk (control plane), and the cockpit helm (final activation of
      the model, where the run ends and the profile is produced).
    status: pending
---
# Intelligent Operating Model rebuild

## What changes, in one line
The experience stops being "catch the AI being wrong" and becomes "design a
system of work". The ship, the five bays, the architecture and the puzzle
framework all stay. The thesis, the scoring and the 2D visual identity change.

## The two rules that decide the whole build

**1. The yardstick comes first.** Consistency can only be measured against
something declared before the decision. So the mandate - mission objective plus
risk appetite - is a scoring prerequisite, not an opening cutscene. A player who
picks a risk appetite after seeing the bays is rationalising, not deciding.

**2. There is no correct answer.** Every bay is a placement on a four-level
autonomy spectrum plus one guardrail. Nothing is graded right or wrong. What is
graded is whether the placement follows from the mandate the player set.

## Scoring: replace judgement-and-time with consistency-and-coherence
The current model is the one thing that cannot be adapted. It grades proximity
to a single correct human-in-the-loop answer and prices the run on a clock.
Both halves are wrong now: there is no correct answer, and speed is explicitly
out of scope. So scripts/systems/score.gd is rewritten:

- **Time is removed entirely.** No clock in the score, no time points. The
  elapsed value may stay for a host's own interest, but it never scores.
- **Consistency** - does the placement follow from the stated objective and
  risk appetite? A cautious mandate and a human-only placement agree.
- **Coherence** - is the placement defensible for that decision's consequence?
  This axis exists to stop consistency being gamed: a player who picks Cautious
  and then over-controls everything would otherwise score perfectly. A cautious
  mandate on a reversible, low-consequence decision is over-controlled and
  wasteful; an ambitious mandate on an irreversible one is under-controlled.
  Consistency alone rewards the most conservative player who ever played.

Proportionality between consequence and autonomy is the actual IOM lesson, and
it is what makes "always keep a human in the loop" a wrong answer too.

## Each decision carries (consequence, reversibility)
For autonomy-vs-assurance to mean anything, the five decisions must not all
weigh the same. Each bay is tagged with how bad it is to get it wrong and
whether it can be undone, and that tag is shown to the player. It is the input
to a defensible placement, so it must be visible rather than hidden in the
scoring.

## The guardrail is where the trade-off actually lives
The spectrum position is the headline; the guardrail is the substance, because
a guardrail has to cost something against the objective. Navigation's options,
for instance: a hard hazard ceiling protects resilience but forfeits an
opportunistic window; continuous sensor re-validation buys assurance with crew
attention; per-re-route human sign-off buys control with speed. A guardrail
that costs nothing is not a decision.

## Milestones
1. **mandate-spine** - OperatingModel data layer, the boot mandate, a spectrum
   component in the terminal, Navigation migrated as the first bay.
2. **four-bays** - Life Support, Comms, Cargo, Engineering migrated, each built
   as the client's own DECISION BUNDLE: decompose the work (what is repetitive,
   what needs judgement, what is coordination), reassemble it (AI and people
   each doing what they are best placed to do), then hold it to account. Each
   bay reframes its process view as a decision view, the way the pack's claims
   example turns Receive-Triage-Assess-Settle into Claim validity / Coverage /
   Fraud risk / Settlement value. Every bay also names an ACCOUNTABLE OWNER.
3. **governance-decisions** - the three layers beyond the five bays, placed on
   consoles the ship already has, so all eight are decided without building a
   single new room: the deck 1 junction kiosk (human authority - who owns the
   outcomes and the escalation path), the deck 2 junction kiosk (control plane -
   evidence, rollback and audit depth), and the cockpit helm (the final
   ACTIVATION of the model, where the run ends and the profile is produced).
   Same spectrum-and-guardrail mechanic, same owner requirement.
4. **legacy-contrast** - each decision shows the legacy model's own logic
   already running before the player configures, so "optimised around
   objectives that were never completely specified" is demonstrated rather
   than narrated.
5. **brand-layer** - the PwC system across the 2D layer from one constants file.
6. **private-profile** - the profile leads with where the player sat between
   COMPRESSION (automate, cut, chase efficiency) and TRANSFORMATION (reallocate
   toward judgement and accountability), because that is the pack's own measure
   of success: not how much work is removed but how effectively work is
   redesigned around decisions, governance and people. Then the archetype, the
   spectrum positions, consistency and coherence, and the host conversation
   opener.
6. **collective-screen** - anonymised cohort patterns, offline-first.
7. **full-run-check** - the whole run, both save paths, three input layers.

## Architecture
Extend, do not replace. Puzzle stays the bay contract; ScreenState gains typed
blocks so a decision can render as a spectrum selector and the profile as a
chart, rather than everything being flat text lines and a button list.
OperatingModel is new and dependency-free like GameState, which reads it and
persists it. Score reads both and still computes in one file.

The four bays not yet migrated keep compiling and read as "not placed" through
the sentinel GameState already uses for a room nobody opened. That is honest
mid-rebuild state, not a silent zero.

## Stays untouched
The interior, the cockpit, the exterior window feed, the station kit, the
hull, the audio mix. The 3D keeps its ember palette; only the door and lintel
accent strips may shift to Orange 500. The brand system governs the 2D layer.

## The accountable-owner step, and where it comes from
The digest hands over the mechanic that makes the whole thesis visible, and it
is the client's own rather than our invention: the pack's control plane "gates
by reversibility and risk", and "nothing irreversible happens without a named
accountable owner". So any placement other than human-only asks the player to
NAME the role that owns the outcome. That is one extra field per bay, and it
does what paragraphs of copy cannot: the player cannot grant autonomy without
saying who answers for it. It also grounds the coherence axis, which is the
control-plane principle applied to a placement rather than a scoring invention.

## The eight layers are the framing, not eight rooms
The pack's eight-layer architecture (human authority, experience surfaces,
domain model, orchestration, agents and AI services, control plane, data
foundation, systems of record) is described as the metaphor spine, and the
player activates the IOM layer by layer. Eight rooms would bury the five
decisions, so the working split is: the five bays stay the five decisions, and
the layers become what SHIPMIND and the terminal visualise - with the CONTROL
PLANE getting a screen of its own, because it is the layer that "governs, never
executes" and it is where the guardrails, the evidence and the accountable owner
live. CONFIRM BEFORE BUILDING.

## Open questions for the client
- Archetype names. The digest does not name them either, so they are ours to
  propose. Grounded in the pack's own vocabulary, a working set is: Compression
  Operator, Control-Plane Architect, Reassembly Lead, Reversible Pragmatist.
- How the collective screen aggregates across many conference devices off a
  single venue network, and what happens when that network is unavailable.
- Whether the eight-layer treatment above is right, or whether the client wants
  the layers to be more literally walkable.
