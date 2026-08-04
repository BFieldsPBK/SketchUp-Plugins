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
    # `parent` (an Entities collection), centered at (cx, cy).
    def self.draw(parent, track, cx, cy, materials)
      r_in = track[:inside_radius]
      r_out = r_in + track[:lanes] * track[:lane_width]
      hs = track[:straight] / 2.0

      surface = parent.add_group
      surface.name = "Track Surface"
      donut(surface.entities, cx, cy, hs, r_out, r_in, 0.0)
      Striping.paint(surface, materials[:track])

      lanes = parent.add_group
      lanes.name = "Lane Lines"
      (0..track[:lanes]).each do |k|
        r = r_in + k * track[:lane_width]
        donut(lanes.entities, cx, cy, hs,
              r + LANE_LINE_WIDTH / 2.0, r - LANE_LINE_WIDTH / 2.0,
              Striping::LINE_Z)
      end
      # Finish line: across the lanes at the end of the home straight.
      lanes.entities.add_face(
        [Geom::Point3d.new(cx + hs - LANE_LINE_WIDTH, cy - r_out, Striping::LINE_Z),
         Geom::Point3d.new(cx + hs + LANE_LINE_WIDTH, cy - r_out, Striping::LINE_Z),
         Geom::Point3d.new(cx + hs + LANE_LINE_WIDTH, cy - r_in, Striping::LINE_Z),
         Geom::Point3d.new(cx + hs - LANE_LINE_WIDTH, cy - r_in, Striping::LINE_Z)]
      )
      Striping.paint(lanes, materials[:line])
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
