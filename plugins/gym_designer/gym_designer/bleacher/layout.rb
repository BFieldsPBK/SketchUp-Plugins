# Pure layout math: parameters in, seating plan out. No SketchUp API calls,
# so this is the one bleacher module that can be exercised in plain Ruby.
#
#   seats_per_row = (available_length - aisles * aisle_width) / seat_width
#   rows_needed   = ceil(bench_target / seats_per_row)
#
# Aisle count and seats-per-row are interdependent (aisles consume seating
# length, fewer seats may need fewer aisles), so the loop iterates to a
# fixed point — it converges because the aisle count only ever increases.

module GymDesigner
  module Bleacher
    module Layout
      def self.plan(p)
        warnings = []
        capacity = p[:capacity]
        avail = p[:available_length]

        wc = p[:wc_override] || Rules.wheelchair_spaces(capacity)
        companions = wc
        bench_target = [capacity - wc - companions, 0].max

        aisles = 0
        seats_per_row = 0
        loop do
          net = avail - aisles * p[:aisle_width]
          seats_per_row = (net / p[:seat_width]).floor
          if seats_per_row < 1
            return { error: "Available length (#{Units.fmt(avail)}) is too short " \
                            "for a row of seats plus the required aisles." }
          end
          needed = [(seats_per_row.to_f / p[:max_seats_between_aisles]).ceil - 1, 0].max
          break if needed <= aisles
          aisles = needed
        end

        rows = [(bench_target.to_f / seats_per_row).ceil, 1].max
        if rows > p[:max_rows]
          rows = p[:max_rows]
          warnings << "Hit the #{p[:max_rows]}-row cap before reaching the target " \
                      "capacity. Increase available length, rows, or split into " \
                      "multiple banks."
        end

        bench_capacity = rows * seats_per_row
        total = bench_capacity + wc + companions
        if total < capacity
          warnings << "Total capacity #{total} falls short of the #{capacity} target."
        end

        # Distribute the row into aisle-separated segments as evenly as possible.
        segment_count = aisles + 1
        base = seats_per_row / segment_count
        extra = seats_per_row % segment_count
        segments = Array.new(segment_count) { |i| base + (i < extra ? 1 : 0) }

        wc_setback = wc > 0 ? p[:wc_space_depth] : 0.0
        used_length = seats_per_row * p[:seat_width] + aisles * p[:aisle_width]
        height = rows * p[:row_rise]

        # x of each aisle's left edge, measured from the bank's start.
        aisle_positions = []
        x = 0.0
        segments.each_with_index do |count, i|
          x += count * p[:seat_width]
          next if i == segments.size - 1
          aisle_positions << x
          x += p[:aisle_width]
        end

        {
          aisles: aisles,
          seats_per_row: seats_per_row,
          segments: segments,
          aisle_positions: aisle_positions,
          rows: rows,
          bench_capacity: bench_capacity,
          wc_spaces: wc,
          companions: companions,
          total_capacity: total,
          used_length: used_length,
          wc_setback: wc_setback,
          depth: wc_setback + rows * p[:row_run],
          height: height,
          guardrail: height > p[:guardrail_trigger],
          warnings: warnings
        }
      end
    end
  end
end
