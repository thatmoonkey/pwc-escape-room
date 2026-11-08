MOBILE DECISION SHELL - LOCAL TEST BUILD
=========================================

Extract this zip over your repo root. Paths are repo-relative; every file
lands where it belongs. Nothing has been committed anywhere - this is the
local working version for your review.

WHAT CHANGES
------------
New file:
  scripts/ui/mobile_decision_ui.gd   the phone-landscape decision shell

Changed files:
  scripts/terminal/terminal_ui.gd    delegates decision bays on touch devices
  scripts/puzzles/puzzle.gd          new info_tabs() contract (default: none)
  scripts/puzzles/nav_puzzle.gd      info_tabs() override
  scripts/puzzles/life_support_puzzle.gd
  scripts/puzzles/comms_puzzle.gd
  scripts/puzzles/cargo_puzzle.gd
  scripts/puzzles/engineering_puzzle.gd
  docs/adding-a-system.md            documents the shell + info_tabs()

Asset (binary - was never pushed; this is the only copy):
  assets/ui/decision_backdrop.webp   blurred cockpit backdrop, 1600x893, 11 KB

HOW IT WORKS
------------
TerminalUI owns the shell and creates it in _ready(), so no scene files
change and every entry point (console interactables, game.gd, dev probes)
keeps talking to the one TerminalUI in the "terminal_ui" group.

Delegation rule: touch device + decision bay -> the shell renders ALL of
that bay's states (decision AND the read-back after placing), so a bay never
switches layout mid-conversation. Hub, log and helm consoles, and desktop
and VR, keep the existing printout untouched.

The shell: blurred backdrop (falls back to the scrim alone with a
push_warning if the webp is missing), 66/33 split, tabs OVERVIEW /
SHIPMIND / LOGS / SUMMARY on the left, the four level chips + commit on the
right. The decision column is greyed (0.45) and disabled until every tab
has been read; the slot reports "N OF M TABS READ". No scroll anywhere.
The LEAVE button in the header replaces the desktop ESC/close path on touch.

WHAT TO TEST
------------
1. Desktop run (F5): consoles behave exactly as before. Nothing changes.
2. Touch run (Project Settings -> Input Devices -> emulate touch, or a
   phone over your LAN): open a bay console. Expect the tab screen,
   greyed decision, gate opening as you read each tab, then the four
   chips lighting and the commit enabling.
3. Place a level: the read-back renders in the same shell (no layout jump).
4. Re-open a decided console: record read-back in the shell.
5. LEAVE closes the console from every state.

KNOWN CAVEATS
-------------
- The cargo LOGS tab carries the longest evidence list and is the binding
  fit constraint for the no-scroll rule at the 648 px design height. If it
  overflows on your test device, that tab's content needs a trim - flag it
  and we shorten the text, not the rule.
- The shell renders only decision bays. If you want hub/log/helm on mobile
  in this layout later, that is a separate pass.
- The webp must sit at assets/ui/decision_backdrop.webp. If it is absent
  the shell still runs (scrim + warning in the output log).
