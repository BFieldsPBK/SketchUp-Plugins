# Tennis court battery.
#
# Courts run lengthwise along x (net parallel to y) and stack side by side
# along y with the standard 12' gap. The playing court gets its own pad
# color over the general surface, USTA-style two-tone.

module FieldDesigner
  module Tennis
    LINE_WIDTH = 2.0
    PAD_Z = 0.005

    def self.build(parent, rules, count, mats)
      count = [[count, 1].max, 8].min
      cl = rules[:court_length]
      cw = rules[:court_width]
      gap = rules[:court_gap]
      ea = rules[:end_apron]
      sa = rules[:side_apron]

      total_w = count * cw + (count - 1) * gap + 2 * sa

      surface = parent.add_group
      surface.name = "Court Surface"
      Diamond.face_at(surface.entities,
                      [[-ea, -sa], [cl + ea, -sa],
                       [cl + ea, total_w - sa], [-ea, total_w - sa]], 0.0)
      Striping.paint(surface, mats[:court_apron])

      pads = parent.add_group
      pads.name = "Playing Courts"
      lines = parent.add_group
      lines.name = "Court Markings"
      nets = parent.add_group
      nets.name = "Nets"

      count.times do |i|
        y0 = i * (cw + gap)
        Diamond.face_at(pads.entities,
                        [[0, y0], [cl, y0], [cl, y0 + cw], [0, y0 + cw]], PAD_Z)
        court_lines(lines.entities, rules, y0)
        net(nets.entities, rules, y0)
      end

      Striping.paint(pads, mats[:court])
      Striping.paint(lines, mats[:line])
      Striping.paint(nets, mats[:net])
      count
    end

    def self.court_lines(e, rules, y0)
      cl = rules[:court_length]
      cw = rules[:court_width]
      sw = rules[:singles_width]
      sd = rules[:service_dist]
      lw = LINE_WIDTH
      z = Striping::LINE_Z
      cy = y0 + cw / 2.0
      alley = (cw - sw) / 2.0
      net_x = cl / 2.0

      # Baselines and doubles sidelines.
      rect(e, 0, y0, lw, y0 + cw, z)
      rect(e, cl - lw, y0, cl, y0 + cw, z)
      rect(e, lw, y0, cl - lw, y0 + lw, z)
      rect(e, lw, y0 + cw - lw, cl - lw, y0 + cw, z)

      # Singles sidelines.
      rect(e, lw, y0 + alley, cl - lw, y0 + alley + lw, z)
      rect(e, lw, y0 + cw - alley - lw, cl - lw, y0 + cw - alley, z)

      # Service lines, 21' each side of the net, spanning the singles court.
      [net_x - sd, net_x + sd].each do |x|
        rect(e, x - lw / 2.0, y0 + alley, x + lw / 2.0, y0 + cw - alley, z)
      end

      # Center service line between the service lines.
      rect(e, net_x - sd, cy - lw / 2.0, net_x + sd, cy + lw / 2.0, z)

      # Center marks: 4" ticks inward from each baseline.
      rect(e, lw, cy - lw / 2.0, lw + 4.0, cy + lw / 2.0, z)
      rect(e, cl - lw - 4.0, cy - lw / 2.0, cl - lw, cy + lw / 2.0, z)
    end

    # Standing net: a vertical mesh panel between posts 3' outside each
    # doubles sideline, 3'6" high at the posts.
    NET_HEIGHT = 42.0
    POST = 3.0

    def self.net(e, rules, y0)
      x = rules[:court_length] / 2.0
      over = rules[:net_overhang]
      ylo = y0 - over
      yhi = y0 + rules[:court_width] + over

      e.add_face([Geom::Point3d.new(x, ylo, 0), Geom::Point3d.new(x, yhi, 0),
                  Geom::Point3d.new(x, yhi, NET_HEIGHT),
                  Geom::Point3d.new(x, ylo, NET_HEIGHT)])
      Goals.box(e, x - POST / 2, x + POST / 2, ylo - POST, ylo, 0, NET_HEIGHT)
      Goals.box(e, x - POST / 2, x + POST / 2, yhi, yhi + POST, 0, NET_HEIGHT)
    end

    def self.rect(e, x0, y0, x1, y1, z)
      Diamond.face_at(e, [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], z)
    end
  end
end
