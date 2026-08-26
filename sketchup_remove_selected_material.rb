# frozen_string_literal: true

require 'sketchup.rb'

module AntiFly
  module RemoveSelectedMaterial
    MENU_LABEL = 'Xoa vat lieu dang chon'

    module_function

    def remove_from_selection
      model = Sketchup.active_model
      material = model.materials.current

      unless material
        UI.messagebox('Hay chon mot vat lieu hien tai trong bang Materials truoc.')
        return
      end

      selection = model.selection.to_a
      if selection.empty?
        UI.messagebox('Hay chon doi tuong co vat lieu can xoa.')
        return
      end

      changed = 0
      model.start_operation(MENU_LABEL, true)
      selection.each do |entity|
        changed += clear_material(entity, material)
      end
      model.commit_operation

      if changed.zero?
        UI.messagebox("Khong tim thay doi tuong nao dang dung vat lieu '#{material.display_name}'.")
      else
        UI.messagebox("Da xoa vat lieu '#{material.display_name}' tren #{changed} mat.")
      end
    rescue StandardError => e
      model.abort_operation if model&.operation_started?
      UI.messagebox("Khong the xoa vat lieu: #{e.message}")
    end

    def clear_material(entity, material)
      changed = 0

      if entity.is_a?(Sketchup::Face)
        if entity.material == material
          entity.material = nil
          changed += 1
        end
        if entity.back_material == material
          entity.back_material = nil
          changed += 1
        end
      elsif entity.respond_to?(:definition)
        entity.definition.entities.each do |child|
          changed += clear_material(child, material)
        end
      elsif entity.respond_to?(:entities)
        entity.entities.each do |child|
          changed += clear_material(child, material)
        end
      end

      changed
    end

    unless file_loaded?(__FILE__)
      menu = UI.menu('Extensions')
      menu.add_item(MENU_LABEL) { remove_from_selection }
      file_loaded(__FILE__)
    end
  end
end