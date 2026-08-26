# frozen_string_literal: true
require 'sketchup.rb'
module TTProRemove
  module_function
  def remove
    model = Sketchup.active_model
    material = model.materials.current
    return UI.messagebox('Hãy chọn một vật liệu trong bảng Materials.') unless material
    return UI.messagebox('Hãy chọn mặt, group hoặc component cần xử lý.') if model.selection.empty?
    changed = 0
    model.start_operation('TT - Xóa vật liệu', true)
    model.selection.to_a.each { |entity| changed += clear(entity, material) }
    model.commit_operation
    UI.messagebox(changed.zero? ? 'Không tìm thấy mặt nào dùng vật liệu này.' : "Đã xóa vật liệu trên #{changed} mặt. Có thể Undo.")
  rescue StandardError => error
    model.abort_operation if model&.operation_started?
    UI.messagebox("Không thể xóa vật liệu: #{error.message}")
  end
  def clear(entity, material)
    return 0 unless entity.valid?
    count = 0
    if entity.respond_to?(:material) && entity.material == material
      entity.material = nil
      count += 1
    end
    if entity.respond_to?(:back_material) && entity.back_material == material
      entity.back_material = nil
      count += 1
    end
    children = entity.is_a?(Sketchup::ComponentInstance) ? entity.definition.entities : (entity.is_a?(Sketchup::Group) ? entity.entities : nil)
    children&.each { |child| count += clear(child, material) }
    count
  end
  unless file_loaded?(__FILE__)
    command = UI::Command.new('Xóa vật liệu đang chọn') { remove }
    command.tooltip = 'Xóa vật liệu đang chọn'
    command.small_icon = File.join(__dir__, 'icon.svg')
    command.large_icon = File.join(__dir__, 'icon.svg')
    menu = UI.menu('Extensions')
    menu.add_item(command)
    toolbar = UI::Toolbar.new('TT - Xóa vật liệu')
    toolbar.add_item(command)
    toolbar.show
    file_loaded(__FILE__)
  end
end
