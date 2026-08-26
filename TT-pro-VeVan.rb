# frozen_string_literal: true
require 'sketchup.rb'
require 'extensions.rb'
module TTProBoard
  EXTENSION = SketchupExtension.new('TT - Vẽ ván', 'TT-pro-VeVan/main')
  EXTENSION.version = '1.0.0'
  EXTENSION.creator = 'TRẦN TUẤN'
  EXTENSION.description = 'Vẽ ván bằng hai góc chéo và nhập độ dày.'
  Sketchup.register_extension(EXTENSION, true)
end
