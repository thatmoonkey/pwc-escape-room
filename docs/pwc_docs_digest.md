# Supplied PwC documents -- digest and game-relevance notes

Prepared 2026-10-21 for the SHIPMIND / space-station experience, next
iteration ("Intelligent Operating Model" reframe).

---

## Document 1: PwC Brand Education -- "PowerPoint for everyone" (v0.10, July 2025)

**What it is:** PwC's internal brand-rulebook for building presentations.
It reads as a slide-template guide, but it is effectively the portable brand
system: colour, type, iconography, layout and photography rules that apply
to ANY surface PwC produces -- including game UI, HUDs, terminals and
leaderboard screens.

### Key content

**Colour system**
- Signature orange is the lead accent: Orange 500 (core) `#FD5108` (253-81-8).
- Orange tints: 400 `#FE7C39`, 300 `#FFAA72`, 200 `#FFCDA8`, 100 `#FFE8D4`,
  50 `#FFF5ED`.
- Greys: 500 `#A1A8B3`, 400 `#B5BCC4`, 300 `#CBD1D6`, 200 `#DFE3E6`,
  100 `#EEEFF1`, 50 `#F5F7F8`.
- Black is lead text colour; white is the main background. Background tints
  for surfaces: Grey 100/200, Orange 100/200.
- Rules: never a fully orange or fully black page; orange is an accent for
  data/highlight, never body text or big backgrounds (except data viz);
  text is black or white only, WCAG AA combinations; white text on orange
  only at 18pt+.

**Typography**
- Two fonts only: Georgia (headlines, body, quotes -- "trust, tradition,
  human") and Arial (sub-heads, labels, data, tables -- "modern, digital").
- Regular and Bold weights only; no italics; sentence case everywhere.
- Hierarchy: Georgia headline / Arial Bold sub-head / Georgia body 1.25
  spacing / Arial for large data numbers.

**Logo & brand marks**
- The PwC logo never appears on content/gameplay surfaces -- covers and
  conclusion screens only. Momentum Mark used sparingly, primary surfaces.
- Never recolour or modify icons/pictograms; never combine them.

**Icons & pictograms**
- Icons: black only, functional/navigation meaning, min 24px, never large,
  linear style with the angled "Momentum" cut.
- Pictograms: orange gradient fill, min 1in, abstract topics.
- Both from approved libraries only.

**Layout**
- 12x12 grid with margins and gutters; align everything to the grid;
  never place elements off-grid or let gutters clog.

**Photography**
- Human, warm, documentary style ("support photography"); licencing
  required; Brand Site library is the source.

**Charts & tables**
- Palette: solid orange + grey tints only, lead with the core orange for
  the single key data point, Georgia chart titles, Arial data labels.

### Game relevance
This is the rulebook for the game's entire 2D layer: terminal screens,
SHIPMIND dialogue UI, principle cards (now: operating-model profile),
and the collective leaderboard. Concrete mappings:
- Terminal palette: white/grey-100 surfaces, black text, Orange 500 accents
  for primary actions and key data; Georgia for narrative text, Arial for
  labels/data. Replace the current cyan/sci-fi accent with Orange 500.
- HUD and profile cards follow the 12-grid and sentence case.
- Icons on terminals: black, approved set, min 24px equivalents.
- PwC logo: title screen and closing summary only -- never on gameplay HUD.

---

## Document 2: Agentic Transformation -- OAOM Intro pack (Generic)

**What it is:** PwC EMEA's introductory pack for the **Orchestrated AI
Operating Model (OAOM)** -- the framework the client feedback says must be
the hero of the experience, and which is now to be referred to as the
**Intelligent Operating Model (IOM)**. Note for all copy: use "Intelligent
Operating Model" (or IOM); treat "OAOM" as the internal legacy name.

### Key content

**Market problem**
- Most AI programmes make work faster; few redesign how the business
  operates. Investment in AI productivity is high, but decision-making,
  accountability and governance are left unchanged. As AI becomes
  autonomous, the operating model itself becomes the transformation
  challenge.

**Point of view: compression vs transformation**
- "Compression" (what most programmes do): automates tasks without
  redefining roles, cuts headcount, chases efficiency, ignores
  second-order effects.
- "Transformation" (what IOM does): moves decisions into governed
  automation, reallocates work toward judgement and accountability,
  creates new roles with an economic case. The measure of success is not
  how much work is removed but how effectively work is redesigned around
  decisions, governance and people.

**What the IOM is -- three parts**
1. *The method*: analyse work, expose decisions, redesign roles, determine
   where autonomy can be applied safely.
2. *The architecture*: an eight-layer model separating intent, execution,
   governance and state so autonomy is governable, not just automated.
3. *The transformation framework*: a structured path from AI
   experimentation to decision-led operating model.

**Decision bundles (the core unit of design)**
- A job is a bundle of repetitive tasks, judgement tasks, coordination and
  accountability. AI takes the bundle apart and reassembles it:
  1. *Decompose* -- split the job into what is repetitive, what needs
     judgement, what is coordination.
  2. *Reassemble* -- rebuild bundles with AI and people each doing what
     they are best placed to do.
  3. *Hold to account* -- a named role owns the bundle outcome; the control
     plane gates by reversibility and risk.
- Commercial point: value comes from redefining the bundle, with
  quantified outcome shifts a CFO can back.

**Eight-layer governance architecture** (top to bottom)
Human authority (sets intent, owns outcomes) -> Experience surfaces (where
people interact with work) -> Domain model (sector data and rules) ->
Orchestration (routes work and decisions) -> Agents and AI services (do
the work within limits) -> Control plane (gates, evidence, rollback,
audit -- governs, never executes) -> Data foundation (governed context
and events) -> Systems of record (platforms hold the truth).

**The autonomy spectrum -- one spectrum for every decision**
1. *Automated within guardrails* -- agents act; evidence is recorded.
2. *Human review* -- agents propose; people confirm.
3. *Human sign-off required* -- held until a named owner approves.
4. *Human-only authority* -- never delegated, by design.
- Nothing irreversible happens without a named accountable owner;
  evidence, rollback and audit are built in.

**Five-phase transformation** (each answers a board-level question)
01 Process analysis -> 02 Decision design -> 03 Role recreation ->
04 Platform transformation -> 05 Experience design.
Produces: scored work portfolio, decision model with named owners,
redesigned roles, implementation blueprint, experience surfaces.

**Proof & credentials**
- 30+ industry/functional blueprints; claims-management example showing
  process view (Receive-Triage-Assess-Settle) re-expressed as decision
  domains (Claim validity, Coverage, Fraud risk, Settlement value).
- EMEA leadership contacts: Quinton Pienaar (EMEA Customer Transformation
  Leader), Claudia de Gouveia-Macedo (Futures Experience Leader).

### Game relevance
This pack IS the design source for the reframed game:
- The **autonomy spectrum** becomes the core player mechanic: for each of
  the five ship systems, the player places the decision on the spectrum
  (1-4) and sets the guardrail, rather than "fixing a rogue AI".
- The **decision-bundle** logic (decompose/reassemble/hold to account) is
  the scoring logic: choices are scored for internal consistency with the
  player's stated objective and risk appetite, not for a single right answer.
- The **eight-layer architecture** is the metaphor spine: the ship's
  "legacy operating model" vs the IOM the player activates layer by layer.
- The **compression-vs-transformation** framing is exactly the client
  feedback point 1: the game must demonstrate designing a better system of
  work, not correcting a broken AI.
- The **claims decision-domain example** is the template for how each bay
  reframes a process view as a decision view.
