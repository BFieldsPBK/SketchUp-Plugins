# The gym-box model both tools reference — the coupling point.
#
# The court generator writes the envelope (court footprint plus run-off /
# side-court margins) into the model's attribute dictionary. The bleacher
# generator reads it to prefill the available seating length and to place
# seating just outside the run-off. Everything is stored in inches, with the
# envelope's lower-left corner at the model origin.

module GymDesigner
  module Core
    module Envelope
      DICT = "GymDesigner_Envelope".freeze
      KEYS = %i[court_length court_width side_margin_near side_margin_far
                end_margin length width label].freeze

      def self.save(model, data)
        KEYS.each { |key| model.set_attribute(DICT, key.to_s, data[key]) }
      end

      def self.load(model)
        return nil unless model.attribute_dictionary(DICT)
        KEYS.each_with_object({}) { |key, hash| hash[key] = model.get_attribute(DICT, key.to_s) }
      end

      def self.clear(model)
        dicts = model.attribute_dictionaries
        dicts.delete(DICT) if dicts && dicts[DICT]
      end
    end
  end
end
