# frozen_string_literal: true
require 'sketchup.rb'
require 'json'
require 'net/http'
require 'uri'
module TTProUpdate
  MANIFEST = 'https://raw.githubusercontent.com/tuanboidoi29-ai/X-A-V-T-LIEU-/main/update.json'
  CURRENT = '1.0.0'
  module_function
  def check
    data = JSON.parse(Net::HTTP.get(URI(MANIFEST)))
    if Gem::Version.new(data.fetch('version')) > Gem::Version.new(CURRENT)
      UI.messagebox("Có bản TT-pro #{data['version']} mới.\nTải tại:\n#{data['url']}")
    else
      UI.messagebox("Bạn đang dùng bản mới nhất (#{CURRENT}).")
    end
  rescue StandardError => error
    UI.messagebox("Không kiểm tra được cập nhật: #{error.message}")
  end
  unless file_loaded?(__FILE__)
    command = UI::Command.new('Kiểm tra bản cập nhật') { check }
    command.tooltip = 'Kiểm tra bản cập nhật'
    command.small_icon = File.join(__dir__, 'icon.svg')
    command.large_icon = File.join(__dir__, 'icon.svg')
    menu = UI.menu('Extensions')
    menu.add_item(command)
    toolbar = UI::Toolbar.new('TT - Cập nhật')
    toolbar.add_item(command)
    toolbar.show
    file_loaded(__FILE__)
  end
end
