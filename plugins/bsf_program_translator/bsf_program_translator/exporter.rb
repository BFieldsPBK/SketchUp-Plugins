# frozen_string_literal: true

require 'csv'
require 'json'

module BSF
  module ProgramTranslator
    # Reads the program blocks back out of the model and writes a CSV comparing
    # each room's original program area with its current (possibly stretched)
    # size, flagging Same / Larger / Smaller / Removed.
    #
    # Blocks are identified by a hidden attribute dictionary stamped at
    # generation time (see Builder). Current size is measured from the block's
    # world bounding box, excluding the label text, so it reflects both group
    # scaling and internal push/pull edits.
    module Exporter
      ATTR = 'bsf_program'  # must match Builder::ATTR_DICT
      TOL_SF  = 1.0         # within this many SF -> "Same"
      TOL_PCT = 1.0         # ...or within this percent

      HEADERS = ['Department', 'Room', 'Original SF', 'Current SF', 'Delta SF',
                 '% Change', 'Orig W (ft)', 'Orig D (ft)', 'Cur W (ft)',
                 'Cur D (ft)', 'Orig H (ft)', 'Cur H (ft)', 'Status'].freeze

      module_function

      def export
        model = Sketchup.active_model
        blocks = collect_blocks(model)
        manifest = collect_manifest(model)
        if blocks.empty?
          UI.messagebox('No tagged program blocks found. Generate a program ' \
                        'with this version of the tool first, then compare.')
          return
        end

        rows = compare(blocks, manifest)
        path = UI.savepanel('Save comparison CSV', '', 'program_comparison.csv')
        return unless path
        path += '.csv' unless path =~ /\.csv\z/i
        write_csv(path, rows)

        changed = rows.count { |r| r[:status] != 'Same' }
        UI.messagebox("Exported #{rows.size} rooms (#{changed} changed) to:\n#{path}")
      rescue StandardError => e
        UI.messagebox("Export failed: #{e.message}")
      end

      # ---- pure comparison logic (no SketchUp) --------------------------

      # blocks: array of hashes with :department, :room, :original_sf,
      #   :original_w, :original_d, :original_h, :current_sf, :current_w,
      #   :current_d, :current_h
      # manifest: array of { 'department', 'room', 'original_sf', ... } used
      #   only to detect rooms whose block was deleted.
      def compare(blocks, manifest)
        rows = []
        seen = {}
        blocks.each do |b|
          seen[key(b[:department], b[:room])] = true
          rows << block_row(b)
        end
        manifest.each do |m|
          k = key(m['department'], m['room'])
          next if seen[k]
          rows << removed_row(m)
          seen[k] = true
        end
        rows.sort_by { |r| [r[:department].to_s, r[:room].to_s] }
      end

      def key(dept, room)
        "#{dept}||#{room}"
      end

      def status(orig_sf, cur_sf)
        return 'Removed' if cur_sf.nil?
        delta = cur_sf - orig_sf
        pct = orig_sf.positive? ? (delta / orig_sf * 100.0) : 0.0
        return 'Same' if delta.abs <= TOL_SF || pct.abs <= TOL_PCT
        delta.positive? ? 'Larger' : 'Smaller'
      end

      def block_row(b)
        orig = b[:original_sf].to_f
        cur = b[:current_sf].to_f
        delta = cur - orig
        pct = orig.positive? ? (delta / orig * 100.0) : 0.0
        {
          department: b[:department], room: b[:room],
          original_sf: r1(orig), current_sf: r1(cur), delta_sf: r1(delta),
          pct: format('%+.1f%%', pct),
          orig_w: r1(b[:original_w]), orig_d: r1(b[:original_d]),
          cur_w: r1(b[:current_w]), cur_d: r1(b[:current_d]),
          orig_h: r1(b[:original_h]), cur_h: r1(b[:current_h]),
          status: status(orig, cur)
        }
      end

      def removed_row(m)
        {
          department: m['department'], room: m['room'],
          original_sf: r1(m['original_sf'].to_f), current_sf: nil,
          delta_sf: nil, pct: nil,
          orig_w: nil, orig_d: nil, cur_w: nil, cur_d: nil,
          orig_h: r1((m['original_height_ft'] || 0).to_f), cur_h: nil,
          status: 'Removed'
        }
      end

      def r1(v)
        return nil if v.nil?
        (v.to_f * 10).round / 10.0
      end

      def write_csv(path, rows)
        CSV.open(path, 'w') do |csv|
          csv << HEADERS
          rows.each do |r|
            csv << [r[:department], r[:room], r[:original_sf], r[:current_sf],
                    r[:delta_sf], r[:pct], r[:orig_w], r[:orig_d], r[:cur_w],
                    r[:cur_d], r[:orig_h], r[:cur_h], r[:status]]
          end
        end
      end

      # ---- model reading (SketchUp) -------------------------------------

      # Walk the model; a group carrying our 'room' attribute is a block (leaf),
      # otherwise recurse into it (e.g. the root program group).
      def collect_blocks(model)
        found = []
        stack = model.entities.to_a
        until stack.empty?
          e = stack.pop
          next unless e.is_a?(Sketchup::Group)
          if e.get_attribute(ATTR, 'room')
            found << read_block(e)
          else
            stack.concat(e.entities.to_a)
          end
        end
        found
      end

      def collect_manifest(model)
        out = []
        model.entities.grep(Sketchup::Group).each do |g|
          json = g.get_attribute(ATTR, 'manifest')
          next unless json
          begin
            out.concat(JSON.parse(json))
          rescue JSON::ParserError
            next
          end
        end
        out
      end

      def read_block(grp)
        w, d, h = world_size(grp)
        {
          department: grp.get_attribute(ATTR, 'department'),
          room: grp.get_attribute(ATTR, 'room'),
          original_sf: grp.get_attribute(ATTR, 'original_sf').to_f,
          original_w: grp.get_attribute(ATTR, 'original_width_ft').to_f,
          original_d: grp.get_attribute(ATTR, 'original_depth_ft').to_f,
          original_h: grp.get_attribute(ATTR, 'original_height_ft').to_f,
          current_sf: (w * d),
          current_w: w, current_d: d, current_h: h
        }
      end

      # World-space width/depth/height (feet) of the block solid, excluding the
      # label text sub-group, accounting for the group's own transformation.
      def world_size(grp)
        local = Geom::BoundingBox.new
        grp.entities.each do |e|
          next if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          local.add(e.bounds)
        end
        return [0.0, 0.0, 0.0] if local.empty?
        t = grp.transformation
        world = Geom::BoundingBox.new
        (0..7).each { |i| world.add(local.corner(i).transform(t)) }
        [world.width / 12.0, world.height / 12.0, world.depth / 12.0]
      end
    end
  end
end
