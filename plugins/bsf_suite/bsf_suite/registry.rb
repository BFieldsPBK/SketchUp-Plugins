# frozen_string_literal: true

# Shared toolbar/menu registry.
#
# This file is deliberately self-contained and load-order independent: any
# plugin may `require "bsf_suite/registry"` at load time (the SketchUp
# Plugins directory is on $LOAD_PATH), and whichever plugin loads first
# pulls the registry in. The single toolbar and Extensions submenu are
# created lazily on first registration, so plugins can register in any
# order and the toolbar simply grows.
#
# Usage from a plugin's UI setup:
#
#   begin
#     require "bsf_suite/registry"
#   rescue LoadError
#     nil
#   end
#   if defined?(BSF::Suite::Registry)
#     BSF::Suite::Registry.add_commands("My Tool", [cmd_a, cmd_b])
#   else
#     ... build a standalone toolbar as before ...
#   end

require 'sketchup.rb'

module BSF
  module Suite
    module Registry
      TOOLBAR_NAME = 'BSF Office Tools'

      # Register a plugin's commands. Adds them to the shared toolbar
      # (separated from the previous plugin's group) and to a submenu named
      # after the plugin under Extensions > BSF Office Tools. Returns that
      # submenu so the caller can append extras (separators, dev items).
      # Re-registration under the same name is ignored so a plugin reload
      # does not duplicate buttons.
      def self.add_commands(plugin_name, commands)
        @registered ||= {}
        return @registered[plugin_name] if @registered.key?(plugin_name)

        toolbar.add_separator unless @registered.empty?
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
      def self.show_toolbar
        state = toolbar.get_last_state
        toolbar.restore if state == TB_VISIBLE || state == TB_NEVER_SHOWN
      end
    end
  end
end
