# Unit helpers. SketchUp lengths are plain numerics measured in inches, so
# everything internal is inches; these helpers keep the feet/inches
# conversions in one place, including parsing of dialog input strings.

module GymDesigner
  module Units
    FEET = 12.0

    def self.ft(value)
      value.to_f * FEET
    end

    def self.to_ft(inches)
      inches / FEET
    end

    # Parse a dialog string given in decimal feet. Returns inches, or
    # `default` when blank / non-numeric / non-positive.
    def self.parse_ft(value, default = nil)
      n = parse_number(value)
      n ? n * FEET : default
    end

    # Parse a dialog string given in inches.
    def self.parse_in(value, default = nil)
      parse_number(value) || default
    end

    def self.parse_int(value, default = nil)
      n = parse_number(value)
      n ? n.round : default
    end

    def self.parse_number(value)
      s = value.to_s.strip
      return nil if s.empty?
      n = Float(s) rescue nil
      n && n > 0 ? n : nil
    end

    # Human-readable feet-and-inches, e.g. 237.0 -> 19' 9"
    def self.fmt(inches)
      feet = (inches / FEET).floor
      rem = (inches - feet * FEET).round(2)
      rem = rem.to_i if rem == rem.to_i
      rem.zero? ? "#{feet}'" : "#{feet}' #{rem}\""
    end
  end
end
