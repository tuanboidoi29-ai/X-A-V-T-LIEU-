# frozen_string_literal: true
require 'sketchup.rb'
module TTProBoard
  module_function
  def start
    thickness = UI.inputbox(['Độ dày ván (mm)'], [18], 'TT - Vẽ ván')&.first
    return unless thickness
    value = Float(thickness) / 25.4
    raise 'Độ dày phải lớn hơn 0.' unless value.positive?
    Sketchup.active_model.select_tool(Tool.new(value))
  rescue StandardError => error
    UI.messagebox("Không thể bắt đầu vẽ ván: #{error.message}")
  end
  class Tool
    def initialize(thickness)
      @thickness = thickness
      @first = nil
      @normal = Z_AXIS.clone
      @preview = nil
    end
    def activate; Sketchup.set_status_text('TT - Vẽ ván: click góc thứ nhất, rồi góc chéo đối diện', SB_PROMPT); end
    def deactivate(view); view.invalidate; Sketchup.set_status_text('', SB_PROMPT); end
    def onMouseMove(_flags, x, y, view)
      point = point_at_plane(x, y, view)
      return unless point
      @preview = [@first, point] if @first
      view.invalidate
    end
    def draw(view)
      return unless @preview
      points = rectangle(@preview[0], @preview[1])
      view.drawing_color = 'DodgerBlue'
      view.draw(GL_LINE_LOOP, points)
      view.drawing_color = 'LightBlue'
      view.draw(GL_POLYGON, points)
    end
    def onLButtonDown(_flags, x, y, view)
      point = point_at_plane(x, y, view)
      return unless point
      if @first
        create_board(@first, point)
        Sketchup.active_model.select_tool(nil)
      else
        @first = point
        Sketchup.set_status_text('TT - Vẽ ván: click góc chéo đối diện', SB_PROMPT)
      end
    end
    def onKeyDown(key, _repeat, _flags, _view); Sketchup.active_model.select_tool(nil) if key == 27; end
    private
    def point_at_plane(x, y, view)
      input = Sketchup::InputPoint.new
      input.pick(view, x, y)
      if !@first && input.valid? && input.face
        @normal = input.face.normal
        @normal.normalize!
      end
      point = input.valid? ? input.position : Geom.intersect_line_plane(view.pickray(x, y), [@first || ORIGIN, @normal])
      return unless point
      return point unless @first
      Geom::Point3d.new(point.x, point.y, @first.z)
    end
    def axes
      axis = X_AXIS - (@normal * X_AXIS.dot(@normal))
      axis = Y_AXIS - (@normal * Y_AXIS.dot(@normal)) if axis.length < 0.001
      axis.normalize!
      other = @normal.cross(axis)
      other.normalize!
      [axis, other]
    end
    def rectangle(first, second)
      axis, other = axes
      delta = second - first
      length = delta.dot(axis)
      width = delta.dot(other)
      [first, first + axis * length, first + axis * length + other * width, first + other * width]
    end
    def create_board(first, second)
      model = Sketchup.active_model
      model.start_operation('TT - Vẽ ván', true)
      group = model.active_entities.add_group
      face = group.entities.add_face(rectangle(first, second))
      face.reverse! if face.normal.dot(@normal).negative?
      face.pushpull(@thickness)
      model.commit_operation
    rescue StandardError => error
      model.abort_operation if model&.operation_started?
      UI.messagebox("Không thể tạo ván: #{error.message}")
    end
  end
  unless file_loaded?(__FILE__)
    command = UI::Command.new('Vẽ ván bằng chuột') { start }
    command.tooltip = 'Vẽ ván bằng chuột'
    command.small_icon = File.join(__dir__, 'icon.svg')
    command.large_icon = File.join(__dir__, 'icon.svg')
    menu = UI.menu('Extensions')
    menu.add_item(command)
    toolbar = UI::Toolbar.new('TT - Vẽ ván')
    toolbar.add_item(command)
    toolbar.show
    file_loaded(__FILE__)
  end
end
