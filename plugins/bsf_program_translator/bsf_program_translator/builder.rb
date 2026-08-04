# frozen_string_literal: true

require 'json'

module BSF
  module ProgramTranslator
    # Generates SketchUp geometry from a parsed program plus the user's
    # choices (one side dimension per room type, one color per department).
    #
    # Layout is a "simple labeled grid": rooms flow left-to-right and wrap
    # into shelves; each department occupies its own horizontal band with a
    # heading. One block is generated per room (8 classrooms -> 8 blocks).
    #
    # Each block is stamped with an attribute dictionary (its department, room,
    # and original size) so the model can later be exported and compared
    # against the original program (see Exporter).
    module Builder
      ATTR_DICT       = 'bsf_program' # must match Exporter::ATTR
      BLOCK_HEIGHT_FT = 10.0  # nominal mass height
      GAP_FT          = 4.0   # space between blocks
      DEPT_GAP_FT     = 18.0  # space between department bands
      BAND_WIDTH_FT   = 220.0 # wrap blocks past this running width
      ROOM_LABEL_IN   = 14.0  # 3D text letter height for room labels
      DEPT_LABEL_IN   = 36.0  # 3D text letter height for department headings
      LABEL_INSET_IN  = 6.0
      LABEL_LIFT_IN   = 0.25  # tiny lift so text rests on the top face
      MIN_LABEL_SCALE = 0.08  # don't shrink labels past this fraction
      CHAR_W_RATIO    = 0.6   # approx Arial glyph advance / letter height

      FT = 12.0 # inches per foot (SketchUp's internal unit is inches)

      module_function

      # config:
      #   { sides:  { "di_ri" => Float (feet) },   # blank/nil -> square
      #     colors: { "di"    => "RRGGBB" } }
      # config:
      #   { colors: { "di" => "RRGGBB" },
      #     rooms:  { "di_ri" => { "sf" => Float, "side" => Float|nil,
      #                            "height" => Float } } }
      # Per-room overrides come from the dialog: edited area (sf), a custom
      # side (nil means square), and a height. Missing values fall back to the
      # parsed area, a square, and the nominal height.
      # Returns the number of room blocks created.
      def build(program, config = {})
        model = Sketchup.active_model
        rooms  = config[:rooms]  || {}
        colors = config[:colors] || {}

        model.start_operation('Import Program', true)
        begin
          root = model.active_entities.add_group
          root.name = "Program (#{program[:scenario]})"
          ents = root.entities

          cursor = { x: 0.0, top: 0.0, shelf_depth: 0.0 }
          count = 0
          manifest = []

          program[:departments].each_with_index do |dept, di|
            color = colors["#{di}"] || dept[:color]
            material = material_for(model, dept[:name], color)
            layer = model.layers.add(dept[:name])

            new_band!(cursor)
            add_dept_heading(ents, dept[:name], cursor)
            new_shelf!(cursor)

            dept[:line_items].each_with_index do |room, ri|
              ov = rooms["#{di}_#{ri}"] || {}
              sf     = pos_float(ov['sf'])     || room[:sf_per_room]
              side   = pos_float(ov['side'])   || Math.sqrt(sf)
              height = pos_float(ov['height']) || BLOCK_HEIGHT_FT
              room[:count].times do |n|
                name = room_display_name(room, n)
                add_block(ents, dept[:name], name, sf, side, height,
                          material, layer, cursor)
                manifest << { 'department' => dept[:name], 'room' => name,
                              'original_sf' => sf.round(1),
                              'original_height_ft' => height.round(2) }
                count += 1
              end
            end
          end

          # Stamp the whole program on the root so deletions can be detected.
          root.set_attribute(ATTR_DICT, 'manifest', manifest.to_json)
          root.set_attribute(ATTR_DICT, 'scenario', program[:scenario].to_s)

          model.commit_operation
          model.active_view.zoom_extents if model.active_view
          count
        rescue StandardError => e
          model.abort_operation
          raise e
        end
      end

      # ---- geometry ------------------------------------------------------

      def add_block(ents, dept_name, name, sf, side_ft, height_ft,
                    material, layer, cursor)
        width = side_ft * FT
        depth = (sf / side_ft) * FT
        wrap_if_needed!(cursor, width)

        origin_y = cursor[:top] - depth
        grp = ents.add_group
        face = grp.entities.add_face(
          [Geom::Point3d.new(0, 0, 0),
           Geom::Point3d.new(width, 0, 0),
           Geom::Point3d.new(width, depth, 0),
           Geom::Point3d.new(0, depth, 0)]
        )
        face.pushpull(height_ft * FT)
        rest_on_ground!(grp)

        grp.name = name
        grp.material = material
        grp.layer = layer
        stamp_block(grp, dept_name, name, sf, side_ft, height_ft)
        label = build_label(name, sf, width)
        add_room_label(grp.entities, label, width, depth, height_ft)
        grp.transform!(Geom::Transformation.translation(
                         Geom::Point3d.new(cursor[:x], origin_y, 0)))

        cursor[:x] += width + GAP_FT * FT
        cursor[:shelf_depth] = [cursor[:shelf_depth], depth].max
        grp
      end

      # Record identity + original size on the block so it can be found and
      # compared after a designer stretches it (see Exporter).
      def stamp_block(grp, dept_name, name, sf, side_ft, height_ft)
        grp.set_attribute(ATTR_DICT, 'department', dept_name)
        grp.set_attribute(ATTR_DICT, 'room', name)
        grp.set_attribute(ATTR_DICT, 'original_sf', sf.round(1))
        grp.set_attribute(ATTR_DICT, 'original_width_ft', side_ft.round(2))
        grp.set_attribute(ATTR_DICT, 'original_depth_ft', (sf / side_ft).round(2))
        grp.set_attribute(ATTR_DICT, 'original_height_ft', height_ft.round(2))
      end

      # Shift the just-extruded block (and only the block -- this runs before
      # the label is added) so its lowest point rests at z = 0, regardless of
      # which direction pushpull happened to extrude.
      def rest_on_ground!(grp)
        min_z = grp.bounds.min.z
        return if min_z.zero?
        grp.entities.transform_entities(
          Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -min_z)),
          grp.entities.to_a
        )
      end

      # Flat 3D text laid on the top face, readable in plan view. The block
      # spans z = 0..height, so the label rests just on top of it. The text is
      # then shrunk if needed so it stays within the block footprint.
      def add_room_label(ents, text, width, depth, height_ft)
        z = height_ft * FT + LABEL_LIFT_IN
        grp = add_3d_text(ents, text, ROOM_LABEL_IN,
                          Geom::Point3d.new(LABEL_INSET_IN, LABEL_INSET_IN, z))
        fit_label!(grp, width, depth)
      end

      # Scale the label down (never up) so it fits inside the block footprint
      # less a margin, keeping it anchored at its corner. Measuring the actual
      # text bounds avoids guessing per-font character widths.
      def fit_label!(grp, width, depth)
        bb = grp.bounds
        return if bb.width.zero? || bb.height.zero?
        avail_w = width - 2 * LABEL_INSET_IN
        avail_h = depth - 2 * LABEL_INSET_IN
        return if avail_w <= 0 || avail_h <= 0
        factor = [avail_w / bb.width, avail_h / bb.height, 1.0].min
        return if factor >= 1.0
        factor = MIN_LABEL_SCALE if factor < MIN_LABEL_SCALE
        grp.transform!(Geom::Transformation.scaling(bb.min, factor))
      end

      def add_dept_heading(ents, name, cursor)
        z = BLOCK_HEIGHT_FT * FT + LABEL_LIFT_IN
        add_3d_text(ents, name, DEPT_LABEL_IN,
                    Geom::Point3d.new(0, cursor[:top] + DEPT_LABEL_IN, z))
      end

      def add_3d_text(ents, string, height_in, origin)
        grp = ents.add_group
        align = defined?(TextAlignLeft) ? TextAlignLeft : 0
        grp.entities.add_3d_text(string.to_s, align, 'Arial',
                                 false, false, height_in, 0.0, 0.0, true, 0.0)
        grp.transform!(Geom::Transformation.translation(origin))
        grp
      end

      # ---- layout bookkeeping -------------------------------------------

      def wrap_if_needed!(cursor, width)
        return if cursor[:x].zero?
        return if cursor[:x] + width <= BAND_WIDTH_FT * FT
        cursor[:top] -= cursor[:shelf_depth] + GAP_FT * FT
        cursor[:x] = 0.0
        cursor[:shelf_depth] = 0.0
      end

      def new_shelf!(cursor)
        cursor[:x] = 0.0
        cursor[:shelf_depth] = 0.0
      end

      def new_band!(cursor)
        cursor[:top] -= cursor[:shelf_depth] + DEPT_GAP_FT * FT unless
          cursor[:top].zero? && cursor[:shelf_depth].zero?
        cursor[:x] = 0.0
        cursor[:shelf_depth] = 0.0
      end

      # ---- helpers -------------------------------------------------------

      # Parse a value to a positive Float, or nil (so callers can fall back).
      def pos_float(value)
        f = Float(value)
        f.positive? ? f : nil
      rescue ArgumentError, TypeError
        nil
      end

      # Display name for a single room instance (numbered when >1 of a type).
      def room_display_name(room, index)
        base = room[:name]
        room[:count] > 1 ? "#{base} #{index + 1}" : base
      end

      # Build the multi-line label: the (wrapped) name followed by the area.
      def build_label(name, sf, width)
        (wrap_name(name, width) + ["#{format_area(sf)} SF"]).join("\n")
      end

      # Wrap a name to fit the block width: break at '/' first, then at spaces
      # if a segment is still too long. Width-aware so wide blocks keep the
      # name on fewer lines and narrow blocks use more (rather than shrinking).
      def wrap_name(name, width)
        max = max_chars_per_line(width)
        return [name] if name.length <= max
        chunks = name.include?('/') ? name.split('/').map(&:strip) : [name]
        chunks.reject!(&:empty?)
        pack_lines(chunks, max)
      end

      # Greedily combine chunks onto lines up to `max` chars; a chunk longer
      # than `max` is first split into word-sized pieces.
      def pack_lines(chunks, max)
        lines = []
        cur = ''
        chunks.each do |chunk|
          pieces = chunk.length <= max ? [chunk] : split_words(chunk, max)
          pieces.each do |piece|
            if cur.empty?
              cur = piece
            elsif cur.length + 1 + piece.length <= max
              cur = "#{cur} #{piece}"
            else
              lines << cur
              cur = piece
            end
          end
        end
        lines << cur unless cur.empty?
        lines
      end

      def split_words(text, max)
        lines = []
        cur = ''
        text.split(/\s+/).each do |w|
          if cur.empty?
            cur = w
          elsif cur.length + 1 + w.length <= max
            cur = "#{cur} #{w}"
          else
            lines << cur
            cur = w
          end
        end
        lines << cur unless cur.empty?
        lines
      end

      # Approximate characters that fit on one line at the nominal label size.
      def max_chars_per_line(width)
        avail = width - 2 * LABEL_INSET_IN
        return 9_999 if avail <= 0
        [(avail / (ROOM_LABEL_IN * CHAR_W_RATIO)).floor, 1].max
      end

      def format_area(sf)
        sf == sf.round ? sf.round.to_s : format('%.0f', sf)
      end

      def material_for(model, dept_name, hex)
        key = "Dept - #{dept_name}"
        mat = model.materials[key] || model.materials.add(key)
        mat.color = Sketchup::Color.new(*Palette.hex_to_rgb(hex))
        mat
      end
    end
  end
end
