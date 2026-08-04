# frozen_string_literal: true

# PBK Tech Tools — registrar.
#
# The suite owns the shared "PBK Tech Tools" toolbar and Extensions
# submenu that every office plugin registers its commands into. Install
# this alongside the individual tools; each tool also works standalone
# (falling back to its own toolbar) when the suite is absent.

require 'sketchup.rb'
require 'extensions.rb'

module PBK
  module TechTools
    unless const_defined?(:VERSION)
      VERSION = '0.2.1'
    end

    unless file_loaded?(__FILE__)
      loader = File.join(File.dirname(__FILE__), 'pbk_tech_tools', 'main')
      ext = SketchupExtension.new('PBK Tech Tools', loader)
      ext.description = 'Shared toolbar and menu hub that gathers all PBK ' \
                        'office plugins in one place.'
      ext.version = VERSION
      ext.creator = 'PBK'
      Sketchup.register_extension(ext, true)
      file_loaded(__FILE__)
    end
  end
end
