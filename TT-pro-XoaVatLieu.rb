# frozen_string_literal: true
require 'sketchup.rb'
require 'extensions.rb'
module TTProRemove
  EXTENSION = SketchupExtension.new('TT - Xóa vật liệu', 'TT-pro-XoaVatLieu/main')
  EXTENSION.version = '1.0.0'
  EXTENSION.creator = 'TRẦN TUẤN'
  EXTENSION.description = 'Xóa vật liệu đang chọn trên mặt, group và component.'
  Sketchup.register_extension(EXTENSION, true)
end
