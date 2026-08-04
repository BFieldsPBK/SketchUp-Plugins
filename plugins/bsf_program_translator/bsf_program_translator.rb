# frozen_string_literal: true

# SketchUp extension registration for the BSF Program Translator.
# Drop this file *and* the bsf_program_translator/ folder into SketchUp's
# Plugins directory (Extensions > Developer > or the standard Plugins path).

require 'sketchup.rb'
require 'extensions.rb'

module BSF
  module ProgramTranslator
    unless defined?(@extension_loaded) && @extension_loaded
      ext = SketchupExtension.new(
        'Program Translator',
        File.join(File.dirname(__FILE__), 'bsf_program_translator', 'main')
      )
      ext.description = 'Turns a program spreadsheet (CSV) into color-coded, ' \
                        'labeled room blocks grouped by department.'
      ext.version = '0.1.0'
      ext.creator = 'BSF'
      Sketchup.register_extension(ext, true)
      @extension_loaded = true
    end
  end
end
