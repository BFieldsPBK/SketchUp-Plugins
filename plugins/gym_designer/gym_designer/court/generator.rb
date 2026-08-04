# Court Generator entry point: dialog -> rules -> geometry.
#
# Output is one group ("GD Court — <level>") containing a Floor subgroup
# (the full envelope, court plus margins), a Striping subgroup, and an
# optional Dimensions subgroup. The envelope is saved to the model so the
# bleacher tool can position itself around the run-off.

module GymDesigner
  module Court
    DEFAULT_SIDE_MARGIN = 6.0 * Units::FEET
    DEFAULT_END_MARGIN = 10.0 * Units::FEET

    def self.run
      dialog = Core::Dialog.new(
        key: "court",
        title: "Court Generator",
        html: "court_dialog.html",
        width: 460,
        height: 660
      )
      dialog.on("generate") do |data|
        dialog.close
        generate(data)
      end
      dialog.on("cancel") { dialog.close }
      dialog.show
    end

    def self.generate(data)
      model = Sketchup.active_model
      overrides = {
        court_length: Units.parse_ft(data["court_length"]),
        court_width: Units.parse_ft(data["court_width"]),
        three_point_radius: Units.parse_ft(data["three_point_radius"]),
        corner_offset: Units.parse_ft(data["corner_offset"]),
        lane_width: Units.parse_ft(data["lane_width"])
      }
      age_group = data["age_group"] || "high_school"
      rules = Rules.resolve(age_group, overrides)
      side_near = Units.parse_ft(data["side_margin_near"], DEFAULT_SIDE_MARGIN)
      side_far = Units.parse_ft(data["side_margin_far"], DEFAULT_SIDE_MARGIN)
      end_margin = Units.parse_ft(data["end_margin"], DEFAULT_END_MARGIN)

      # Texture striping only works with unmodified preset dimensions — the
      # pre-rendered image can't stretch honestly. Fall back to geometry
      # striping (and say so) whenever it can't be used.
      texture_path = nil
      texture_note = nil
      if data["striping"] == "texture"
        candidate = File.join(GymDesigner::RESOURCES, "textures", "#{age_group}.png")
        if overrides.values.any?
          texture_note = "Dimension overrides present — texture striping can't " \
                         "stretch honestly, so geometry striping was used instead."
        elsif !File.exist?(candidate)
          texture_note = "No pre-rendered texture for this level — geometry " \
                         "striping used instead."
        else
          texture_path = candidate
        end
      end

      model.start_operation("Gym Designer — Court", true)
      build(model, rules, side_near, side_far, end_margin, data, texture_path)
      model.commit_operation
      summarize(rules, side_near, side_far, end_margin, texture_note)
    rescue StandardError => e
      model.abort_operation rescue nil
      UI.messagebox("Court generation failed:\n#{e.class}: #{e.message}")
    end

    # side_near is the margin along y=0 (where the dimension chains draw and
    # where the bleacher tool's "near" placement lands); side_far is opposite.
    # Unequal values shift the court off-center, e.g. bleachers on one side.
    def self.build(model, rules, side_near, side_far, end_margin, data, texture_path = nil)
      env_l = rules[:court_length] + 2 * end_margin
      env_w = rules[:court_width] + side_near + side_far

      group = model.entities.add_group
      group.name = "GD Court — #{rules[:label]}"

      floor = group.entities.add_group
      floor.name = "Floor"
      face = floor.entities.add_face(
        [0, 0, 0], [env_l, 0, 0], [env_l, env_w, 0], [0, env_w, 0]
      )
      floor_mat = material(model, "GD Floor", [214, 168, 110])
      face.material = floor_mat
      face.back_material = floor_mat

      if texture_path
        apply_texture(model, group, rules, end_margin, side_near, texture_path)
      else
        striping = group.entities.add_group
        striping.name = "Striping"
        striping.transformation = Geom::Transformation.new(
          Geom::Point3d.new(end_margin, side_near, 0)
        )
        Striping.draw(
          striping.entities, rules,
          material(model, "GD Stripe", [25, 25, 30]),
          three_point: truthy(data, "three_point", true)
        )
      end

      if truthy(data, "goals", true)
        goals = group.entities.add_group
        goals.name = "Goals"
        goals.transformation = Geom::Transformation.new(
          Geom::Point3d.new(end_margin, side_near, 0)
        )
        Goals.draw(
          goals.entities, model, rules,
          mount: data["goal_mount"] == "wall" ? "wall" : "ceiling",
          side_mount: data["side_goal_mount"] == "ceiling" ? "ceiling" : "wall",
          rim_height: Units.parse_ft(data["rim_height"], 10 * Units::FEET),
          side_count: Units.parse_int(data["side_goals"]) || 0,
          side_near: side_near,
          side_far: side_far,
          end_margin: end_margin
        )
      end

      if truthy(data, "dimensions", true)
        dims = group.entities.add_group
        dims.name = "Dimensions"
        Core::Dimensions.court_dimensions(dims.entities, rules, side_near, side_far, end_margin)
      end

      Core::Envelope.save(
        model,
        court_length: rules[:court_length],
        court_width: rules[:court_width],
        side_margin_near: side_near,
        side_margin_far: side_far,
        end_margin: end_margin,
        length: env_l,
        width: env_w,
        label: rules[:label]
      )
      group
    end

    # Court striping as a single pre-rendered image on a face sized exactly
    # to the court, floated just above the envelope floor. One texture tile
    # spans the whole court, pinned to the court's corners.
    def self.apply_texture(model, group, rules, end_margin, side_near, texture_path)
      mat_name = "GD Court — #{rules[:label]}"
      mat = model.materials[mat_name] || model.materials.add(mat_name)
      mat.texture = texture_path
      mat.texture.size = [rules[:court_length], rules[:court_width]]

      court = group.entities.add_group
      court.name = "Court texture"
      l = rules[:court_length]
      w = rules[:court_width]
      z = 0.05
      face = court.entities.add_face(
        [end_margin, side_near, z], [end_margin + l, side_near, z],
        [end_margin + l, side_near + w, z], [end_margin, side_near + w, z]
      )
      face.reverse! if face.normal.z < 0
      face.material = mat
      face.back_material = mat
      face.position_material(
        mat,
        [
          Geom::Point3d.new(end_margin, side_near, z), Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(end_margin + l, side_near, z), Geom::Point3d.new(1, 0, 0),
          Geom::Point3d.new(end_margin, side_near + w, z), Geom::Point3d.new(0, 1, 0)
        ],
        true
      )
    end

    def self.summarize(rules, side_near, side_far, end_margin, texture_note = nil)
      env_l = rules[:court_length] + 2 * end_margin
      env_w = rules[:court_width] + side_near + side_far
      lines = [
        "Court generated — #{rules[:label]}",
        "",
        "Court: #{Units.fmt(rules[:court_length])} x #{Units.fmt(rules[:court_width])}",
        "Three-point: #{Units.fmt(rules[:three_point_radius])} radius, " \
          "#{Units.fmt(rules[:corner_offset])} from sideline in the corner",
        "Lane: #{Units.fmt(rules[:lane_width])} wide x #{Units.fmt(rules[:lane_length])} deep",
        "Margins: #{Units.fmt(side_near)} near side, #{Units.fmt(side_far)} far side, " \
          "#{Units.fmt(end_margin)} ends",
        "Envelope: #{Units.fmt(env_l)} x #{Units.fmt(env_w)}",
        ""
      ]
      lines << "NOTE: #{texture_note}" << "" if texture_note
      lines << rules[:note] << "" if rules[:note]
      lines << "Dimensions are starting values — verify against the current rulebook."
      UI.messagebox(lines.join("\n"), MB_MULTILINE, "Gym Designer")
    end

    def self.truthy(data, key, default)
      return default unless data.key?(key)
      value = data[key]
      value == true || value == "true" || value == 1
    end

    def self.material(model, name, rgb)
      materials = model.materials
      mat = materials[name] || materials.add(name)
      mat.color = Sketchup::Color.new(*rgb)
      mat
    end
  end
end
