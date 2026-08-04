# Basketball goal massing: backboard, flat rim ring, connector plate, and a
# ceiling-drop or wall-arm mount. Deliberately simple — these are planning
# visuals, not equipment shop drawings.
#
# Goals are drawn in the same court-local frame as the striping. A goal's
# local axes: +x faces the court, board face at x=0, rim center 15" into the
# court, board bottom 6" below the rim. Placement transforms rotate that
# into position for each end / sideline.

module GymDesigner
  module Court
    module Goals
      MAIN_BOARD_W = 72.0
      MAIN_BOARD_H = 42.0
      SIDE_BOARD_W = 54.0
      SIDE_BOARD_H = 36.0
      RIM_R = 9.0

      def self.draw(entities, model, rules, opts)
        mats = {
          steel: Core::Solids.material(model, "GD Goal Steel", [120, 126, 134]),
          board: Core::Solids.material(model, "GD Backboard", [235, 238, 240]),
          rim: Core::Solids.material(model, "GD Rim", [225, 106, 44])
        }
        length = rules[:court_length]
        cy = rules[:court_width] / 2.0

        # Main goals: board face on the backboard plane at each end. Wall
        # mounts reach back past the run-off to the envelope edge.
        main_arm = opts[:end_margin] + rules[:backboard_x]
        [[rules[:backboard_x], cy, 0], [length - rules[:backboard_x], cy, 180]].each do |x, y, ang|
          goal(entities, placement(x, y, ang), opts[:rim_height],
               MAIN_BOARD_W, MAIN_BOARD_H, opts[:mount], main_arm, mats)
        end

        side_goals(entities, rules, opts, mats) if opts[:side_count] > 0
      end

      # Practice goals split between the sidelines (near side gets the odd
      # one), spaced evenly along the court. Mounting is selected
      # independently of the main goals; wall mounts reach back to the
      # envelope edge outside each margin.
      def self.side_goals(entities, rules, opts, mats)
        length = rules[:court_length]
        width = rules[:court_width]
        sides = [
          [(opts[:side_count] + 1) / 2, 0.0, 90, opts[:side_near]],
          [opts[:side_count] / 2, width, -90, opts[:side_far]]
        ]
        sides.each do |count, y, ang, margin|
          count.times do |i|
            x = length * (i + 1) / (count + 1.0)
            goal(entities, placement(x, y, ang), opts[:rim_height],
                 SIDE_BOARD_W, SIDE_BOARD_H, opts[:side_mount], margin, mats)
          end
        end
      end

      def self.placement(x, y, angle_deg)
        Geom::Transformation.new(Geom::Point3d.new(x, y, 0)) *
          Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0),
                                        Geom::Vector3d.new(0, 0, 1), angle_deg.degrees)
      end

      def self.goal(entities, transformation, rim_h, board_w, board_h, mount, arm_len, mats)
        group = entities.add_group
        ge = group.entities
        board_z = rim_h - 6.0

        board = ge.add_group
        Core::Solids.box(board.entities, -2.0, -board_w / 2.0, board_z, 2.0, board_w, board_h)
        board.material = mats[:board]

        # Rim: flat ring at rim height plus the connector plate to the board.
        rim = ge.add_group
        [[0.0, Math::PI], [Math::PI, 2 * Math::PI]].each do |a0, a1|
          pts = Core::Geometry.annulus_points(15.0, 0.0, RIM_R + 1.0, RIM_R - 1.0, a0, a1, 24)
          face = rim.entities.add_face(pts.map { |x, y| Geom::Point3d.new(x, y, rim_h) })
          face.material = mats[:rim]
          face.back_material = mats[:rim]
        end
        Core::Solids.box(rim.entities, 0.0, -3.0, rim_h - 2.0, 6.0, 6.0, 2.0)
        rim.material = mats[:rim]

        mount_grp = ge.add_group
        if mount == "ceiling"
          # Drop mast from above, behind the board top.
          Core::Solids.box(mount_grp.entities, -8.0, -2.0, board_z + board_h - 4.0,
                           6.0, 4.0, 144.0)
        else
          # Two horizontal arms back to the wall at mid-board height.
          [-board_w / 4.0, board_w / 4.0].each do |y|
            Core::Solids.box(mount_grp.entities, -arm_len, y - 1.5,
                             board_z + board_h / 2.0 - 1.5, arm_len, 3.0, 3.0)
          end
        end
        mount_grp.material = mats[:steel]

        group.transformation = transformation
        group
      end
    end
  end
end
