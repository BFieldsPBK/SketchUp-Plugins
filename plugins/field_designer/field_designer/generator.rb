# Builds the model: resolves the preset and track choice from the dialog
# payload, then generates surface, markings, and track inside a single
# named group wrapped in one undoable operation.

module FieldDesigner
  module Generator
    DEFAULT_APRON = Units.ft(10)

    def self.build(data)
      key = data["preset"].to_s
      rules = Rules.preset(key)
      return UI.messagebox("Unknown field preset.") unless rules

      rules = rules.dup
      if Rules.soccer?(key)
        rules[:length] = Units.parse_yd(data["length"], rules[:length])
        rules[:width] = Units.parse_yd(data["width"], rules[:width])
      end

      # Diamonds and tennis batteries have their own builders; a running
      # track only applies to rectangular fields.
      return build_special(rules, data) unless Rules.trackable?(key)

      length, width = Rules.field_extent(rules)

      choice = data.fetch("track", "none").to_s
      track = Rules.pick_track(choice, length, width)
      if track && !Rules.track_fits?(track, length, width)
        UI.messagebox(
          "Heads up: this field does not fit inside the #{track[:label]} " \
          "infield with #{Units.to_m(Rules::TRACK_CLEARANCE).round} m of " \
          "clearance. Building anyway — check overlaps."
        )
      elsif track.nil? && choice == "auto"
        UI.messagebox(
          "No regulation track (300 m or 400 m) fits around this field; " \
          "generating the field without a track."
        )
      end

      model = Sketchup.active_model
      model.start_operation("Generate #{rules[:label]}", true)
      group = build_group(model, rules, data, track, length, width)
      model.commit_operation
      model.selection.clear
      model.selection.add(group)
      group
    rescue StandardError => e
      model.abort_operation if model
      UI.messagebox("Field Designer error: #{e.message}")
      raise
    end

    # Diamond sports and tennis batteries.
    def self.build_special(rules, data)
      model = Sketchup.active_model
      model.start_operation("Generate #{rules[:label]}", true)
      group = model.active_entities.add_group
      mats = materials(model)
      if rules[:bases]
        group.name = rules[:label]
        Diamond.build(group.entities, rules, mats)
      else
        count = Units.parse_number(data["courts"])&.round || 1
        count = Tennis.build(group.entities, rules, count, mats)
        group.name = count > 1 ? "Tennis Battery (#{count} courts)" : rules[:label]
      end
      model.commit_operation
      model.selection.clear
      model.selection.add(group)
      group
    rescue StandardError => e
      model.abort_operation if model
      UI.messagebox("Field Designer error: #{e.message}")
      raise
    end

    def self.build_group(model, rules, data, track, length, width)
      group = model.active_entities.add_group
      group.name = track ? "#{rules[:label]} + #{track[:label]}" : rules[:label]
      ents = group.entities
      mats = materials(model)
      cx = length / 2.0
      cy = width / 2.0

      if track
        Track.draw_infield(ents, track, cx, cy, mats[:grass])
        Track.draw(ents, track, cx, cy, mats)
      else
        apron = Units.parse_ft(data["apron"], DEFAULT_APRON)
        surface = ents.add_group
        surface.name = "Field Surface"
        surface.entities.add_face(
          [Geom::Point3d.new(-apron, -apron, 0),
           Geom::Point3d.new(length + apron, -apron, 0),
           Geom::Point3d.new(length + apron, width + apron, 0),
           Geom::Point3d.new(-apron, width + apron, 0)]
        )
        Striping.paint(surface, mats[:grass])
      end

      lines = ents.add_group
      lines.name = "Field Markings"
      if rules[:playing_length]
        Striping.draw_football(lines.entities, rules)
      elsif rules[:crease_radius]
        Striping.draw_lacrosse(lines.entities, rules)
      else
        opts = { goals: data.fetch("goals", true),
                 buildout: data.fetch("buildout", true) }
        Striping.draw_soccer(lines.entities, rules, opts)
      end
      Striping.paint(lines, mats[:line])
      group
    end

    def self.materials(model)
      { grass: material(model, "FD Grass", [92, 145, 66]),
        line: material(model, "FD Line White", [250, 250, 250]),
        track: material(model, "FD Track", [186, 75, 60]),
        dirt: material(model, "FD Infield Dirt", [194, 148, 98]),
        fence: material(model, "FD Fence", [52, 82, 60]),
        court: material(model, "FD Court", [62, 110, 165]),
        court_apron: material(model, "FD Court Apron", [96, 128, 100]),
        net: material(model, "FD Net", [60, 60, 62]) }
    end

    def self.material(model, name, rgb)
      existing = model.materials[name]
      return existing if existing
      mat = model.materials.add(name)
      mat.color = Sketchup::Color.new(*rgb)
      mat
    end
  end
end
