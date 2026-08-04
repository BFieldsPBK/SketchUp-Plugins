# Baseball / softball diamond geometry.
#
# Local coordinates put home plate at the origin with the foul lines along
# the +x (right field) and +y (left field) axes, matching the CDE guide
# diagrams; the pitching rubber sits on the diagonal. Surfaces stack with
# small z-offsets: grass at 0, skinned dirt above it, the baseball grass
# infield above the dirt, painted lines on top.

module FieldDesigner
  module Diamond
    DIRT_Z = 0.01
    GRASS_PATCH_Z = 0.02
    LINE_WIDTH = 4.0
    FENCE_HEIGHT = 72.0
    BASE_SIZE = 15.0 # regulation base: 15" square
    SEGMENTS = 48

    def self.build(parent, rules, mats)
      surface_r = rules[:fence] || rules[:surface_radius] ||
                  rules[:infield_radius] + Units.ft(60)

      draw_surface(parent, rules, surface_r + Units.ft(10), mats[:grass])
      draw_dirt(parent, rules, mats[:dirt])
      draw_grass_infield(parent, rules, mats[:grass]) if rules[:grass_infield]
      draw_lines(parent, rules, surface_r, mats[:line])
      draw_fence(parent, rules, mats[:fence]) if rules[:fence]
    end

    # Grass out to `radius` from home, bounded square behind home by the
    # backstop clearance.
    def self.draw_surface(parent, rules, radius, material)
      b = rules[:behind_home]
      x0 = Math.sqrt(radius**2 - b**2)
      a0 = Math.atan2(-b, x0)
      pts = [[-b, -b], [x0, -b]]
      pts += arc_points(0, 0, radius, a0, Math::PI / 2.0 - a0)
      pts << [-b, x0]
      group = parent.add_group
      group.name = "Field Surface"
      face_at(group.entities, pts, 0.0)
      Striping.paint(group, material)
    end

    # Skinned infield: bounded by the foul lines and the arc centered on
    # the pitching rubber.
    def self.draw_dirt(parent, rules, material)
      p = rules[:pitching] / Math.sqrt(2) # rubber at (p, p)
      r = rules[:infield_radius]
      x_int = p + Math.sqrt(r**2 - p**2)
      a0 = Math.atan2(-p, x_int - p)
      a1 = Math.atan2(x_int - p, -p)
      pts = [[0, 0], [x_int, 0]]
      pts += arc_points(p, p, r, a0, a1)
      pts << [0, x_int]
      group = parent.add_group
      group.name = "Skinned Infield"
      face_at(group.entities, pts, DIRT_Z)
      # Pitcher's mound (baseball) as a dirt disc; on skinned softball
      # infields the circle is painted instead (see draw_lines).
      if rules[:mound_radius] && rules[:grass_infield]
        disc_at(group.entities, p, p, rules[:mound_radius], GRASS_PATCH_Z + 0.005)
      end
      # Home plate dirt circle, 13' radius per the pro/HS layout.
      if rules[:grass_infield]
        disc_at(group.entities, 0, 0, Units.ft(13), GRASS_PATCH_Z + 0.005)
      end
      Striping.paint(group, material)
    end

    # Baseball's grass infield: the base diamond inset from the base lines
    # so a dirt path reads around it.
    def self.draw_grass_infield(parent, rules, material)
      bases = rules[:bases]
      inset = Units.ft(6)
      pts = [[inset, inset], [bases - inset, inset],
             [bases - inset, bases - inset], [inset, bases - inset]]
      group = parent.add_group
      group.name = "Infield Grass"
      face_at(group.entities, pts, GRASS_PATCH_Z)
      Striping.paint(group, material)
    end

    def self.draw_lines(parent, rules, surface_r, material)
      group = parent.add_group
      group.name = "Field Markings"
      e = group.entities
      lw = LINE_WIDTH
      z = Striping::LINE_Z
      bases = rules[:bases]
      p = rules[:pitching] / Math.sqrt(2)

      # Foul lines from home to the fence / edge of surface, in fair
      # territory (inside each axis).
      face_at(e, [[0, 0], [surface_r, 0], [surface_r, lw], [0, lw]], z)
      face_at(e, [[0, 0], [lw, 0], [lw, surface_r], [0, surface_r]], z)

      # Bases at 1st, 2nd, 3rd; home plate as a disc; pitching rubber.
      h = BASE_SIZE / 2.0
      [[bases, 0], [bases, bases], [0, bases]].each do |cx, cy|
        face_at(e, [[cx - h, cy - h], [cx + h, cy - h],
                    [cx + h, cy + h], [cx - h, cy + h]], z)
      end
      disc_at(e, 0, 0, 12.0, z)
      face_at(e, [[p - 12, p - 3], [p + 12, p - 3],
                  [p + 12, p + 3], [p - 12, p + 3]], z)

      # Softball's painted pitcher's circle.
      if rules[:pitch_circle_radius]
        r = rules[:pitch_circle_radius]
        ring_at(e, p, p, r, lw, z)
      end
      Striping.paint(group, material)
    end

    # Outfield fence: a vertical ribbon along the fence arc between the
    # foul lines.
    def self.draw_fence(parent, rules, material)
      group = parent.add_group
      group.name = "Outfield Fence"
      pts = arc_points(0, 0, rules[:fence], 0.0, Math::PI / 2.0, SEGMENTS)
      pts.each_cons(2) do |(x0, y0), (x1, y1)|
        group.entities.add_face(
          [Geom::Point3d.new(x0, y0, 0), Geom::Point3d.new(x1, y1, 0),
           Geom::Point3d.new(x1, y1, FENCE_HEIGHT),
           Geom::Point3d.new(x0, y0, FENCE_HEIGHT)]
        )
      end
      Striping.paint(group, material)
    end

    # --- small helpers -----------------------------------------------------

    def self.arc_points(cx, cy, r, a0, a1, segments = SEGMENTS)
      (0..segments).map do |i|
        a = a0 + (a1 - a0) * i / segments
        [cx + r * Math.cos(a), cy + r * Math.sin(a)]
      end
    end

    def self.face_at(entities, pts, z)
      pts = Striping.dedup(pts)
      entities.add_face(pts.map { |x, y| Geom::Point3d.new(x, y, z) })
    end

    def self.disc_at(entities, cx, cy, r, z, segments = 24)
      pts = (0...segments).map do |i|
        a = 2 * Math::PI * i / segments
        [cx + r * Math.cos(a), cy + r * Math.sin(a)]
      end
      face_at(entities, pts, z)
    end

    def self.ring_at(entities, cx, cy, r, width, z)
      [[0.0, Math::PI], [Math::PI, 2 * Math::PI]].each do |a0, a1|
        pts = Striping.annulus_points(cx, cy, r + width / 2.0,
                                      r - width / 2.0, a0, a1, 32)
        face_at(entities, pts, z)
      end
    end
  end
end
