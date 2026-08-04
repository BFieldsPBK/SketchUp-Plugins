# frozen_string_literal: true

dir = File.dirname(__FILE__)
require File.join(dir, 'palette')
require File.join(dir, 'parser')
require File.join(dir, 'builder')
require File.join(dir, 'dialog')
require File.join(dir, 'exporter')

module BSF
  module ProgramTranslator
    module_function

    # Menu entry point: pick a CSV, choose an option (only if the sheet has
    # more than one), review in the dialog, then build geometry.
    def import_program
      path = UI.openpanel('Select program CSV', '', 'CSV Files|*.csv||')
      return unless path

      rows = Parser.read_rows(path)
      layout = Parser.detect_layout(rows)
      group = choose_group(layout[:groups])
      return unless group

      program = Parser.build_program(rows, layout, group)
      if program[:departments].empty?
        UI.messagebox('No rooms found in that option of the spreadsheet.')
        return
      end

      Dialog.show(program) { |config| Builder.build(program, config) }
    rescue StandardError => e
      UI.messagebox("Could not read the program: #{e.message}")
    end

    # Auto-select when there is a single option; otherwise let the user pick.
    def choose_group(groups)
      return groups.first if groups.size == 1

      names = groups.map { |g| g[:name] }
      result = UI.inputbox(['Program option:'], [names.first],
                           [names.join('|')], 'Import Program')
      return nil unless result
      groups.find { |g| g[:name] == result[0] } || groups.first
    end

    # The shared PBK Tech Tools registry, when the pbk_tech_tools extension is
    # installed alongside this one; nil otherwise (standalone install).
    def suite_registry
      begin
        require 'pbk_tech_tools/registry'
      rescue LoadError
        return nil
      end
      defined?(PBK::TechTools::Registry) ? PBK::TechTools::Registry : nil
    end

    def set_icons(command, basename)
      icons = File.join(File.dirname(__FILE__), 'resources', 'icons')
      small = File.join(icons, "#{basename}_24.png")
      large = File.join(icons, "#{basename}_48.png")
      command.small_icon = small if File.exist?(small)
      command.large_icon = large if File.exist?(large)
    end

    def build_ui
      return if defined?(@loaded) && @loaded

      import_cmd = UI::Command.new('Import Program from CSV…') { import_program }
      set_icons(import_cmd, 'import')
      import_cmd.tooltip = 'Import Program from CSV'
      import_cmd.status_bar_text =
        'Build color-coded, labeled room blocks from a program spreadsheet'

      export_cmd = UI::Command.new('Export Program Comparison to CSV…') { Exporter.export }
      set_icons(export_cmd, 'export')
      export_cmd.tooltip = 'Export Program Comparison'
      export_cmd.status_bar_text =
        'Export a programmed-vs-modeled area comparison to CSV'

      commands = [import_cmd, export_cmd]

      if (suite = suite_registry)
        suite.add_commands('Program Translator', commands)
      else
        toolbar = UI::Toolbar.new('Program Translator')
        commands.each { |cmd| toolbar.add_item(cmd) }
        state = toolbar.get_last_state
        toolbar.restore if state == TB_VISIBLE || state == TB_NEVER_SHOWN
        menu = UI.menu('Plugins').add_submenu('Program Translator')
        commands.each { |cmd| menu.add_item(cmd) }
      end

      @loaded = true
    end

    build_ui
  end
end
