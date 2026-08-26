# frozen_string_literal: true
require 'sketchup.rb'
require 'extensions.rb'
module TTProUpdate
  EXTENSION = SketchupExtension.new('TT - Kiểm tra bản cập nhật', 'TT-pro-CapNhat/main')
  EXTENSION.version = '1.0.0'
  EXTENSION.creator = 'TRẦN TUẤN'
  EXTENSION.description = 'Kiểm tra và tải cập nhật TT-pro từ GitHub.'
  Sketchup.register_extension(EXTENSION, true)
end
