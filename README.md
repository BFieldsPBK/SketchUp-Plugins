# SketchUp Plugins

The office's SketchUp extension suite. Every tool registers its buttons on
one shared **PBK Tech Tools** toolbar (and a matching submenu under
`Extensions > PBK Tech Tools`), so everything stays gathered in one place.

## Plugins

| Plugin | What it does |
| --- | --- |
| `pbk_tech_tools` | The shared toolbar/menu hub. No commands of its own — it hosts every other plugin's buttons. |
| `gym_designer` | Striped basketball courts by age group, plus code-informed parametric bleachers sized to a target capacity. |
| `bsf_program_translator` | Turns a program spreadsheet (CSV) into color-coded, labeled room blocks grouped by department, and exports programmed-vs-modeled comparisons. |
| `field_designer` | Regulation athletic fields for site design: soccer, football, lacrosse, baseball/softball diamonds, and tennis courts, with optional regulation running tracks. |

Each plugin also works standalone: if `pbk_tech_tools` isn't installed, it
falls back to its own toolbar, exactly as before.

### Field Designer

One **Field Generator** button opens a dialog with:

- **Soccer** — U6 and U8 (4v4), U10 (7v7, with build-out lines), U12
  (9v9), High School (NFHS 110×65 yd), College (NCAA 115×75 yd), and
  Adult (FIFA international 105×68 m). Markings scale with the preset:
  center circle, penalty/goal areas, penalty marks and arcs, corner arcs,
  and plan-view goal symbols.
- **Football** — Youth (80-yard field) and Regulation (HS/College/Pro,
  100 yd + two 10 yd end zones × 160 ft), with yard lines every 5 yards.
- **Lacrosse** — Men/Boys (NCAA/NFHS 110×60 yd): goal creases,
  restraining lines, wing lines, midline and center X.
- **Baseball / Softball** — Elementary playfield diamond (45' bases,
  165' batting radius per the CDE school-site guide), Little League
  (60' bases, 200' fence), HS/College/Pro (90' bases, 330' fence,
  60' backstop clearance), NFHS/NCAA fastpitch softball (60' bases,
  43' pitching, 200' fence), and adult slow-pitch (65' bases, 275'
  fence). Diamonds build grass, skinned dirt infield, baseball grass
  infield and mound, foul lines, bases, pitcher's circle (softball),
  and a 6' outfield fence ribbon.
- **Tennis** — USTA 78×36 ft doubles court with singles lines, service
  boxes, center marks, two-tone playing surface and net band; generate
  a battery of 1–8 courts with the standard 12' spacing and 21'/12'
  clearances.
- **Track wrap** (rectangular fields) — None, 400 m (8 lanes, World
  Athletics standard: 36.50 m kerb radius, 84.39 m straights), 300 m
  (6 lanes, compact configuration), or **Auto**, which picks the smallest
  regulation track whose infield holds the field with 2 m of clearance —
  300 m for small-sided fields, 400 m for full-size soccer, football,
  and lacrosse.
- **Overrides** — soccer length/width within a governing body's legal
  range, tennis battery count, and the apron margin used when no track
  is drawn.

Output is one named group per run (surface, markings, track, fence as
subgroups), fully undoable in one step. Striping is drawn as thin painted
faces floated 1/32" above the surface, so lines stay dimensionable.

Dimension tables live in `field_designer/rules.rb` with sources noted —
US Youth Soccer, NFHS, NCAA, FIFA, Little League, USA Softball, USTA,
World Athletics, and the California DOE *Guide to School Site Analysis
and Development* (2000). Verify against current rulebooks for
competition work.

## Installing

Build the installers, then use `Extension Manager > Install Extension` in
SketchUp for each `.rbz` (install `pbk_tech_tools` plus whichever tools
you want):

```
python3 tools/package.py        # writes dist/<plugin>.rbz for every plugin
```

## Developing

- Each plugin lives in `plugins/<name>/`: a registrar `<name>.rb` at the
  top (what SketchUp's Extension Manager sees) plus a `<name>/` support
  folder with the real code.
- For a fast loop, symlink (or copy) a plugin's contents into your
  SketchUp Plugins folder; `gym_designer` and `field_designer` have a
  `Reload (dev)` menu item that re-loads their files without restarting
  SketchUp.
- New plugins join the shared toolbar by requiring `pbk_tech_tools/registry`
  and calling `PBK::TechTools::Registry.add_commands("My Tool", commands)` —
  see `field_designer/main.rb` for the pattern, including the standalone
  fallback.
- Toolbar icons are generated placeholders: `python3 tools/gen_icons.py`
  regenerates them; swap in real artwork by replacing the PNGs.

## Roadmap ideas

- Field Designer: hash marks / yard numbers for football, lane stagger
  markings and D-zones for the track, 3D goals and goal posts, backstops
  and dugouts for diamonds, batter's boxes, women's lacrosse (120×70 yd
  with 8 m / 12 m arcs), field hockey.
- Suite: an "About / versions" dialog listing installed office tools.
