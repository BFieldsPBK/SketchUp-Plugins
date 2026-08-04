# frozen_string_literal: true

# PBK Tech Tools — loader. The suite has no commands of its own; loading it just
# makes the shared registry available so plugins gather onto one toolbar.

require File.join(File.dirname(__FILE__), 'registry')

file_loaded(__FILE__)
