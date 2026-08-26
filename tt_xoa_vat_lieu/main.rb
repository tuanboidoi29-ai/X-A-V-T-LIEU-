# frozen_string_literal: true

require 'sketchup.rb'
require 'json'
require 'net/http'
require 'tempfile'
require 'uri'

module TT
  module XoaVatLieu
    VERSION = '1.0.2'
    UPDATE_MANIFEST_URL = 'https://raw.githubusercontent.com/tuanboidoi29-ai/X-A-V-T-LIEU-/main/update.json'
    DIALOG_TITLE = 'TT - Xóa vật liệu'
    MENU_LABEL = 'TT - Xóa vật liệu'

    class << self
      def show_dialog
        create_dialog unless @dialog
        refresh_dialog
        @dialog.show
      end

      def create_dialog
        @dialog = UI::HtmlDialog.new(
          dialog_title: DIALOG_TITLE,
          preferences_key: 'tt_xoa_vat_lieu',
          scrollable: false,
          resizable: true,
          width: 420,
          height: 510,
          style: UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_file(File.join(__dir__, 'dialog.html'))
        register_callbacks
        @dialog.set_on_closed { @dialog = nil }
      end

      def register_callbacks
        @dialog.add_action_callback('remove_material') do |_context|
          result = remove_selected_material
          @dialog.execute_script("window.TTMaterial.status(#{result.to_json})")
          refresh_dialog
        end

        @dialog.add_action_callback('refresh') do |_context|
          refresh_dialog
        end

        @dialog.add_action_callback('check_update') do |_context|
          check_for_update
        end
      end

      def refresh_dialog
        return unless @dialog

        model = Sketchup.active_model
        payload = {
          material: model.materials.current&.display_name || 'Chưa chọn vật liệu',
          selection: model.selection.length,
          version: VERSION
        }
        @dialog.execute_script("window.TTMaterial.refresh(#{payload.to_json})")
      end

      def remove_selected_material
        model = Sketchup.active_model
        material = model.materials.current
        return 'Hãy chọn một vật liệu trong bảng Materials.' unless material
        return 'Hãy chọn ít nhất một mặt, group hoặc component.' if model.selection.empty?

        changed = 0
        model.start_operation('TT - Xóa vật liệu', true)
        model.selection.to_a.each do |entity|
          changed += clear_material(entity, material)
        end
        model.commit_operation

        if changed.zero?
          "Không tìm thấy mặt nào đang dùng vật liệu '#{material.display_name}'."
        else
          "Đã xóa '#{material.display_name}' trên #{changed} mặt. Có thể Undo."
        end
      rescue StandardError => error
        model.abort_operation if model&.operation_started?
        "Không thể xóa vật liệu: #{error.message}"
      end

      def clear_material(entity, material)
        return 0 unless entity.valid?

        changed = 0
        if entity.respond_to?(:material) && entity.respond_to?(:material=)
          if entity.material == material
            entity.material = nil
            changed += 1
          end
        end
        if entity.respond_to?(:back_material) && entity.respond_to?(:back_material=)
          if entity.back_material == material
            entity.back_material = nil
            changed += 1
          end
        end

        children = if entity.is_a?(Sketchup::ComponentInstance)
                     entity.definition.entities
                   elsif entity.is_a?(Sketchup::Group)
                     entity.entities
                   end
        children&.each { |child| changed += clear_material(child, material) }
        changed
      end

      def check_for_update
        unless UPDATE_MANIFEST_URL.empty?
          uri = URI.parse(UPDATE_MANIFEST_URL)
          manifest = JSON.parse(Net::HTTP.get(uri))
          latest = manifest.fetch('version')
          if Gem::Version.new(latest) > Gem::Version.new(VERSION)
            install_update(manifest)
          else
            @dialog.execute_script("window.TTMaterial.status('Bạn đang dùng phiên bản mới nhất (#{VERSION}).')")
          end
          return
        end

        @dialog.execute_script("window.TTMaterial.status('Nút cập nhật đã sẵn sàng. Hãy cấu hình UPDATE_MANIFEST_URL trong main.rb để dùng máy chủ phát hành.')")
      rescue StandardError => error
        @dialog.execute_script("window.TTMaterial.status(#{"Không kiểm tra được cập nhật: #{error.message}".to_json})")
      end

      def install_update(manifest)
        download_url = URI.parse(manifest.fetch('url'))
        raise 'URL cập nhật phải dùng HTTPS.' unless download_url.scheme == 'https'

        @dialog.execute_script("window.TTMaterial.status('Đang tải bản cập nhật...')")
        temporary_file = Tempfile.new(['tt-xoa-vat-lieu-', '.rbz'])
        temporary_file.binmode
        response = Net::HTTP.start(
          download_url.host,
          download_url.port,
          use_ssl: true,
          open_timeout: 10,
          read_timeout: 60
        ) do |http|
          http.request(Net::HTTP::Get.new(download_url.request_uri))
        end
        raise "Tải cập nhật thất bại (HTTP #{response.code})." unless response.is_a?(Net::HTTPSuccess)

        temporary_file.write(response.body)
        temporary_file.close
        Sketchup.install_from_archive(temporary_file.path)
        load File.join(__dir__, 'main.rb')
        @dialog.execute_script("window.TTMaterial.status('Đã cập nhật lên phiên bản #{manifest.fetch('version')}. Không cần khởi động lại SketchUp.')")
      ensure
        temporary_file&.close!
      end
    end

    unless file_loaded?(__FILE__)
      command = UI::Command.new(MENU_LABEL) { show_dialog }
      command.tooltip = MENU_LABEL
      command.status_bar_text = 'Mở công cụ xóa vật liệu đang chọn'
      icon_path = File.join(__dir__, 'icon.svg')
      command.small_icon = icon_path
      command.large_icon = icon_path

      menu = UI.menu('Extensions')
      menu.add_item(command)

      toolbar = UI::Toolbar.new('TT - Xóa vật liệu')
      toolbar.add_item(command)
      toolbar.show
      file_loaded(__FILE__)
    end
  end
end