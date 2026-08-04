# Bleacher rule-set: the code-derived assumptions that drive the layout.
#
# STARTING VALUES, not a code sign-off. Every value here is surfaced as an
# editable field in the dialog and echoed in the generation summary, so a
# licensed architect can see exactly what drove the layout and verify it
# against the governing editions of ICC 300, the IBC, and ICC A117.1 / ADA.

module GymDesigner
  module Bleacher
    module Rules
      DEFAULTS = {
        seat_width: 18.0,              # in per person on bench seating — VERIFY ICC 300
        row_rise: 8.0,                 # in rise row-to-row — VERIFY ICC 300 riser limits
        row_run: 24.0,                 # in depth row-to-row — VERIFY ICC 300 row spacing
        seat_depth: 10.0,              # in, seat board depth (product dimension)
        seat_board_height: 16.0,       # in, seat top above its footboard (product dimension)
        aisle_width: 48.0,             # in — VERIFY ICC 300 / IBC 1029 aisle sizing
        max_seats_between_aisles: 20,  # seats to the nearest aisle — VERIFY ICC 300
        max_rows: 24,                  # practical cap; egress limits may bind sooner
        guardrail_trigger: 30.0,       # in — guards required above this drop (IBC 1015) — VERIFY
        guardrail_height: 42.0,        # in — VERIFY
        wc_space_width: 36.0,          # in — wheelchair space, ICC A117.1 / ADA — VERIFY
        wc_space_depth: 60.0,          # in
        companion_seat_width: 18.0     # in, one companion seat beside each wheelchair space
      }.freeze

      # Wheelchair spaces for assembly seating, IBC Table 1108.2.2.1
      # (starting values — VERIFY against the governing edition).
      def self.wheelchair_spaces(capacity)
        return 0 if capacity < 4
        return 1 if capacity <= 25
        return 2 if capacity <= 50
        return 4 if capacity <= 150
        return 5 if capacity <= 300
        return 6 if capacity <= 500
        return 6 + ((capacity - 500) / 150.0).ceil if capacity <= 5000
        36 + ((capacity - 5000) / 200.0).ceil
      end

      # Human-readable list of the assumptions in force, for the summary.
      def self.assumptions(p)
        [
          "Seat width #{p[:seat_width]}\" per person (ICC 300)",
          "Row rise #{p[:row_rise]}\", row depth #{p[:row_run]}\" (ICC 300)",
          "Aisles #{p[:aisle_width]}\" wide, max #{p[:max_seats_between_aisles]} seats " \
            "between aisles (ICC 300 / IBC 1029)",
          "Wheelchair spaces per IBC Table 1108.2.2.1, one companion seat each " \
            "(ICC A117.1 / ADA), placed at grade in the front row",
          "Guardrails #{p[:guardrail_height]}\" high where the top row exceeds " \
            "#{p[:guardrail_trigger]}\" (IBC 1015)",
          "Aisle stairs (half-risers) and 36\" center handrails modeled — verify " \
            "tread/riser and handrail extensions against ICC 300",
          "Cross-aisles and egress capacity are NOT modeled"
        ]
      end
    end
  end
end
