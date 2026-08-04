# Gym Designer — loader.
#
# Loads the shared core plus both tools, then builds the toolbar and menu.
# Uses `load` rather than `require` so GymDesigner.reload works during
# development (edit a file, run `GymDesigner.reload` in the Ruby Console).

require "sketchup.rb"

module GymDesigner
  ROOT = File.dirname(__FILE__) unless const_defined?(:ROOT)
  RESOURCES = File.join(ROOT, "resources") unless const_defined?(:RESOURCES)

  MODULE_FILES = %w[
    core/units
    core/geometry
    core/solids
    core/envelope
    core/dimensions
    core/dialog
    court/rules
    court/striping
    court/goals
    court/generator
    bleacher/rules
    bleacher/layout
    bleacher/generator
  ].freeze

  def self.load_files
    MODULE_FILES.each { |file| load File.join(ROOT, "#{file}.rb") }
  end

  # Dev helper: re-load every module file without restarting SketchUp.
  def self.reload
    load_files
    puts "[Gym Designer] reloaded #{MODULE_FILES.size} files"
    true
  end

  def self.set_icons(command, basename)
    small = File.join(RESOURCES, "icons", "#{basename}_24.png")
    large = File.join(RESOURCES, "icons", "#{basename}_48.png")
    command.small_icon = small if File.exist?(small)
    command.large_icon = large if File.exist?(large)
  end

  # The shared BSF Office Tools registry, when the bsf_suite extension is
  # installed alongside this one; nil otherwise (standalone install).
  def self.suite_registry
    begin
      require "bsf_suite/registry"
    rescue LoadError
      return nil
    end
    defined?(BSF::Suite::Registry) ? BSF::Suite::Registry : nil
  end

  def self.build_ui
    return if @ui_built

    court_cmd = UI::Command.new("Court Generator") { Court.run }
    set_icons(court_cmd, "court")
    court_cmd.tooltip = "Court Generator"
    court_cmd.status_bar_text = "Generate a striped court by age group"

    bleacher_cmd = UI::Command.new("Bleacher Generator") { Bleacher.run }
    set_icons(bleacher_cmd, "bleacher")
    bleacher_cmd.tooltip = "Bleacher Generator"
    bleacher_cmd.status_bar_text = "Generate code-based bleachers by capacity"

    commands = [court_cmd, bleacher_cmd]

    if (suite = suite_registry)
      menu = suite.add_commands("Gym Designer", commands)
    else
      toolbar = UI::Toolbar.new("Gym Designer")
      commands.each { |cmd| toolbar.add_item(cmd) }
      state = toolbar.get_last_state
      toolbar.restore if state == TB_VISIBLE || state == TB_NEVER_SHOWN
      menu = UI.menu("Plugins").add_submenu("Gym Designer")
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
