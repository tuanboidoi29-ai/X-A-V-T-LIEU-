# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module TT
  module XoaVatLieu
    EXTENSION = SketchupExtension.new(
      'TT - Xóa vật liệu',
      'tt_xoa_vat_lieu/main'
    )
    EXTENSION.version = '1.0.2'
    EXTENSION.creator = 'TRẦN TUẤN'
    EXTENSION.description = 'Xóa vật liệu đang chọn khỏi các mặt và đối tượng được chọn trong SketchUp.'

    Sketchup.register_extension(EXTENSION, true)
  end
end