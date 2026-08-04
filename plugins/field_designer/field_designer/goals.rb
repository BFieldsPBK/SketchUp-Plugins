# 3D goal frames: soccer goals (posts + crossbar, sized per preset) and
# football goal posts (center post, crossbar, uprights). Simple box
# members keep the model light while reading clearly in plan and 3D.

module FieldDesigner
  module Goals
    SOCCER_POST = 4.0    # square member size, inches (regulation max 5")
    FOOTBALL_POST = 6.0
    CROSSBAR_HEIGHT = 120.0  # football crossbar: 10'
    UPRIGHT_HEIGHT = 240.0   # football uprights: 20' above the crossbar

    # Soccer goal at each end: posts on the goal line, opening measured
    # inside the posts, crossbar across the top.
    def self.soccer(parent, rules, material)
      group = parent.add_group
      group.name = "Goals"
      e = group.entities
      cy = rules[:width] / 2.0
      gw2 = rules[:goal_width] / 2.0
      gh = rules[:goal_height] || Units.ft(8)
      p = SOCCER_POST

      [0.0, rules[:length]].each do |gx|
        box(e, gx - p / 2, gx + p / 2, cy - gw2 - p, cy - gw2, 0, gh)
        box(e, gx - p / 2, gx + p / 2, cy + gw2, cy + gw2 + p, 0, gh)
        box(e, gx - p / 2, gx + p / 2, cy - gw2 - p, cy + gw2 + p, gh, gh + p)
      end
      Striping.paint(group, material)
    end

    # Football goal posts on each end line: slingshot-style center post,
    # crossbar at 10', uprights measured inside.
    def self.football(parent, rules, material)
      group = parent.add_group
      group.name = "Goal Posts"
      e = group.entities
      length = rules[:playing_length] + 2 * rules[:end_zone]
      cy = rules[:width] / 2.0
      cw2 = rules[:goal_post_width] / 2.0
      p = FOOTBALL_POST
      ch = CROSSBAR_HEIGHT

      [0.0, length].each do |gx|
        box(e, gx - p / 2, gx + p / 2, cy - p / 2, cy + p / 2, 0, ch)
        box(e, gx - p / 2, gx + p / 2, cy - cw2 - p, cy + cw2 + p, ch, ch + p)
        box(e, gx - p / 2, gx + p / 2, cy - cw2 - p, cy - cw2,
            ch + p, ch + p + UPRIGHT_HEIGHT)
        box(e, gx - p / 2, gx + p / 2, cy + cw2, cy + cw2 + p,
            ch + p, ch + p + UPRIGHT_HEIGHT)
      end
      Striping.paint(group, material)
    end

    # Axis-aligned solid box as six faces.
    def self.box(e, x0, x1, y0, y1, z0, z1)
      corners = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
      e.add_face(corners.map { |x, y| Geom::Point3d.new(x, y, z0) })
      e.add_face(corners.map { |x, y| Geom::Point3d.new(x, y, z1) })
      corners.each_index do |i|
        xa, ya = corners[i]
        xb, yb = corners[(i + 1) % 4]
        e.add_face([Geom::Point3d.new(xa, ya, z0), Geom::Point3d.new(xb, yb, z0),
                    Geom::Point3d.new(xb, yb, z1), Geom::Point3d.new(xa, ya, z1)])
      end
    end
  end
end
