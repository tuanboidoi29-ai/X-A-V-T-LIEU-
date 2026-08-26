# frozen_string_literal: true

require 'sketchup.rb'
require 'json'
require 'net/http'
require 'tempfile'
require 'uri'

module TT
  module XoaVatLieu
    VERSION = '1.0.10'
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
          @dialog.execute_script("window.TTMaterial.status('Đang kiểm tra bản cập nhật...')")
          check_for_update
        end

        @dialog.add_action_callback('draw_board') do |_context, thickness_mm|
          start_board_tool(thickness_mm)
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

      def start_board_tool(thickness_mm)
        thickness = Float(thickness_mm) / 25.4
        raise 'Độ dày phải lớn hơn 0 mm.' unless thickness.positive?

        Sketchup.active_model.select_tool(BoardTool.new(thickness, @dialog))
        @dialog.execute_script("window.TTMaterial.status('Đang vẽ: click điểm đầu, điểm cuối chiều dài, rồi điểm xác định chiều rộng.')")
      rescue ArgumentError
        @dialog.execute_script("window.TTMaterial.status('Vui lòng nhập độ dày hợp lệ bằng mm.')")
      rescue StandardError => error
        @dialog.execute_script("window.TTMaterial.status(#{error.message.to_json})")
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
        response = download_with_redirects(download_url)
        raise "Tải cập nhật thất bại (HTTP #{response.code})." unless response.is_a?(Net::HTTPSuccess)

        temporary_file.write(response.body)
        temporary_file.close
        Sketchup.install_from_archive(temporary_file.path)
        load File.join(__dir__, 'main.rb')
        @dialog.execute_script("window.TTMaterial.status('Đã cập nhật lên phiên bản #{manifest.fetch('version')}. Không cần khởi động lại SketchUp.')")
      ensure
        temporary_file&.close!
      end

      def download_with_redirects(uri, limit = 5)
        raise 'URL cập nhật phải dùng HTTPS.' unless uri.scheme == 'https'
        raise 'URL cập nhật chuyển hướng quá nhiều lần.' if limit.zero?

        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: true,
          open_timeout: 10,
          read_timeout: 60
        ) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          request['User-Agent'] = 'TT-pro-Sketchup-Extension'
          http.request(request)
        end

        return download_with_redirects(URI.join(uri.to_s, response['location']), limit - 1) if response.is_a?(Net::HTTPRedirection)

        response
      end
    end

    class BoardTool
      def initialize(thickness, dialog)
        @thickness = thickness
        @dialog = dialog
        @first_point = nil
        @second_point = nil
        @preview = nil
      end

      def activate
        Sketchup.set_status_text('TT - Vẽ ván: chọn góc thứ nhất', SB_PROMPT)
      end

      def deactivate(view)
        view.invalidate
        Sketchup.set_status_text('', SB_PROMPT)
      end

      def onMouseMove(_flags, x, y, view)
        return unless @first_point

        point = point_on_drawing_plane(x, y, view)
        return unless point
        if @first_point && @second_point
          width = distance_from_line(point, @first_point, @second_point)
          @preview = [@first_point, @second_point, width]
          length_mm = @first_point.distance(@second_point) * 25.4
          width_mm = width * 25.4
          Sketchup.set_status_text("Dài: %.1f mm | Rộng: %.1f mm | Dày: %.1f mm | Click để tạo" % [length_mm, width_mm, @thickness * 25.4], SB_PROMPT)
        elsif @first_point
          @preview = [@first_point, point, nil] if point
        end
        view.invalidate
      end

      def draw(view)
        return unless @preview

        first, second, width = @preview
        view.drawing_color = 'DodgerBlue'
        view.line_width = 2
        if width && width > 0.001
          view.draw(GL_LINE_LOOP, rectangle_points(first, second, width))
          view.drawing_color = 'LightBlue'
          view.draw(GL_POLYGON, rectangle_points(first, second, width))
        else
          view.draw(GL_LINE_STRIP, [first, second])
        end
      end

      def onLButtonDown(_flags, x, y, view)
        point = point_on_drawing_plane(x, y, view)
        return unless point

        if @second_point
          width = distance_from_line(point, @first_point, @second_point)
          if width < 0.01
            @dialog&.execute_script("window.TTMaterial.status('Chiều rộng quá nhỏ. Hãy click lệch khỏi đường chiều dài.')")
          else
            create_board(@first_point, @second_point, width)
            Sketchup.active_model.select_tool(nil)
          end
        elsif @first_point
          @second_point = point
          Sketchup.set_status_text('TT - Vẽ ván: chọn điểm xác định chiều rộng', SB_PROMPT)
        else
          @first_point = point
          Sketchup.set_status_text('TT - Vẽ ván: chọn điểm cuối chiều dài', SB_PROMPT)
        end
      end

      def onKeyDown(key, _repeat, _flags, _view)
        Sketchup.active_model.select_tool(nil) if key == 27
      end

      private

      def point_on_drawing_plane(x, y, view)
        input_point = Sketchup::InputPoint.new
        input_point.pick(view, x, y)
        point = input_point.valid? ? input_point.position : nil
        if point.nil?
          plane_z = @first_point ? @first_point.z : 0.0
          point = Geom.intersect_line_plane(
            view.pickray(x, y),
            [Geom::Point3d.new(0, 0, plane_z), Z_AXIS]
          )
        end
        return unless point

        Geom::Point3d.new(point.x, point.y, @first_point ? @first_point.z : point.z)
      end

      def distance_from_line(point, first, second)
        line = second - first
        return 0 if line.length < 0.001

        relative = point - first
        ((relative.x * line.y) - (relative.y * line.x)).abs / line.length
      end

      def rectangle_points(first, second, width)
        direction = second - first
        direction.z = 0
        return [first, first, second, second] if direction.length < 0.001

        direction.normalize!
        perpendicular = Geom::Vector3d.new(-direction.y, direction.x, 0)
        perpendicular.length = width
        [first + perpendicular * 0.5, second + perpendicular * 0.5,
         second - perpendicular * 0.5, first - perpendicular * 0.5]
      end

      def create_board(first, second, width)
        return if first.distance(second) < 0.01 || width < 0.01

        model = Sketchup.active_model
        model.start_operation('TT - Vẽ ván', true)
        group = model.active_entities.add_group
        face = group.entities.add_face(rectangle_points(first, second, width))
        face.reverse! if face.normal.z.negative?
        face.pushpull(@thickness)
        model.commit_operation
        @dialog&.execute_script("window.TTMaterial.status('Đã tạo ván theo hướng bắt điểm. Dài #{first.distance(second) * 25.4} mm, rộng #{width * 25.4} mm, dày #{@thickness * 25.4} mm.')")
      rescue StandardError => error
        model.abort_operation if model&.operation_started?
        @dialog&.execute_script("window.TTMaterial.status(#{"Không thể tạo ván: #{error.message}".to_json})")
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
      board_command = UI::Command.new('Vẽ ván bằng chuột') { show_dialog }
      board_command.tooltip = 'Vẽ ván bằng chuột'
      board_command.status_bar_text = 'Mở công cụ vẽ ván bằng chuột'
      board_icon_path = File.join(__dir__, 'board_icon.svg')
      board_command.small_icon = board_icon_path
      board_command.large_icon = board_icon_path
      menu.add_item(board_command)
      toolbar.add_item(board_command)
      toolbar.show
      file_loaded(__FILE__)
    end
  end
end