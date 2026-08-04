# frozen_string_literal: true

# PBK Tech Tools — loader. Makes the shared registry available so plugins
# gather onto one toolbar, and puts the toolbar (with its About button) on
# screen even before any tool plugin registers.

require File.join(File.dirname(__FILE__), 'registry')

PBK::TechTools::Registry.ensure_ui

file_loaded(__FILE__)
