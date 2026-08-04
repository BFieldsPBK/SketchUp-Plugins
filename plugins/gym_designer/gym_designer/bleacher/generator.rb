# Bleacher Generator entry point: dialog -> layout plan -> massing geometry.
#
# Output is one group per configuration (fully open, and optionally a
# partially-open telescopic state) containing an understructure (stepped
# solid), bench seats split at the aisles, front-row accessible seating, and
# guardrails when the deployed height requires them. Local axes: x along the
# seating length, y from front (court side) to back (wall side), z up.
#
# Telescopic banks are wall-anchored: the back line is fixed and the front
# recedes as rows close. All configurations are therefore placed so their
# BACKS coincide; undeployed rows show as a closed stack (full bank height,
# one row deep) behind the deployed rows. When both configurations are
# generated they go on separate tags so scenes can toggle game vs. assembly.

module GymDesigner
  module Bleacher
    TAG_OPEN = "GD Bleachers - Fully Open".freeze
    TAG_PARTIAL = "GD Bleachers - Partially Open".freeze

    def self.run
      model = Sketchup.active_model
      env = Core::Envelope.load(model)
      dialog = Core::Dialog.new(
        key: "bleacher",
        title: "Bleacher Generator",
        html: "bleacher_dialog.html",
        width: 460,
        height: 820
      )
      dialog.prefill(
        "has_envelope" => !env.nil?,
        "envelope_label" => env && env[:label],
        "available_length" => env ? Units.to_ft(env[:length]).round(2) : 60
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
      p = params(data)
      env = Core::Envelope.load(model)

      # One placement per selected sideline; both banks share every other
      # parameter and the target capacity splits evenly between them.
      placements =
        if env.nil? || p[:sides].empty?
          ["origin"]
        else
          p[:sides].map { |side| "#{side}_#{p[:runoff]}" }
        end
      banks = placements.size
      per_bank = (p[:capacity].to_f / banks).ceil

      plan = Layout.plan(p.merge(capacity: per_bank))
      if plan[:error]
        UI.messagebox(plan[:error], MB_OK, "Gym Designer")
        return
      end

      front_needed = plan[:wc_spaces] * (p[:wc_space_width] + p[:companion_seat_width])
      if front_needed > plan[:used_length]
        plan[:warnings] << "Wheelchair + companion spaces need #{Units.fmt(front_needed)} " \
                           "of frontage but only #{Units.fmt(plan[:used_length])} exists — " \
                           "distribute across additional locations."
      end
      if env.nil? && !p[:sides].empty?
        plan[:warnings] << "No court envelope in the model — generated a single " \
                           "bank at the origin instead of the selected sideline(s)."
      end

      open_depth = config_depth(plan, p, plan[:rows])
      placements.each { |pl| check_encroachment(env, plan, p, open_depth, pl) }

      partial_rows = p[:partial_config] ? partial_row_count(plan, p) : nil

      model.start_operation("Gym Designer — Bleachers", true)
      open_groups = []
      partial_groups = []
      placements.each do |pl|
        open_group = build_bank(model, plan, p, plan[:rows])
        place(model, open_group, plan, p, open_depth, open_depth, pl)
        open_groups << open_group

        next unless partial_rows
        partial_depth = config_depth(plan, p, partial_rows)
        partial_group = build_bank(model, plan, p, partial_rows)
        place(model, partial_group, plan, p, partial_depth, open_depth, pl)
        partial_groups << partial_group
      end
      tag_configurations(model, open_groups, partial_groups) if partial_rows
      model.commit_operation
      summarize(plan, p, partial_rows, banks)
    rescue StandardError => e
      model.abort_operation rescue nil
      UI.messagebox("Bleacher generation failed:\n#{e.class}: #{e.message}")
    end

    def self.params(data)
      d = Rules::DEFAULTS
      runoff = data["runoff"] == "within" ? "within" : "beyond"
      sides = []
      sides << "near" if data["side_near"] == true
      sides << "far" if data["side_far"] == true
      # Legacy single-placement payloads ("far", "near_within", ...).
      if sides.empty? && data["placement"].to_s =~ /^(near|far)(_(beyond|within))?$/
        sides << Regexp.last_match(1)
        runoff = Regexp.last_match(3) if Regexp.last_match(3)
      end
      {
        capacity: Units.parse_int(data["capacity"], 200),
        available_length: Units.parse_ft(data["available_length"], 60 * Units::FEET),
        seat_width: Units.parse_in(data["seat_width"], d[:seat_width]),
        row_rise: Units.parse_in(data["row_rise"], d[:row_rise]),
        row_run: Units.parse_in(data["row_run"], d[:row_run]),
        seat_depth: d[:seat_depth],
        seat_board_height: d[:seat_board_height],
        aisle_width: Units.parse_in(data["aisle_width"], d[:aisle_width]),
        max_seats_between_aisles: Units.parse_int(data["max_seats_between_aisles"],
                                                  d[:max_seats_between_aisles]),
        max_rows: Units.parse_int(data["max_rows"], d[:max_rows]),
        guardrail_trigger: d[:guardrail_trigger],
        guardrail_height: Units.parse_in(data["guardrail_height"], d[:guardrail_height]),
        wc_space_width: d[:wc_space_width],
        wc_space_depth: d[:wc_space_depth],
        companion_seat_width: d[:companion_seat_width],
        wc_override: Units.parse_int(data["wc_spaces"]),
        sides: sides,
        runoff: runoff,
        frame_type: data["frame_type"] || "telescopic",
        partial_config: data["partial_config"] == true,
        rows_open: Units.parse_int(data["rows_open"])
      }
    end

    # Footprint depth of a configuration: wheelchair setback + deployed rows
    # + the closed stack (one row deep) when any rows remain undeployed.
    def self.config_depth(plan, p, rows_open)
      depth = plan[:wc_setback] + rows_open * p[:row_run]
      depth += p[:row_run] if rows_open < plan[:rows]
      depth
    end

    def self.partial_row_count(plan, p)
      return nil if plan[:rows] < 2
      rows = p[:rows_open] || (plan[:rows] / 2.0).ceil
      rows.clamp(1, plan[:rows] - 1)
    end

    # A "within run-off" bank occupies the court's side clearance; warn when
    # it is deeper than that side's margin and would encroach past the
    # sideline.
    def self.check_encroachment(env, plan, p, open_depth, placement)
      return unless env && placement.end_with?("_within")
      side = placement.start_with?("far") ? "far" : "near"
      margin = side == "far" ? env[:side_margin_far] : env[:side_margin_near]
      return unless margin # envelope saved by an older version
      if open_depth > margin
        plan[:warnings] << "Fully-open depth #{Units.fmt(open_depth)} exceeds the " \
                           "#{Units.fmt(margin)} #{side}-side run-off margin — the front " \
                           "row crosses the sideline clearance. Widen that side margin " \
                           "or reduce rows."
      end
    end

    def self.build_bank(model, plan, p, rows_open)
      group = model.entities.add_group
      group.name =
        if rows_open == plan[:rows]
          "GD Bleachers — #{plan[:total_capacity]} seats (fully open)"
        else
          "GD Bleachers — partial (#{rows_open} of #{plan[:rows]} rows)"
        end
      len = plan[:used_length]
      setback = plan[:wc_setback]

      structure_mat = material(model, "GD Bleacher", [148, 152, 158])
      seat_mat = material(model, "GD Seat", [176, 58, 46])
      access_mat = material(model, "GD Accessible", [58, 110, 196])

      build_structure(group, plan, p, len, setback, structure_mat, rows_open)
      build_seats(group, plan, p, setback, seat_mat, rows_open)
      build_aisles(group, plan, p, setback, structure_mat, rows_open) if plan[:aisles] > 0
      build_accessible(group, plan, p, len, access_mat) if plan[:wc_spaces] > 0
      if rows_open > 0 && rows_open * p[:row_rise] > p[:guardrail_trigger]
        build_guardrails(group, plan, p, len, setback, structure_mat, rows_open)
      end

      group.set_attribute("GymDesigner_Bleacher", "plan", JSON.generate(plan))
      group.set_attribute("GymDesigner_Bleacher", "frame_type", p[:frame_type])
      group.set_attribute("GymDesigner_Bleacher", "rows_open", rows_open)
      group
    end

    # Stepped solid for the deployed rows, plus the closed stack of any
    # undeployed rows: full bank height, one row deep, at the back.
    def self.build_structure(group, plan, p, len, setback, mat, rows_open)
      structure = group.entities.add_group
      structure.name = "Understructure"

      if rows_open > 0
        profile = [[setback, 0.0]]
        rows_open.times do |i|
          profile << [setback + i * p[:row_run], (i + 1) * p[:row_rise]]
          profile << [setback + (i + 1) * p[:row_run], (i + 1) * p[:row_rise]]
        end
        profile << [setback + rows_open * p[:row_run], 0.0]
        face = structure.entities.add_face(
          profile.map { |y, z| Geom::Point3d.new(0, y, z) }
        )
        face.pushpull(face.normal % Geom::Vector3d.new(1, 0, 0) > 0 ? len : -len)
      end

      if rows_open < plan[:rows]
        # Nested frames keep the full bank's height when closed: top row
        # structure plus its seat board, plus the rear guardrail when the
        # bank carries one. Closed/partial stacks must match the fully-open
        # silhouette height.
        stack_height = plan[:rows] * p[:row_rise] +
                       (plan[:guardrail] ? p[:guardrail_height] : p[:seat_board_height])
        box(structure.entities, 0, setback + rows_open * p[:row_run], 0,
            len, p[:row_run], stack_height)
      end
      structure.material = mat
    end

    def self.build_seats(group, plan, p, setback, mat, rows_open)
      return if rows_open < 1
      seats = group.entities.add_group
      seats.name = "Seats"
      rows_open.times do |row|
        tread_back = setback + (row + 1) * p[:row_run]
        y = tread_back - p[:seat_depth]
        z = (row + 1) * p[:row_rise]
        x = 0.0
        plan[:segments].each_with_index do |count, i|
          seg_len = count * p[:seat_width]
          box(seats.entities, x, y, z, seg_len, p[:seat_depth], p[:seat_board_height])
          x += seg_len
          x += p[:aisle_width] if i < plan[:segments].size - 1
        end
      end
      seats.material = mat
    end

    # Aisle stairs and center handrails (ICC 300-style): each row rise gets an
    # intermediate half-step against the riser, and each aisle a sloped
    # center rail following the tread noses (which are collinear), with posts
    # every other row. Only the deployed rows get stairs/rails.
    def self.build_aisles(group, plan, p, setback, mat, rows_open)
      return if rows_open < 1
      aisles = group.entities.add_group
      aisles.name = "Aisle steps & handrails"
      plan[:aisle_positions].each do |ax|
        (0...(rows_open - 1)).each do |i|
          box(aisles.entities, ax,
              setback + (i + 1) * p[:row_run] - p[:row_run] / 2.0,
              (i + 1) * p[:row_rise],
              p[:aisle_width], p[:row_run] / 2.0, p[:row_rise] / 2.0)
        end

        next if rows_open < 2
        x_rail = ax + p[:aisle_width] / 2.0 - 0.75
        y0 = setback
        z0 = p[:row_rise]
        y1 = setback + (rows_open - 1) * p[:row_run]
        z1 = rows_open * p[:row_rise]
        band = [[y0, z0 + 34.0], [y1, z1 + 34.0], [y1, z1 + 36.0], [y0, z0 + 36.0]]
        face = aisles.entities.add_face(band.map { |y, z| Geom::Point3d.new(x_rail, y, z) })
        face.pushpull(face.normal % Geom::Vector3d.new(1, 0, 0) > 0 ? 1.5 : -1.5)
        (0...rows_open).step(2) do |i|
          box(aisles.entities, x_rail,
              setback + i * p[:row_run], (i + 1) * p[:row_rise],
              1.5, 1.5, 34.0)
        end
      end
      aisles.material = mat
    end

    # Wheelchair spaces at grade along the front, one companion seat beside
    # each, spread evenly across the length. Spaces are marked faces (floated
    # to avoid z-fighting the gym floor) plus the companion bench box.
    def self.build_accessible(group, plan, p, len, mat)
      access = group.entities.add_group
      access.name = "Accessible seating"
      unit = p[:wc_space_width] + p[:companion_seat_width]
      pitch = len / plan[:wc_spaces].to_f
      plan[:wc_spaces].times do |i|
        x0 = [[pitch * (i + 0.5) - unit / 2.0, 0.0].max, len - unit].min
        face = access.entities.add_face(
          [x0, 0, 0.05],
          [x0 + p[:wc_space_width], 0, 0.05],
          [x0 + p[:wc_space_width], p[:wc_space_depth], 0.05],
          [x0, p[:wc_space_depth], 0.05]
        )
        face.material = mat
        face.back_material = mat
        box(access.entities, x0 + p[:wc_space_width], p[:wc_space_depth] - 16.0, 0,
            p[:companion_seat_width], 16.0, 18.0)
      end
      access.material = mat
    end

    # Side rails band along the deployed rows; the back rail only exists when
    # fully open (otherwise the closed stack forms the back).
    def self.build_guardrails(group, plan, p, len, setback, mat, rows_open)
      rails = group.entities.add_group
      rails.name = "Guardrails"

      if rows_open == plan[:rows]
        top_z = rows_open * p[:row_rise]
        back_y = setback + rows_open * p[:row_run]
        box(rails.entities, 0, back_y - 2.0, top_z, len, 2.0, p[:guardrail_height])
      end

      chain = []
      rows_open.times do |i|
        chain << [setback + i * p[:row_run], (i + 1) * p[:row_rise]]
        chain << [setback + (i + 1) * p[:row_run], (i + 1) * p[:row_rise]]
      end
      band = chain + chain.reverse.map { |y, z| [y, z + p[:guardrail_height]] }
      [0.0, len - 2.0].each do |x|
        face = rails.entities.add_face(band.map { |y, z| Geom::Point3d.new(x, y, z) })
        face.pushpull(face.normal % Geom::Vector3d.new(1, 0, 0) > 0 ? 2.0 : -2.0)
      end
      rails.material = mat
    end

    # Position a configuration against the court envelope. All configurations
    # share the wall (back) line: "beyond" fixes the wall so the fully-open
    # front lands on the envelope edge; "within" fixes the wall on the
    # envelope edge itself so the bank occupies the run-off. "near" rotates
    # 180 so the front row still faces the court. Everything centers along
    # the envelope; without an envelope, banks sit at the origin, backs
    # aligned.
    def self.place(model, group, plan, p, depth, open_depth, placement)
      env = Core::Envelope.load(model)
      len = plan[:used_length]
      rot180 = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0),
                                             Geom::Vector3d.new(0, 0, 1), 180.degrees)
      group.transformation =
        if env.nil? || placement == "origin"
          Geom::Transformation.new(Geom::Point3d.new(0, open_depth - depth, 0))
        else
          cx_far = (env[:length] - len) / 2.0
          cx_near = (env[:length] + len) / 2.0
          case placement
          when "far_beyond"
            Geom::Transformation.new(Geom::Point3d.new(cx_far, env[:width] + open_depth - depth, 0))
          when "far_within"
            Geom::Transformation.new(Geom::Point3d.new(cx_far, env[:width] - depth, 0))
          when "near_beyond"
            Geom::Transformation.new(Geom::Point3d.new(cx_near, depth - open_depth, 0)) * rot180
          when "near_within"
            Geom::Transformation.new(Geom::Point3d.new(cx_near, depth, 0)) * rot180
          else
            Geom::Transformation.new(Geom::Point3d.new(0, open_depth - depth, 0))
          end
        end
    end

    def self.tag_configurations(model, open_groups, partial_groups)
      tag_open = model.layers.add(TAG_OPEN)
      tag_partial = model.layers.add(TAG_PARTIAL)
      open_groups.each { |g| g.layer = tag_open }
      partial_groups.each { |g| g.layer = tag_partial }
      tag_partial.visible = false
    end

    def self.summarize(plan, p, partial_rows, banks)
      lines = ["Bleachers generated — #{p[:frame_type]}", ""]
      lines << "#{banks} banks, each:" if banks > 1
      lines.concat [
        "#{plan[:rows]} rows x #{plan[:seats_per_row]} bench seats = #{plan[:bench_capacity]}",
        "+ #{plan[:wc_spaces]} wheelchair spaces + #{plan[:companions]} companion seats"
      ]
      if banks > 1
        lines << "= #{plan[:total_capacity]} per bank"
        lines << "Combined: #{plan[:total_capacity] * banks} seats (target #{p[:capacity]})"
        lines << "Wheelchair counts computed per bank — the combined count can " \
                 "exceed the single-assembly IBC minimum (conservative)."
      else
        lines << "= #{plan[:total_capacity]} total (target #{p[:capacity]})"
      end
      lines.concat [
        "",
        "Aisles: #{plan[:aisles]} x #{p[:aisle_width]}\" " \
          "(row segments: #{plan[:segments].join(' / ')})",
        "Footprint: #{Units.fmt(plan[:used_length])} long x " \
          "#{Units.fmt(config_depth(plan, p, plan[:rows]))} deep, " \
          "top row #{Units.fmt(plan[:height])} high",
        ""
      ]
      if partial_rows
        lines << "Partial configuration: #{partial_rows} of #{plan[:rows]} rows open " \
                 "(#{partial_rows * plan[:seats_per_row]} bench seats). Tags " \
                 "\"#{TAG_OPEN}\" / \"#{TAG_PARTIAL}\" toggle the two states " \
                 "(partial starts hidden) — capture each in a scene for " \
                 "game vs. assembly views."
        lines << ""
      end
      plan[:warnings].each { |w| lines << "WARNING: #{w}" }
      lines << "" unless plan[:warnings].empty?
      lines << "ASSUMPTIONS (shown, not certified — verify with a licensed professional):"
      Rules.assumptions(p).each { |a| lines << "- #{a}" }
      UI.messagebox(lines.join("\n"), MB_MULTILINE, "Gym Designer")
    end

    def self.box(entities, x, y, z, dx, dy, dz)
      Core::Solids.box(entities, x, y, z, dx, dy, dz)
    end

    def self.material(model, name, rgb)
      Core::Solids.material(model, name, rgb)
    end
  end
end
