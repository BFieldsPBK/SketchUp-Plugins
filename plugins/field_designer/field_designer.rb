# Field Designer — registrar.
#
# This file lives directly in the SketchUp Plugins folder alongside the
# field_designer/ directory. It only registers the extension; all real
# loading happens in field_designer/main.rb so the extension can be
# disabled cleanly from the Extension Manager.

require "sketchup.rb"
require "extensions.rb"

module FieldDesigner
  unless const_defined?(:PLUGIN_ID)
    PLUGIN_ID = "field_designer".freeze
    PLUGIN_NAME = "Field Designer".freeze
    VERSION = "0.2.2".freeze
  end

  unless file_loaded?(__FILE__)
    loader = File.join(File.dirname(__FILE__), "field_designer", "main")
    extension = SketchupExtension.new(PLUGIN_NAME, loader)
    extension.description =
      "Generates regulation athletic fields — soccer, football, lacrosse, " \
      "baseball/softball diamonds, and tennis courts — with soccer and " \
      "football optionally wrapped in a regulation 400 m or 300 m track."
    extension.version = VERSION
    extension.creator = "BSF"
    extension.copyright = "#{Time.now.year}"
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
