# frozen_string_literal: true

# BSF Suite — registrar.
#
# The suite owns the shared "BSF Office Tools" toolbar and Extensions
# submenu that every office plugin registers its commands into. Install
# this alongside the individual tools; each tool also works standalone
# (falling back to its own toolbar) when the suite is absent.

require 'sketchup.rb'
require 'extensions.rb'

module BSF
  module Suite
    unless const_defined?(:VERSION)
      VERSION = '0.1.0'
    end

    unless file_loaded?(__FILE__)
      loader = File.join(File.dirname(__FILE__), 'bsf_suite', 'main')
      ext = SketchupExtension.new('BSF Office Tools', loader)
      ext.description = 'Shared toolbar and menu hub that gathers all BSF ' \
                        'office plugins in one place.'
      ext.version = VERSION
      ext.creator = 'BSF'
      Sketchup.register_extension(ext, true)
      file_loaded(__FILE__)
    end
  end
end
