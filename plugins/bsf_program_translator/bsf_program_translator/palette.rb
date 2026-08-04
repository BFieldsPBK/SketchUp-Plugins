# frozen_string_literal: true

module BSF
  module ProgramTranslator
    # Department color handling.
    #
    # KNOWN holds the colors pulled directly from the reference HHES program
    # spreadsheet (the fill colors on each department header row in column A).
    # They are keyed by a normalized form of the department name so small
    # punctuation/spacing differences still match. Duplicates in the source
    # sheet (Life Skill / Arts / Music all pink; Support / Unassignable gray)
    # are preserved intentionally -- we color "exactly as the sheet".
    #
    # Departments that are NOT in this map (e.g. a new project introduces a
    # department we have not seen) get an automatically generated, evenly
    # spaced color so they still read distinctly. The import dialog lets the
    # user override any of these before geometry is generated.
    module Palette
      KNOWN = {
        'ADMINISTRATION'       => 'F6F2A2',
        'LIBRARY'              => 'CBB4CC',
        'LIFESKILL'            => 'F3BDBD',
        'ARTSSCIENCE'          => 'F3BDBD',
        'MUSICPERFORMINGARTS'  => 'F3BDBD',
        'CORELEARNING'         => 'F9D8AD',
        'SPECIALEDUCATION'     => 'EBAE93',
        'KITCHENCOMMONS'       => 'B1BEAA',
        'PHYSICALEDUCATION'    => 'B3D5E1',
        'SUPPORTSPACES'        => '888886',
        'UNASSIGNABLEAREAS'    => '888886'
      }.freeze

      module_function

      # Normalize a department name to a lookup key: uppercase, alphanumerics
      # only. "Arts / Science" -> "ARTSSCIENCE".
      def normalize(name)
        name.to_s.upcase.gsub(/[^A-Z0-9]/, '')
      end

      # Return a 6-char hex color (no leading '#') for a department.
      # Known departments use the sheet color; unknown ones get an auto color
      # derived from their position so repeated runs are stable.
      def color_for(name, auto_index = 0)
        KNOWN[normalize(name)] || auto_color(auto_index)
      end

      def known?(name)
        KNOWN.key?(normalize(name))
      end

      # Evenly spaced pastel colors using the golden-angle hue rotation.
      def auto_color(index)
        hue = (index * 137.508) % 360.0
        rgb_to_hex(hsl_to_rgb(hue, 0.45, 0.78))
      end

      def hsl_to_rgb(h, s, l)
        c = (1 - (2 * l - 1).abs) * s
        x = c * (1 - ((h / 60.0) % 2 - 1).abs)
        m = l - c / 2.0
        r, g, b = case h
                  when 0...60   then [c, x, 0]
                  when 60...120 then [x, c, 0]
                  when 120...180 then [0, c, x]
                  when 180...240 then [0, x, c]
                  when 240...300 then [x, 0, c]
                  else [c, 0, x]
                  end
        [((r + m) * 255).round, ((g + m) * 255).round, ((b + m) * 255).round]
      end

      def rgb_to_hex(rgb)
        format('%02X%02X%02X', *rgb)
      end

      # ['FF','00','80'] style -> [255, 0, 128]
      def hex_to_rgb(hex)
        h = hex.to_s.sub(/\A#/, '')
        [h[0, 2], h[2, 2], h[4, 2]].map { |p| p.to_i(16) }
      end
    end
  end
end
