# Regulation field and track dimensions, all stored in inches.
#
# Soccer presets follow the US Youth Soccer small-sided standards (U6-U12),
# NFHS (high school), NCAA (college), and the FIFA international pitch
# (105 m x 68 m). Diamond, tennis, and lacrosse presets follow the
# governing bodies noted on each preset, cross-checked against the CDE
# "Guide to School Site Analysis and Development" (2000) school playfield
# diagrams. Where a governing body publishes a range, the value here is
# the commonly recommended size; every dimension can be tweaked in this
# file, and field length/width can be overridden per-run from the dialog.
# As with any basis-of-design data, verify against the current rulebook
# for competition work.
#
# Track data: the 400 m oval is the World Athletics standard track —
# 36.50 m inside-kerb radius, 84.39 m straights, measured 0.30 m out from
# the kerb. The 300 m oval is a common compact configuration for sites
# that cannot fit a full 400 m footprint; there is no single governing
# standard for it, so verify the geometry against site requirements.

module FieldDesigner
  module Rules
    U = Units

    SOCCER = {
      "u6" => {
        label: "U6 Soccer (4v4)",
        length: U.yd(30), width: U.yd(20),
        center_circle_radius: U.yd(3),
        corner_radius: U.yd(1),
        goal_width: U.ft(6), goal_height: U.ft(4)
      },
      "u8" => {
        label: "U8 Soccer (4v4)",
        length: U.yd(35), width: U.yd(25),
        center_circle_radius: U.yd(3),
        corner_radius: U.yd(1),
        goal_width: U.ft(6), goal_height: U.ft(4)
      },
      "u10" => {
        label: "U10 Soccer (7v7)",
        length: U.yd(60), width: U.yd(40),
        center_circle_radius: U.yd(8),
        corner_radius: U.yd(1),
        penalty_area_depth: U.yd(12), penalty_area_width: U.yd(24),
        penalty_mark: U.yd(10),
        # Build-out lines: across the field, halfway between the penalty
        # area line and the halfway line (7v7 only).
        buildout: true,
        goal_width: U.ft(18.5), goal_height: U.ft(6.5)
      },
      "u12" => {
        label: "U12 Soccer (9v9)",
        length: U.yd(75), width: U.yd(50),
        center_circle_radius: U.yd(8),
        corner_radius: U.yd(1),
        penalty_area_depth: U.yd(14), penalty_area_width: U.yd(36),
        penalty_mark: U.yd(10), penalty_arc_radius: U.yd(8),
        goal_width: U.ft(21), goal_height: U.ft(7)
      },
      "hs" => {
        label: "High School Soccer (NFHS)",
        length: U.yd(110), width: U.yd(65),
        center_circle_radius: U.yd(10),
        corner_radius: U.yd(1),
        goal_area_depth: U.yd(6), goal_area_width: U.yd(20),
        penalty_area_depth: U.yd(18), penalty_area_width: U.yd(44),
        penalty_mark: U.yd(12), penalty_arc_radius: U.yd(10),
        goal_width: U.ft(24), goal_height: U.ft(8)
      },
      "ncaa" => {
        label: "College Soccer (NCAA)",
        length: U.yd(115), width: U.yd(75),
        center_circle_radius: U.yd(10),
        corner_radius: U.yd(1),
        goal_area_depth: U.yd(6), goal_area_width: U.yd(20),
        penalty_area_depth: U.yd(18), penalty_area_width: U.yd(44),
        penalty_mark: U.yd(12), penalty_arc_radius: U.yd(10),
        goal_width: U.ft(24), goal_height: U.ft(8)
      },
      "fifa" => {
        label: "Adult Soccer (FIFA International)",
        length: U.m(105), width: U.m(68),
        center_circle_radius: U.m(9.15),
        corner_radius: U.m(1),
        goal_area_depth: U.m(5.5), goal_area_width: U.m(18.32),
        penalty_area_depth: U.m(16.5), penalty_area_width: U.m(40.32),
        penalty_mark: U.m(11), penalty_arc_radius: U.m(9.15),
        goal_width: U.m(7.32), goal_height: U.m(2.44)
      }
    }.freeze

    FOOTBALL = {
      "fb_youth" => {
        label: "Youth Football (80-yard)",
        playing_length: U.yd(80), end_zone: U.yd(10), width: U.yd(40),
        yard_line_interval: U.yd(5)
      },
      "fb_reg" => {
        label: "Football — Regulation (HS/College/Pro)",
        playing_length: U.yd(100), end_zone: U.yd(10), width: U.ft(160),
        yard_line_interval: U.yd(5)
      }
    }.freeze

    # Diamond sports. `bases` is the base-path (diamond side) length;
    # `infield_radius` is the skinned-infield arc measured from the front
    # of the pitching rubber; `behind_home` is the clearance from home
    # plate back to the backstop line (CDE guide: 15' elementary, 60' at
    # the high-school diamond). `fence` (home plate to outfield fence,
    # nil = open playfield) uses the common minimum for each level.
    DIAMOND = {
      "bb_elem" => {
        label: "Baseball — Elementary Playfield",
        # CDE guide Fig. D: 45' diamond on a 180' square with a 165'
        # batting radius and no outfield fence.
        bases: U.ft(45), pitching: U.ft(35),
        behind_home: U.ft(15), infield_radius: U.ft(50),
        fence: nil, surface_radius: U.ft(165)
      },
      "bb_ll" => {
        label: "Baseball — Little League",
        bases: U.ft(60), pitching: U.ft(46),
        behind_home: U.ft(20), infield_radius: U.ft(50),
        fence: U.ft(200), grass_infield: true, mound_radius: U.ft(5)
      },
      "bb_hs" => {
        label: "Baseball — HS/College/Pro (90' bases)",
        bases: U.ft(90), pitching: U.ft(60.5),
        behind_home: U.ft(60), infield_radius: U.ft(95),
        fence: U.ft(330), grass_infield: true, mound_radius: U.ft(9)
      },
      "sb_fp" => {
        label: "Softball — Fastpitch (NFHS/NCAA)",
        bases: U.ft(60), pitching: U.ft(43),
        behind_home: U.ft(25), infield_radius: U.ft(60),
        fence: U.ft(200), pitch_circle_radius: U.ft(8)
      },
      "sb_sp" => {
        label: "Softball — Slow-Pitch (Adult)",
        bases: U.ft(65), pitching: U.ft(50),
        behind_home: U.ft(25), infield_radius: U.ft(65),
        fence: U.ft(275), pitch_circle_radius: U.ft(8)
      }
    }.freeze

    # Men's/boys field lacrosse (NCAA/NFHS): goals 80 yd apart (15 yd off
    # each end line), 9' goal creases, restraining lines 20 yd upfield of
    # each goal line, wing lines 20 yd either side of field center
    # extending 10 yd each side of the midline.
    LACROSSE = {
      "lax" => {
        label: "Lacrosse — Men/Boys (NCAA/NFHS)",
        length: U.yd(110), width: U.yd(60),
        goal_from_end: U.yd(15), restraining_from_goal: U.yd(20),
        crease_radius: U.ft(9), goal_width: U.ft(6),
        wing_from_center: U.yd(20), wing_length: U.yd(20)
      }
    }.freeze

    # Tennis (USTA / CDE guide): 78' x 36' doubles court, 27' singles
    # width, service lines 21' from the net; 21' clear behind baselines,
    # 12' at the sides and between courts in a battery.
    TENNIS = {
      "tennis" => {
        label: "Tennis Court",
        court_length: U.ft(78), court_width: U.ft(36),
        singles_width: U.ft(27), service_dist: U.ft(21),
        end_apron: U.ft(21), side_apron: U.ft(12), court_gap: U.ft(12),
        net_overhang: U.ft(3)
      }
    }.freeze

    TRACKS = {
      "400" => {
        label: "400 m Track (8 lanes)",
        inside_radius: U.m(36.5), straight: U.m(84.39),
        lanes: 8, lane_width: U.m(1.22)
      },
      "300" => {
        label: "300 m Track (6 lanes)",
        # 2 x 67.38 m straights + 2 curves at 26.0 m inside radius
        # (measured 0.30 m out from the inside edge) = 300 m.
        inside_radius: U.m(26.0), straight: U.m(67.38),
        lanes: 6, lane_width: U.m(1.22)
      }
    }.freeze

    # Painted line widths: soccer maxes out at 12 cm (~5"), football
    # uses 4" lines.
    SOCCER_LINE_WIDTH = 5.0
    FOOTBALL_LINE_WIDTH = 4.0

    # Minimum clearance between the field's painted boundary and the
    # track's inside edge when nesting a field in a track infield.
    TRACK_CLEARANCE = U.m(2)

    def self.preset(key)
      SOCCER[key] || FOOTBALL[key] || DIAMOND[key] || LACROSSE[key] || TENNIS[key]
    end

    def self.soccer?(key)
      SOCCER.key?(key)
    end

    def self.diamond?(key)
      DIAMOND.key?(key)
    end

    def self.lacrosse?(key)
      LACROSSE.key?(key)
    end

    def self.tennis?(key)
      TENNIS.key?(key)
    end

    # true when the preset is a rectangular field a running track can wrap.
    def self.trackable?(key)
      SOCCER.key?(key) || FOOTBALL.key?(key) || LACROSSE.key?(key)
    end

    # Overall footprint (length, width) a field needs, including apron.
    def self.field_extent(rules)
      if rules[:playing_length]
        [rules[:playing_length] + 2 * rules[:end_zone], rules[:width]]
      else
        [rules[:length], rules[:width]]
      end
    end

    # true when `track`'s infield can hold a field of length x width with
    # the standard clearance on every side.
    def self.track_fits?(track, length, width)
      infield_l = track[:straight] + 2 * track[:inside_radius]
      infield_w = 2 * track[:inside_radius]
      length + 2 * TRACK_CLEARANCE <= infield_l &&
        width + 2 * TRACK_CLEARANCE <= infield_w
    end

    # Resolve the dialog's track choice against the field size:
    #   "none"        -> nil
    #   "400" / "300" -> that track (caller warns if it does not fit)
    #   "auto"        -> smallest regulation track that fits, else nil
    def self.pick_track(choice, length, width)
      case choice
      when "none" then nil
      when "400", "300" then TRACKS[choice]
      else
        %w[300 400].each do |key|
          return TRACKS[key] if track_fits?(TRACKS[key], length, width)
        end
        nil
      end
    end
  end
end
