# frozen_string_literal: true

require 'csv'
require File.join(File.dirname(__FILE__), 'palette')

module BSF
  module ProgramTranslator
    # Turns a CSV exported from a program / area-tabulation spreadsheet into a
    # structured program model. Columns are found by their HEADER NAMES (not
    # fixed positions), so any sheet works as long as it has, per option, a
    # "No. of Rooms" column and an "SF / Room" column, with room names in a
    # description column and departments as ALL-CAPS heading rows.
    #
    # A sheet may contain several option groups side by side (e.g. baseline /
    # request / working); each is discovered and offered as a choice. A single
    # group is used automatically.
    #
    # Program model:
    #   { scenario: 'HHES Program Request',
    #     departments: [
    #       { name: 'ADMINISTRATION', color: 'F6F2A2',
    #         line_items: [ { name:, count:, sf_per_room:, default_side: } ] } ] }
    module Parser
      AGGREGATE_RE = /\A(SUBTOTAL|TOTAL|PROGRAMAREA|TARGET|DELTA|BUILDINGAREA)/.freeze

      SKIP_DEPARTMENTS = %w[
        SITEPROGRAMAMENITIES
        MECHANICALPLATFORMATTIC
      ].freeze

      TRANSPARENT_PREFIXES = %w[
        CLASSROOMGROUPING
        FOODSERVICE
        BUILDINGSUPPORT
        RESTROOMS
        ELECTRICAL
        MECHANICALPLATFORMPENTHOUSES
      ].freeze

      module_function

      # ---- public API ----------------------------------------------------

      def read_rows(path)
        CSV.read(path)
      end

      # Discover the header row, the name column, and the option groups.
      # { header_row:, name_col:, groups: [ { name:, count_col:, sf_col:,
      #   capacity_col:, total_col: } ] }
      def detect_layout(rows)
        header_row = find_header_row(rows)
        unless header_row
          raise 'Could not find a header row. The sheet needs columns named ' \
                'like "No. of Rooms" and "SF / Room".'
        end
        roles = rows[header_row].map { |c| classify(c) }
        name_col = detect_name_col(rows, header_row, roles)
        groups = build_groups(rows, header_row, roles)
        if groups.empty?
          raise 'No option found. Each program option needs a "No. of Rooms" ' \
                'column paired with an "SF / Room" column.'
        end
        { header_row: header_row, name_col: name_col, groups: groups }
      end

      # Build the program for one chosen group.
      def build_program(rows, layout, group)
        name_col = layout[:name_col]
        start = layout[:header_row] + 1

        departments = []
        by_key = {}
        current = nil
        auto_index = 0

        rows[start..].to_a.each do |row|
          name = (row[name_col] || '').to_s.strip
          next if name.empty?

          norm = Palette.normalize(name)
          next if norm =~ AGGREGATE_RE

          if header_row?(row, name_col)
            result = classify_header(name, norm, departments, by_key) do
              dept = build_department(name, auto_index)
              auto_index += 1 unless Palette.known?(name)
              dept
            end
            current = result unless result == :current_unchanged
            next
          end

          count = parse_int(row[group[:count_col]])
          sf    = parse_float(row[group[:sf_col]])
          next if count.nil? || count < 1 # no rooms in this option, or a %
          next if sf.nil? || sf < 1        # percentage factor, skip
          next unless current.is_a?(Hash)

          add_line_item(current, name, count, sf)
        end

        finalize(departments, group[:name])
      end

      # Convenience: parse a file and build a program for the group whose name
      # contains `group_name` (or the first group when nil). Used by tests.
      def parse_csv(path, group_name = nil)
        rows = read_rows(path)
        layout = detect_layout(rows)
        group = pick_group(layout[:groups], group_name)
        build_program(rows, layout, group)
      end

      def pick_group(groups, group_name)
        return groups.first if group_name.nil? || group_name.empty?
        groups.find { |g| g[:name].downcase.include?(group_name.downcase) } ||
          groups.first
      end

      # ---- header / column detection ------------------------------------

      # Classify a header cell into a column role, or nil.
      def classify(header)
        h = header.to_s.strip.downcase
        return nil if h.empty?
        return :name     if h =~ /description|room name|space name|\bspace\b/
        return :total    if h.include?('total')
        return :capacity if h =~ /capacit|student|enroll/
        if h =~ /(no\.?|num|number|qty|count|#).*(room|rm)/ ||
           h =~ /\A(rooms?|qty|count|#)\z/
          return :count
        end
        return :sf       if h =~ /\b(sf|nsf|gsf|area)\b|sf\s*\/|sq\.?\s*ft/
        return :name     if h =~ /\broom\b/
        nil
      end

      # First row (within the first 30) that has both a count and an sf column.
      def find_header_row(rows)
        rows.each_with_index do |row, i|
          break if i > 30
          roles = row.map { |c| classify(c) }
          return i if roles.include?(:count) && roles.include?(:sf)
        end
        nil
      end

      def detect_name_col(rows, header_row, roles)
        idx = roles.index(:name)
        return idx if idx
        if header_row.positive?
          above = rows[header_row - 1].to_a.map { |c| classify(c) }
          j = above.index(:name)
          return j if j
        end
        0
      end

      # Pair each sf column with the nearest count column to its left, plus the
      # optional capacity (left of count) and total (right of sf). Name each
      # group from the title cell above it.
      def build_groups(rows, header_row, roles)
        counts = indices(roles, :count)
        sfs    = indices(roles, :sf)
        caps   = indices(roles, :capacity)
        totals = indices(roles, :total)

        groups = []
        sfs.each do |sf_col|
          count_col = counts.select { |c| c < sf_col && sf_col - c <= 4 }.max
          next unless count_col

          cap_col   = caps.select { |c| c < count_col && count_col - c <= 3 }.max
          total_col = totals.select { |t| t > sf_col && t - sf_col <= 3 }.min
          cols = [cap_col, count_col, sf_col, total_col].compact
          name = group_title(rows, header_row, cols) || "Option #{groups.size + 1}"
          groups << { name: name, count_col: count_col, sf_col: sf_col,
                      capacity_col: cap_col, total_col: total_col }
        end
        groups
      end

      def indices(roles, role)
        roles.each_index.select { |i| roles[i] == role }
      end

      # Look above the header row for a non-empty title cell spanning the group.
      def group_title(rows, header_row, cols)
        return nil if cols.empty?
        lo = cols.min
        hi = cols.max
        (header_row - 1).downto(0) do |r|
          row = rows[r] or next
          (lo..hi).each do |c|
            v = (row[c] || '').to_s.strip
            return tidy(v) unless v.empty?
          end
        end
        nil
      end

      # ---- department / room helpers ------------------------------------

      # A header/label row has text in the name column and NO numeric value in
      # any other column.
      def header_row?(row, name_col)
        row.each_with_index.none? { |cell, i| i != name_col && numeric?(cell) }
      end

      def classify_header(name, norm, departments, by_key)
        return :skip if SKIP_DEPARTMENTS.include?(norm)
        return :current_unchanged if transparent?(norm)

        if (existing = by_key[norm])
          return existing
        end

        unless Palette.known?(name) || mostly_uppercase?(name)
          return :current_unchanged
        end

        dept = yield
        departments << dept
        by_key[norm] = dept
        dept
      end

      def transparent?(norm)
        TRANSPARENT_PREFIXES.any? { |p| norm.start_with?(p) }
      end

      def mostly_uppercase?(name)
        letters = name.gsub(/[^A-Za-z]/, '')
        return false if letters.empty?
        letters.count('A-Z').to_f / letters.length >= 0.6
      end

      def build_department(name, auto_index)
        {
          name: tidy(name),
          color: Palette.color_for(name, auto_index),
          line_items: []
        }
      end

      def add_line_item(dept, name, count, sf)
        dept[:line_items] << {
          name: tidy(name),
          count: count,
          sf_per_room: sf,
          default_side: default_side(sf)
        }
      end

      def finalize(departments, scenario)
        kept = departments.reject { |d| d[:line_items].empty? }
        { scenario: scenario, departments: kept }
      end

      def default_side(sf)
        Math.sqrt(sf).round
      end

      def numeric?(cell)
        return true if cell.is_a?(Numeric)
        s = cell.to_s.strip
        return false if s.empty?
        !Float(s.delete(',%$')).nil?
      rescue ArgumentError
        false
      end

      def parse_int(cell)
        f = parse_float(cell)
        f&.round
      end

      def parse_float(cell)
        return cell.to_f if cell.is_a?(Numeric)
        s = cell.to_s.strip.delete(',$')
        return nil if s.empty?
        Float(s)
      rescue ArgumentError
        nil
      end

      def tidy(name)
        name.to_s.strip.gsub(/\s+/, ' ')
      end
    end
  end
end
