# frozen_string_literal: true

# Shared toolbar/menu registry.
#
# This file is deliberately self-contained and load-order independent: any
# plugin may `require "pbk_tech_tools/registry"` at load time (the SketchUp
# Plugins directory is on $LOAD_PATH), and whichever plugin loads first
# pulls the registry in. The single toolbar and Extensions submenu are
# created lazily on first registration, so plugins can register in any
# order and the toolbar simply grows.
#
# Usage from a plugin's UI setup:
#
#   begin
#     require "pbk_tech_tools/registry"
#   rescue LoadError
#     nil
#   end
#   if defined?(PBK::TechTools::Registry)
#     PBK::TechTools::Registry.add_commands("My Tool", [cmd_a, cmd_b])
#   else
#     ... build a standalone toolbar as before ...
#   end

require 'sketchup.rb'

module PBK
  module TechTools
    module Registry
      TOOLBAR_NAME = 'PBK Tech Tools'

      # Make the suite visible even before any tool registers: the toolbar
      # always exists with an About button, so installing just the hub
      # shows up immediately in the toolbar list. Called by the suite
      # loader and by the first add_commands, whichever happens first.
      def self.ensure_ui
        return if @ui_ready
        @ui_ready = true

        about = UI::Command.new('About PBK Tech Tools…') { show_about }
        about.tooltip = 'About PBK Tech Tools'
        about.status_bar_text = 'List the PBK tools registered on this toolbar'
        icons = File.join(File.dirname(__FILE__), 'resources', 'icons')
        small = File.join(icons, 'suite_24.png')
        large = File.join(icons, 'suite_48.png')
        about.small_icon = small if File.exist?(small)
        about.large_icon = large if File.exist?(large)

        toolbar.add_item(about)
        menu.add_item(about)
        show_toolbar
      end

      def self.show_about
        version = defined?(PBK::TechTools::VERSION) ? PBK::TechTools::VERSION : ''
        tools = (@registered || {}).keys
        list = if tools.empty?
                 '(none yet — install the tool plugins: Field Designer, ' \
                 'Gym Designer, Program Translator)'
               else
                 tools.map { |t| "  •  #{t}" }.join("\n")
               end
        UI.messagebox("PBK Tech Tools #{version}\n\nRegistered tools:\n#{list}")
      end

      # Register a plugin's commands. Adds them to the shared toolbar
      # (separated from the previous plugin's group) and to a submenu named
      # after the plugin under Extensions > PBK Tech Tools. Returns that
      # submenu so the caller can append extras (separators, dev items).
      # Re-registration under the same name is ignored so a plugin reload
      # does not duplicate buttons.
      def self.add_commands(plugin_name, commands)
        @registered ||= {}
        return @registered[plugin_name] if @registered.key?(plugin_name)

        ensure_ui
        toolbar.add_separator
        commands.each { |cmd| toolbar.add_item(cmd) }
        show_toolbar

        submenu = menu.add_submenu(plugin_name)
        commands.each { |cmd| submenu.add_item(cmd) }
        @registered[plugin_name] = submenu
      end

      def self.toolbar
        @toolbar ||= UI::Toolbar.new(TOOLBAR_NAME)
      end

      def self.menu
        @menu ||= UI.menu('Plugins').add_submenu(TOOLBAR_NAME)
      end

      # Restore the toolbar's last saved position, or show it the first
      # time it ever appears. Safe to call repeatedly as plugins register.
      # The deferred second restore is SketchUp's standard workaround for
      # toolbars failing to appear when restored during startup.
      def self.show_toolbar
        state = toolbar.get_last_state
        return unless state == TB_VISIBLE || state == TB_NEVER_SHOWN
        toolbar.restore
        UI.start_timer(0.1, false) { toolbar.restore }
      end
    end
  end
end
