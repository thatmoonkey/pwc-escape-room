## One-time floor sweep for the text-size rule: nothing in the game renders
## below the Brand reading floor (30px). Clamps raw font-size hardcodes in
## scripts and theme_override entries in scene files. Helper functions that
## scale fonts are clamped separately in their own files.
import re
import pathlib

FLOOR = 30

# 1) Raw integer overrides: add_theme_font_size_override("font_size", N)
RAW = re.compile(r'(add_theme_font_size_override\("font_size",\s*)(\d+)(\))')

# 2) hud.gd style: int(17.0 * scale)  -> the multiplier base, clamped too
SCALED = re.compile(r'(int\()(\d+)(\.0\s*\*\s*scale\s*\))')

# 3) Scene overrides: theme_override_font_sizes/font_size = N
TSCN = re.compile(r'(theme_override_font_sizes/font_size\s*=\s*)(\d+)')


def clamp(m: re.Match) -> str:
	return m.group(1) + str(max(int(m.group(2)), FLOOR)) + m.group(3)


def clamp_mid(m: re.Match) -> str:
	## SCALED matches have a trailing group; TSCN matches do not.
	tail = m.group(3) if (m.lastindex and m.lastindex >= 3) else ""
	return m.group(1) + str(max(int(m.group(2)), FLOOR)) + tail


changed = []
skipped = []
for pattern in ("scripts/**/*.gd", "scenes/**/*.tscn"):
	for path in pathlib.Path(".").glob(pattern):
		try:
			text = path.read_text()
		except UnicodeDecodeError as err:
			skipped.append(f"{path} ({err.reason})")
			continue
		new = RAW.sub(clamp, text)
		new = SCALED.sub(clamp_mid, new)
		new = TSCN.sub(clamp_mid, new)
		if new != text:
			path.write_text(new)
			changed.append(str(path))

print(f"{len(changed)} files changed:")
for path in sorted(changed):
	print(" ", path)
if skipped:
	print(f"{len(skipped)} files skipped (undecodable, check manually):")
	for path in sorted(skipped):
		print(" ", path)
