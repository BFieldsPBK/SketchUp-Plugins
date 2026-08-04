# 2D construction helpers shared by the striping code. Everything works on
# plain [x, y] pairs in court-local inches; callers map pairs to Point3d
# (applying any mirroring and the stripe z-offset) when adding faces.

module GymDesigner
  module Core
    module Geometry
      def self.arc_points(cx, cy, radius, a0, a1, segments = 48)
        pts = []
        (0..segments).each do |i|
          a = a0 + (a1 - a0) * i / segments.to_f
          pts << [cx + radius * Math.cos(a), cy + radius * Math.sin(a)]
        end
        pts
      end

      # Half of an annular ring (a circular stripe). Full rings are built from
      # two halves so each face is a simple, non-self-touching polygon.
      def self.annulus_points(cx, cy, r_out, r_in, a0, a1, segments = 32)
        arc_points(cx, cy, r_out, a0, a1, segments) +
          arc_points(cx, cy, r_in, a1, a0, segments)
      end

      # One edge of the three-point line: a straight run from the baseline
      # parallel to the sideline, then the arc around the basket. `lateral` is
      # the straight segment's distance from the court centerline; when it
      # equals the radius (high school) the straight run ends level with the
      # basket and the arc is a full semicircle.
      def self.three_point_edge(basket_x, center_y, radius, lateral, start_x, segments)
        lateral = [lateral, radius].min
        phi = Math.asin(lateral / radius)
        pts = [[start_x, center_y + lateral]]
        pts.concat(arc_points(basket_x, center_y, radius, phi, -phi, segments))
        pts << [start_x, center_y - lateral]
        pts
      end

      # Closed polygon for the three-point stripe: the outer edge traced
      # baseline-to-baseline, then the inner edge back. `lateral` and `radius`
      # describe the stripe centerline; the band is line_width wide.
      def self.three_point_band_points(basket_x:, center_y:, radius:, lateral:,
                                       line_width:, start_x: 0.0, segments: 60)
        hw = line_width / 2.0
        outer = three_point_edge(basket_x, center_y, radius + hw, lateral + hw, start_x, segments)
        inner = three_point_edge(basket_x, center_y, radius - hw, lateral - hw, start_x, segments)
        outer + inner.reverse
      end

      # Drop consecutive points closer than tol so add_face never sees a
      # duplicate vertex (arc endpoints coincide with straight-run endpoints).
      def self.dedup(points, tol = 0.001)
        result = []
        points.each do |pt|
          prev = result.last
          result << pt unless prev && (pt[0] - prev[0]).abs < tol && (pt[1] - prev[1]).abs < tol
        end
        first = result.first
        last = result.last
        if result.size > 2 && (first[0] - last[0]).abs < tol && (first[1] - last[1]).abs < tol
          result.pop
        end
        result
      end
    end
  end
end
