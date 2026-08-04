# Running track geometry: a stadium oval (two straights + two semicircular
# curves) wrapped around the field, centered on the field's center.
#
# The track band and each lane line are "donut" faces: an outer loop face
# with the inner loop punched out. Each donut lives in its own group so the
# punch-out never interacts with neighboring coplanar faces, and the group
# material paints whatever faces remain after the punch.

module FieldDesigner
  module Track
    LANE_LINE_WIDTH = 2.0 # inches (~5 cm)

    # Build the whole track (surface, lane lines, finish line) into
    # `parent` (an Entities collection), centered at (cx, cy). With
    # opts[:runoff] (default true) the home straight extends beyond the
    # oval on both ends — sprint start area on the left, deceleration
    # run-off past the finish on the right.
    def self.draw(parent, track, cx, cy, materials, opts = {})
      r_in = track[:inside_radius]
      r_out = r_in + track[:lanes] * track[:lane_width]
      hs = track[:straight] / 2.0
      runoff = opts.fetch(:runoff, true)
      e_start = runoff ? track[:sprint_start] || 0 : 0
      e_stop = runoff ? track[:sprint_runoff] || 0 : 0

      surface = parent.add_group
      surface.name = "Track Surface"
      outer = surface_outline(cx, cy, hs, r_out, r_in, e_start, e_stop)
      out_face = surface.entities.add_face(outer)
      out_face.reverse! if out_face.normal.z < 0
      inner = surface.entities.add_face(loop_points(cx, cy, hs, r_in, 0.0))
      inner.erase!
      Striping.paint(surface, materials[:track])

      lanes = parent.add_group
      lanes.name = "Lane Lines"
      (0..track[:lanes]).each do |k|
        r = r_in + k * track[:lane_width]
        donut(lanes.entities, cx, cy, hs,
              r + LANE_LINE_WIDTH / 2.0, r - LANE_LINE_WIDTH / 2.0,
              Striping::LINE_Z)
        next unless e_start > 0 || e_stop > 0
        # Straight sprint-lane lines continue through the extensions.
        y = cy - r
        hw = LANE_LINE_WIDTH / 2.0
        if e_start > 0
          lane_rect(lanes.entities, cx - hs - e_start, cx - hs, y - hw, y + hw)
        end
        if e_stop > 0
          lane_rect(lanes.entities, cx + hs, cx + hs + e_stop, y - hw, y + hw)
        end
      end
      # Finish line: across the lanes at the end of the home straight,
      # where it meets the first curve.
      lane_rect(lanes.entities, cx + hs - LANE_LINE_WIDTH,
                cx + hs + LANE_LINE_WIDTH, cy - r_out, cy - r_in)
      Striping.paint(lanes, materials[:line])
    end

    def self.lane_rect(entities, x0, x1, y0, y1)
      z = Striping::LINE_Z
      entities.add_face(
        [Geom::Point3d.new(x0, y0, z), Geom::Point3d.new(x1, y0, z),
         Geom::Point3d.new(x1, y1, z), Geom::Point3d.new(x0, y1, z)]
      )
    end

    # Outer boundary of the track surface: the stadium oval unioned with
    # the two sprint-extension rectangles along the home straight
    # (bottom). Traced counterclockwise from the bottom-left corner.
    def self.surface_outline(cx, cy, hs, r_out, r_in, e_start, e_stop, z = 0.0)
      pts = []
      pts << [cx - hs - e_start, cy - r_out]
      pts << [cx + hs + e_stop, cy - r_out]
      pts += end_boundary(cx + hs, cy, r_out, r_in, e_stop, false)
      pts += end_boundary(cx - hs, cy, r_out, r_in, e_start, true)
      Striping.dedup(pts).map { |x, y| Geom::Point3d.new(x, y, z) }
    end

    # Boundary of one end, from the extension's outer corner up and around
    # the curve's outer arc to the top of the oval. Two cases: a short
    # extension's edge meets the outer circle directly; a long one runs
    # along the inside lane edge (y = cy - r_in) until it does.
    def self.end_boundary(ccx, cy, r_out, r_in, e, left)
      limit = Math.sqrt(r_out**2 - r_in**2)
      sign = left ? -1 : 1
      junction = []
      if e < limit
        y_meet = Math.sqrt(r_out**2 - e**2)
        a0 = Math.atan2(-y_meet, e)
        junction << [ccx + sign * e, cy - y_meet]
      else
        a0 = Math.atan2(-r_in, limit)
        junction << [ccx + sign * e, cy - r_in]
        junction << [ccx + sign * limit, cy - r_in]
      end
      segments = 32
      if left
        arc = (0..segments).map do |i|
          a = Math::PI / 2.0 + (Math::PI / 2.0 - a0) * i / segments
          [ccx + r_out * Math.cos(a), cy + r_out * Math.sin(a)]
        end
        arc + junction.reverse
      else
        arc = (0..segments).map do |i|
          a = a0 + (Math::PI / 2.0 - a0) * i / segments
          [ccx + r_out * Math.cos(a), cy + r_out * Math.sin(a)]
        end
        junction + arc
      end
    end

    # The grass infield enclosed by the track's inside edge, as a single
    # stadium-shaped face.
    def self.draw_infield(parent, track, cx, cy, material)
      infield = parent.add_group
      infield.name = "Infield"
      hs = track[:straight] / 2.0
      infield.entities.add_face(loop_points(cx, cy, hs, track[:inside_radius], 0.0))
      Striping.paint(infield, material)
      infield
    end

    def self.donut(entities, cx, cy, half_straight, r_out, r_in, z)
      outer = entities.add_face(loop_points(cx, cy, half_straight, r_out, z))
      outer.reverse! if outer.normal.z < 0
      inner = entities.add_face(loop_points(cx, cy, half_straight, r_in, z))
      inner.erase!
    end

    # Stadium loop: right semicircle, then left semicircle; add_face closes
    # the bottom straight back to the start point.
    def self.loop_points(cx, cy, half_straight, r, z, segments = 48)
      pts = []
      (0..segments).each do |i|
        a = -Math::PI / 2.0 + Math::PI * i / segments
        pts << Geom::Point3d.new(cx + half_straight + r * Math.cos(a),
                                 cy + r * Math.sin(a), z)
      end
      (0..segments).each do |i|
        a = Math::PI / 2.0 + Math::PI * i / segments
        pts << Geom::Point3d.new(cx - half_straight + r * Math.cos(a),
                                 cy + r * Math.sin(a), z)
      end
      pts
    end
  end
end
