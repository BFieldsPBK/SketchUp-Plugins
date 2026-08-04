# Field striping, drawn as thin painted faces floated 1/32" above the
# playing surface — the same doc-grade approach as the office court tool:
# real faces stay dimensionable, and the small z-offset avoids z-fighting
# without splitting the surface face.
#
# Faces are added unpainted into a group whose material is set by the
# caller; SketchUp renders unpainted faces with their group's material, so
# no face-level painting (or tracking of faces through splits) is needed.
#
# Both ends of a field are drawn by the same code: a point mapper closure
# turns field-local [x, y] pairs into Point3d, mirroring x about midfield
# for the far end.

module FieldDesigner
  module Striping
    LINE_Z = 0.03125

    # --- generic helpers ---------------------------------------------------

    # Paint every face in `group` on both sides (donut punch-outs and
    # mirrored ends can leave faces flipped either way), plus the group
    # itself so later faces inherit sensibly.
    def self.paint(group, material)
      group.entities.grep(Sketchup::Face).each do |f|
        f.material = material
        f.back_material = material
      end
      group.material = material
    end

    def self.mapper(length, mirror, z = LINE_Z)
      ->(x, y) { Geom::Point3d.new(mirror ? length - x : x, y, z) }
    end

    def self.face(entities, map, points)
      pts = dedup(points).map { |x, y| map.call(x, y) }
      entities.add_face(pts)
    end

    def self.rect(entities, map, x0, y0, x1, y1)
      face(entities, map, [[x0, y0], [x1, y0], [x1, y1], [x0, y1]])
    end

    def self.circle(entities, map, cx, cy, radius, line_width)
      arc_band(entities, map, cx, cy, radius, line_width, 0.0, Math::PI)
      arc_band(entities, map, cx, cy, radius, line_width, Math::PI, 2 * Math::PI)
    end

    def self.disc(entities, map, cx, cy, radius, segments = 24)
      pts = (0...segments).map do |i|
        a = 2 * Math::PI * i / segments
        [cx + radius * Math.cos(a), cy + radius * Math.sin(a)]
      end
      face(entities, map, pts)
    end

    def self.arc_band(entities, map, cx, cy, radius, line_width, a0, a1, segments = 32)
      hw = line_width / 2.0
      face(entities, map,
           annulus_points(cx, cy, radius + hw, radius - hw, a0, a1, segments))
    end

    def self.annulus_points(cx, cy, r_out, r_in, a0, a1, segments)
      pts = []
      (0..segments).each do |i|
        a = a0 + (a1 - a0) * i / segments
        pts << [cx + r_out * Math.cos(a), cy + r_out * Math.sin(a)]
      end
      segments.downto(0).each do |i|
        a = a0 + (a1 - a0) * i / segments
        pts << [cx + r_in * Math.cos(a), cy + r_in * Math.sin(a)]
      end
      pts
    end

    def self.dedup(points)
      out = []
      points.each do |p|
        prev = out.last
        out << p unless prev && (prev[0] - p[0]).abs < 1e-6 && (prev[1] - p[1]).abs < 1e-6
      end
      first = out.first
      last = out.last
      out.pop if out.size > 1 &&
                 (first[0] - last[0]).abs < 1e-6 && (first[1] - last[1]).abs < 1e-6
      out
    end

    # --- soccer ------------------------------------------------------------

    def self.draw_soccer(entities, rules, opts = {})
      length = rules[:length]
      width = rules[:width]
      lw = Rules::SOCCER_LINE_WIDTH
      map = mapper(length, false)

      # Boundary: four stripes meeting at (not overlapping) the corners,
      # painted inside the field like the rulebook's lines.
      rect(entities, map, 0, 0, length, lw)
      rect(entities, map, 0, width - lw, length, width)
      rect(entities, map, 0, lw, lw, width - lw)
      rect(entities, map, length - lw, lw, length, width - lw)

      # Halfway line, center circle, center mark.
      rect(entities, map, length / 2.0 - lw / 2.0, lw, length / 2.0 + lw / 2.0, width - lw)
      circle(entities, map, length / 2.0, width / 2.0, rules[:center_circle_radius], lw)
      disc(entities, map, length / 2.0, width / 2.0, 4.5)

      [false, true].each { |mirror| soccer_end(entities, rules, mirror, opts) }
    end

    def self.soccer_end(entities, rules, mirror, opts)
      length = rules[:length]
      width = rules[:width]
      cy = width / 2.0
      lw = Rules::SOCCER_LINE_WIDTH
      map = mapper(length, mirror)
      inner = lw # area lines butt against the inside edge of the goal line

      # Penalty area and goal area: two side stripes plus the front stripe.
      area_lines(entities, map, cy, lw, inner,
                 rules[:penalty_area_depth], rules[:penalty_area_width])
      area_lines(entities, map, cy, lw, inner,
                 rules[:goal_area_depth], rules[:goal_area_width])

      # Penalty mark and the arc outside the penalty area.
      if rules[:penalty_mark]
        pk = rules[:penalty_mark]
        disc(entities, map, pk, cy, 4.5)
        arc_r = rules[:penalty_arc_radius]
        if arc_r && rules[:penalty_area_depth] &&
           arc_r > rules[:penalty_area_depth] - pk
          half = Math.acos((rules[:penalty_area_depth] - pk) / arc_r)
          arc_band(entities, map, pk, cy, arc_r, lw, -half, half)
        end
      end

      # Corner arcs: quarter circles centered on each corner.
      r = rules[:corner_radius]
      arc_band(entities, map, 0, 0, r, lw, 0.0, Math::PI / 2.0, 8)
      arc_band(entities, map, 0, width, r, lw, -Math::PI / 2.0, 0.0, 8)

      # Build-out line (7v7): across the field, halfway between the penalty
      # area line and the halfway line.
      if rules[:buildout] && opts.fetch(:buildout, true)
        bx = (rules[:penalty_area_depth] + length / 2.0) / 2.0
        rect(entities, map, bx - lw / 2.0, lw, bx + lw / 2.0, width - lw)
      end

      # Goal, as a plan-view symbol: posts and net box behind the goal line.
      if opts.fetch(:goals, true)
        gw = rules[:goal_width] / 2.0
        depth = Units.ft(2)
        rect(entities, map, -depth, cy - gw - lw, 0, cy - gw)
        rect(entities, map, -depth, cy + gw, 0, cy + gw + lw)
        rect(entities, map, -depth - lw, cy - gw - lw, -depth, cy + gw + lw)
      end
    end

    # Rectangular area open toward the goal line: two side stripes running
    # from the goal line plus the stripe across the front edge.
    def self.area_lines(entities, map, cy, lw, inner, depth, area_width)
      return unless depth && area_width
      hw = area_width / 2.0
      rect(entities, map, inner, cy - hw, depth, cy - hw + lw)
      rect(entities, map, inner, cy + hw - lw, depth, cy + hw)
      rect(entities, map, depth - lw, cy - hw + lw, depth, cy + hw - lw)
    end

    # --- lacrosse ----------------------------------------------------------

    def self.draw_lacrosse(entities, rules)
      length = rules[:length]
      width = rules[:width]
      cy = width / 2.0
      lw = Rules::FOOTBALL_LINE_WIDTH
      map = mapper(length, false)

      # Boundary.
      rect(entities, map, 0, 0, length, lw)
      rect(entities, map, 0, width - lw, length, width)
      rect(entities, map, 0, lw, lw, width - lw)
      rect(entities, map, length - lw, lw, length, width - lw)

      # Midline and center X.
      rect(entities, map, length / 2.0 - lw / 2.0, lw, length / 2.0 + lw / 2.0, width - lw)
      rect(entities, map, length / 2.0 - 12.0, cy - lw / 2.0,
           length / 2.0 + 12.0, cy + lw / 2.0)

      # Wing lines: parallel to the sidelines, 20 yd out from field center,
      # extending 10 yd each side of the midline.
      wo = rules[:wing_from_center]
      wl = rules[:wing_length] / 2.0
      [cy - wo, cy + wo].each do |y|
        rect(entities, map, length / 2.0 - wl, y - lw / 2.0,
             length / 2.0 + wl, y + lw / 2.0)
      end

      [false, true].each { |mirror| lacrosse_end(entities, rules, mirror) }
    end

    def self.lacrosse_end(entities, rules, mirror)
      length = rules[:length]
      width = rules[:width]
      cy = width / 2.0
      lw = Rules::FOOTBALL_LINE_WIDTH
      map = mapper(length, mirror)
      gx = rules[:goal_from_end]

      # Goal crease circle, goal line across the crease, restraining line
      # across the full field.
      circle(entities, map, gx, cy, rules[:crease_radius], lw)
      gw = rules[:goal_width] / 2.0
      rect(entities, map, gx - lw / 2.0, cy - gw, gx + lw / 2.0, cy + gw)
      rx = gx + rules[:restraining_from_goal]
      rect(entities, map, rx - lw / 2.0, lw, rx + lw / 2.0, width - lw)
    end

    # --- football ----------------------------------------------------------

    def self.draw_football(entities, rules)
      ez = rules[:end_zone]
      playing = rules[:playing_length]
      length = playing + 2 * ez
      width = rules[:width]
      lw = Rules::FOOTBALL_LINE_WIDTH
      map = mapper(length, false)

      # Sidelines and end lines around the full field including end zones.
      rect(entities, map, 0, 0, length, lw)
      rect(entities, map, 0, width - lw, length, width)
      rect(entities, map, 0, lw, lw, width - lw)
      rect(entities, map, length - lw, lw, length, width - lw)

      # Goal lines (drawn double-width, reading as the heavier stripe).
      [ez, ez + playing].each do |x|
        rect(entities, map, x - lw, lw, x + lw, width - lw)
      end

      # Yard lines every interval between the goal lines.
      step = rules[:yard_line_interval]
      x = ez + step
      while x < ez + playing - 1
        rect(entities, map, x - lw / 2.0, lw, x + lw / 2.0, width - lw)
        x += step
      end
    end
  end
end
