# Field Designer — loader.
#
# Loads the modules, then registers the command on the shared PBK Tech Tools
# Tools toolbar (or a standalone toolbar when the suite is not installed).
# Uses `load` rather than `require` so FieldDesigner.reload works during
# development.

require "sketchup.rb"

module FieldDesigner
  ROOT = File.dirname(__FILE__) unless const_defined?(:ROOT)
  RESOURCES = File.join(ROOT, "resources") unless const_defined?(:RESOURCES)

  MODULE_FILES = %w[
    units
    rules
    striping
    track
    diamond
    tennis
    generator
    dialog
  ].freeze

  def self.load_files
    MODULE_FILES.each { |file| load File.join(ROOT, "#{file}.rb") }
  end

  # Dev helper: re-load every module file without restarting SketchUp.
  def self.reload
    load_files
    puts "[Field Designer] reloaded #{MODULE_FILES.size} files"
    true
  end

  def self.set_icons(command, basename)
    small = File.join(RESOURCES, "icons", "#{basename}_24.png")
    large = File.join(RESOURCES, "icons", "#{basename}_48.png")
    command.small_icon = small if File.exist?(small)
    command.large_icon = large if File.exist?(large)
  end

  # The shared PBK Tech Tools registry, when the pbk_tech_tools extension is
  # installed alongside this one; nil otherwise (standalone install).
  def self.suite_registry
    begin
      require "pbk_tech_tools/registry"
    rescue LoadError
      return nil
    end
    defined?(PBK::TechTools::Registry) ? PBK::TechTools::Registry : nil
  end

  def self.build_ui
    return if @ui_built

    field_cmd = UI::Command.new("Field Generator") { FieldDesigner.run }
    set_icons(field_cmd, "field")
    field_cmd.tooltip = "Field Generator"
    field_cmd.status_bar_text =
      "Generate a regulation soccer or football field, optionally wrapped " \
      "in a 400 m or 300 m track"

    commands = [field_cmd]

    if (suite = suite_registry)
      menu = suite.add_commands("Field Designer", commands)
    else
      toolbar = UI::Toolbar.new("Field Designer")
      commands.each { |cmd| toolbar.add_item(cmd) }
      state = toolbar.get_last_state
      toolbar.restore if state == TB_VISIBLE || state == TB_NEVER_SHOWN
      menu = UI.menu("Plugins").add_submenu("Field Designer")
      commands.each { |cmd| menu.add_item(cmd) }
    end

    menu.add_separator
    menu.add_item("Reload (dev)") { reload }

    @ui_built = true
  end

  load_files
  build_ui
end

file_loaded(__FILE__)
