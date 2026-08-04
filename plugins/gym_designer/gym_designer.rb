# Gym Designer — registrar.
#
# This file lives directly in the SketchUp Plugins folder alongside the
# gym_designer/ directory. It only registers the extension; all real loading
# happens in gym_designer/main.rb so the extension can be disabled cleanly
# from the Extension Manager.

require "sketchup.rb"
require "extensions.rb"

module GymDesigner
  unless const_defined?(:PLUGIN_ID)
    PLUGIN_ID = "gym_designer".freeze
    PLUGIN_NAME = "Gym Designer".freeze
    VERSION = "0.5.0".freeze
  end

  unless file_loaded?(__FILE__)
    loader = File.join(File.dirname(__FILE__), "gym_designer", "main")
    extension = SketchupExtension.new(PLUGIN_NAME, loader)
    extension.description =
      "Generates striped basketball courts by age group and code-informed " \
      "parametric bleachers sized to a target capacity."
    extension.version = VERSION
    extension.creator = "SKP Court and Bleachers"
    extension.copyright = "#{Time.now.year}"
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
