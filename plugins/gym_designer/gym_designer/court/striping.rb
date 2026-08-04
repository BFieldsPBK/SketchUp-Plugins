# Court striping, drawn as thin painted faces floated 1/32" above the floor.
#
# Real faces (rather than a texture) keep the lines dimensionable and
# doc-grade; the small z-offset avoids z-fighting with the floor without the
# fragility of splitting the floor face. A texture-based mode is a candidate
# later optimization for pure-visualization use.
#
# Both half-courts are drawn by the same code: a point mapper closure turns
# court-local [x, y] pairs into Point3d, mirroring x about mid-court for the
# far end.

module GymDesigner
  module Court
    module Striping
      LINE_Z = 0.03125

      def self.draw(entities, rules, material, opts = {})
        @material = material
        length = rules[:court_length]
        width = rules[:court_width]
        lw = rules[:line_width]
        map = mapper(length, false)

        # Boundary: four stripes meeting at (not overlapping) the corners.
        rect(entities, map, 0, 0, length, lw)
        rect(entities, map, 0, width - lw, length, width)
        rect(entities, map, 0, lw, lw, width - lw)
        rect(entities, map, length - lw, lw, length, width - lw)

        # Center line, and center circle unless the preset omits it.
        rect(entities, map, length / 2.0 - lw / 2.0, lw, length / 2.0 + lw / 2.0, width - lw)
        if rules.fetch(:center_circle, true)
          circle(entities, map, length / 2.0, width / 2.0, rules[:center_circle_radius], lw)
        end

        [false, true].each { |mirror| half_court(entities, rules, mirror, opts) }
      end

      def self.half_court(entities, rules, mirror, opts)
        length = rules[:court_length]
        cy = rules[:court_width] / 2.0
        lw = rules[:line_width]
        map = mapper(length, mirror)
        lane_hw = rules[:lane_width] / 2.0
        lane_end = rules[:lane_length]
        inner = lw # stripes start at the inside edge of the baseline stripe

        # Lane ("key"): two side stripes plus the free-throw line.
        rect(entities, map, inner, cy - lane_hw, lane_end, cy - lane_hw + lw)
        rect(entities, map, inner, cy + lane_hw - lw, lane_end, cy + lane_hw)
        rect(entities, map, lane_end - lw, cy - lane_hw + lw, lane_end, cy + lane_hw - lw)

        # Free-throw circle, centered on the free-throw line, unless the
        # preset omits it. Levels flagged ft_dashed get the rulebook dashed
        # half inside the lane; the court-side half is always solid.
        if rules.fetch(:ft_circle, true)
          ft_cx = lane_end - lw / 2.0
          if rules[:ft_dashed]
            arc_band(entities, map, ft_cx, cy, rules[:ft_circle_radius], lw,
                     -Math::PI / 2.0, Math::PI / 2.0)
            dashed_arc(entities, map, ft_cx, cy, rules[:ft_circle_radius], lw,
                       Math::PI / 2.0, 3.0 * Math::PI / 2.0, 8)
          else
            circle(entities, map, ft_cx, cy, rules[:ft_circle_radius], lw)
          end
        end

        # Backboard and basket, as plan-view visual aids.
        rect(entities, map, rules[:backboard_x] - 1.0, cy - 36.0, rules[:backboard_x] + 1.0, cy + 36.0)
        circle(entities, map, rules[:basket_x], cy, 9.0, 2.0)

        # Restricted-area arc (NBA/NCAA): semicircle under the basket with
        # straight legs back to the backboard plane — same construction as
        # the three-point band with lateral == radius.
        if rules[:restricted_radius]
          pts = Core::Geometry.three_point_band_points(
            basket_x: rules[:basket_x], center_y: cy,
            radius: rules[:restricted_radius], lateral: rules[:restricted_radius],
            line_width: lw, start_x: rules[:backboard_x], segments: 24)
          face(entities, map, pts)
        end

        return unless opts.fetch(:three_point, true)
        pts = Core::Geometry.three_point_band_points(
          basket_x: rules[:basket_x],
          center_y: cy,
          radius: rules[:three_point_radius],
          lateral: rules[:three_point_lateral],
          line_width: lw,
          start_x: inner
        )
        face(entities, map, pts)
      end

      def self.mapper(length, mirror)
        ->(x, y) { Geom::Point3d.new(mirror ? length - x : x, y, LINE_Z) }
      end

      def self.rect(entities, map, x0, y0, x1, y1)
        face(entities, map, [[x0, y0], [x1, y0], [x1, y1], [x0, y1]])
      end

      def self.circle(entities, map, cx, cy, radius, line_width)
        arc_band(entities, map, cx, cy, radius, line_width, 0.0, Math::PI)
        arc_band(entities, map, cx, cy, radius, line_width, Math::PI, 2 * Math::PI)
      end

      def self.arc_band(entities, map, cx, cy, radius, line_width, a0, a1, segments = 32)
        hw = line_width / 2.0
        face(entities, map,
             Core::Geometry.annulus_points(cx, cy, radius + hw, radius - hw, a0, a1, segments))
      end

      # Alternating painted slices: `dashes` dashes with equal gaps between.
      def self.dashed_arc(entities, map, cx, cy, radius, line_width, a0, a1, dashes)
        slices = dashes * 2 - 1
        step = (a1 - a0) / slices
        slices.times do |i|
          next if i.odd?
          arc_band(entities, map, cx, cy, radius, line_width,
                   a0 + i * step, a0 + (i + 1) * step, 4)
        end
      end

      def self.face(entities, map, points)
        pts = Core::Geometry.dedup(points).map { |x, y| map.call(x, y) }
        f = entities.add_face(pts)
        f.material = @material
        f.back_material = @material
        f
      end
    end
  end
end
