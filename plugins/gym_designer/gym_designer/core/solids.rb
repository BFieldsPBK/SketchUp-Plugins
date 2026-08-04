# Small 3D helpers shared by the court and bleacher generators.

module GymDesigner
  module Core
    module Solids
      # Axis-aligned box from its minimum corner and positive extents.
      def self.box(entities, x, y, z, dx, dy, dz)
        face = entities.add_face(
          [x, y, z], [x + dx, y, z], [x + dx, y + dy, z], [x, y + dy, z]
        )
        face.pushpull(face.normal.z > 0 ? dz : -dz)
      end

      def self.material(model, name, rgb)
        materials = model.materials
        mat = materials[name] || materials.add(name)
        mat.color = Sketchup::Color.new(*rgb)
        mat
      end
    end
  end
end
