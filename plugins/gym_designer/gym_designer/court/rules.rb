# Per-age-group court dimension tables.
#
# NBA/College, High School, and Junior High sizes follow the Sports Venue
# Calculator gymnasium-flooring guide (sportsvenuecalculator.com/knowledge/
# gymnasium-flooring/basketball-court-dimensions/): 94x50, 84x50, and 74x42
# respectively. It also recommends 3-10 ft of safety clearance around the
# court, which is what the margin defaults reflect. Elementary follows the
# project's basis-of-design plan (GYM 800) instead — see its entry.
#
# Striping values (three-point, lane, circles) remain STARTING VALUES —
# verify against the current NFHS / NCAA / FIBA / NBA rulebooks. Everything
# is overridable from the dialog.

module GymDesigner
  module Court
    module Rules
      F = Units::FEET

      # corner_offset = distance of the three-point line's straight segment
      # from the sideline. 5'3" makes the arc a full semicircle ending level
      # with the basket (the NFHS construction).
      TABLES = {
        "nba" => {
          label: "NBA",
          court_length: 94 * F,
          court_width: 50 * F,
          three_point_radius: 23.75 * F,       # 23'9" at the top of the arc
          corner_offset: 3.0 * F,              # line 3'0" from sideline in the corner
          lane_width: 16 * F,
          restricted_radius: 4 * F,            # restricted-area arc — VERIFY
          ft_dashed: true,                     # lower FT half dashed
          note: nil
        },
        "college" => {
          label: "College (NCAA)",
          court_length: 94 * F,
          court_width: 50 * F,
          three_point_radius: 22 * F + 1.75,   # 22'1-3/4"
          corner_offset: 3.34 * F,             # ~40" from sideline — VERIFY
          lane_width: 12 * F,
          restricted_radius: 4 * F,            # restricted-area arc — VERIFY
          ft_dashed: true,                     # lower FT half dashed
          note: nil
        },
        "high_school" => {
          label: "High School (NFHS)",
          court_length: 84 * F,
          court_width: 50 * F,
          three_point_radius: 19.75 * F,       # 19'9"
          corner_offset: 5.25 * F,             # pure semicircle construction
          lane_width: 12 * F,
          note: nil
        },
        "junior_high" => {
          label: "Junior High",
          court_length: 74 * F,
          court_width: 42 * F,
          three_point_radius: 19.75 * F,
          corner_offset: 5.25 * F,
          lane_width: 12 * F,
          note: "Junior high / middle school: 74 x 42 ft per the Sports " \
                "Venue Calculator guide. Some districts play on high-school " \
                "floors — override if yours does."
        },
        "elementary" => {
          label: "Elementary",
          court_length: 53 * F + 10.5,     # 53'-10 1/2" per basis-of-design plan
          court_width: 43 * F + 4.0,       # 43'-4"
          three_point_radius: (43 * F + 4.0) / 2.0, # arc scaled from plan: ~half court width
          corner_offset: 2.0,              # arc runs essentially to the sidelines
          lane_width: 12 * F,
          center_circle: false,            # plan shows no center circle
          ft_circle: false,                # plan shows plain keys, no FT circles
          note: "Basis of design: elementary gym plan (GYM 800), court " \
                "53'-10 1/2\" x 43'-4\". The three-point arc is scaled from " \
                "the plan (radius ~half the court width, tangent to the " \
                "sidelines); center and free-throw circles are omitted to " \
                "match. Override any value as needed."
        }
      }.freeze

      # Shared at every level. Free-throw line is 15' from the backboard face,
      # which sits 4' inside the baseline, so the lane runs 19' deep.
      COMMON = {
        line_width: 2.0,
        backboard_x: 4 * F,        # backboard face, from baseline
        basket_x: 5.25 * F,        # basket center, 5'3" from baseline
        lane_length: 19 * F,       # baseline to far edge of the free-throw line
        ft_circle_radius: 6 * F,
        center_circle_radius: 6 * F
      }.freeze

      OVERRIDABLE = %i[court_length court_width three_point_radius corner_offset lane_width].freeze

      def self.age_groups
        TABLES.keys
      end

      # Merge the level's table over the shared values, then apply any
      # positive user overrides (nil / blank overrides are ignored).
      def self.resolve(age_group, overrides = {})
        base = TABLES[age_group]
        raise ArgumentError, "Unknown age group: #{age_group.inspect}" unless base
        rules = COMMON.merge(base)
        OVERRIDABLE.each do |key|
          value = overrides[key]
          rules[key] = value if value && value > 0
        end
        rules[:three_point_lateral] = rules[:court_width] / 2.0 - rules[:corner_offset]
        rules
      end
    end
  end
end
