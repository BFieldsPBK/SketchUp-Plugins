# DimensionLinear placement for the court tool.
#
# Dimensions are chained: along one end, end-margin / court-length /
# end-margin share a dimension line, with the overall envelope length on a
# second line further out. Same pattern along one side for widths/margins.

module GymDesigner
  module Core
    module Dimensions
      NEAR_OFFSET = 36.0
      FAR_OFFSET = 84.0

      def self.court_dimensions(entities, rules, side_near, side_far, end_margin)
        length = rules[:court_length]
        width = rules[:court_width]
        env_l = length + 2 * end_margin
        env_w = width + side_near + side_far
        x0 = end_margin
        y0 = side_near

        # Chained along the near side (court length + both end margins),
        # with the overall envelope length further out.
        linear(entities, [0, y0], [x0, y0], [0, -(y0 + NEAR_OFFSET), 0])
        linear(entities, [x0, y0], [x0 + length, y0], [0, -(y0 + NEAR_OFFSET), 0])
        linear(entities, [x0 + length, y0], [env_l, y0], [0, -(y0 + NEAR_OFFSET), 0])
        linear(entities, [0, y0], [env_l, y0], [0, -(y0 + FAR_OFFSET), 0])

        # Chained along the near end (court width + both side margins),
        # with the overall envelope width further out.
        linear(entities, [x0, 0], [x0, y0], [-(x0 + NEAR_OFFSET), 0, 0])
        linear(entities, [x0, y0], [x0, y0 + width], [-(x0 + NEAR_OFFSET), 0, 0])
        linear(entities, [x0, y0 + width], [x0, env_w], [-(x0 + NEAR_OFFSET), 0, 0])
        linear(entities, [x0, 0], [x0, env_w], [-(x0 + FAR_OFFSET), 0, 0])
      end

      def self.linear(entities, p1, p2, offset)
        entities.add_dimension_linear(
          Geom::Point3d.new(p1[0], p1[1], 0),
          Geom::Point3d.new(p2[0], p2[1], 0),
          Geom::Vector3d.new(offset[0], offset[1], offset[2])
        )
      end
    end
  end
end
