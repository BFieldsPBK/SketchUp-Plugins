# Unit helpers. SketchUp lengths are plain numerics measured in inches.
# Field sports mix systems — US fields are laid out in yards and feet,
# tracks in meters — so these helpers keep every conversion in one place.

module FieldDesigner
  module Units
    IN_PER_FT = 12.0
    IN_PER_YD = 36.0
    IN_PER_M = 39.3700787

    def self.ft(value)
      value.to_f * IN_PER_FT
    end

    def self.yd(value)
      value.to_f * IN_PER_YD
    end

    def self.m(value)
      value.to_f * IN_PER_M
    end

    def self.to_yd(inches)
      inches / IN_PER_YD
    end

    def self.to_m(inches)
      inches / IN_PER_M
    end

    # Parse a dialog string given in decimal yards / feet. Returns inches,
    # or `default` when blank / non-numeric / non-positive.
    def self.parse_yd(value, default = nil)
      n = parse_number(value)
      n ? n * IN_PER_YD : default
    end

    def self.parse_ft(value, default = nil)
      n = parse_number(value)
      n ? n * IN_PER_FT : default
    end

    def self.parse_number(value)
      s = value.to_s.strip
      return nil if s.empty?
      n = Float(s) rescue nil
      n && n > 0 ? n : nil
    end
  end
end
