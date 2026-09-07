Pod::Spec.new do |s|
  s.name             = 'LinePrinter'
  s.version          = '0.6.0'
  s.summary          = 'A declarative ESC/POS thermal printer layout engine and visual previewer for iOS.'
  s.description      = <<-DESC
LinePrinter is a declarative ESC/POS thermal receipt layout engine and visual previewer for iOS.
It supports standard text styling, smart multi-column alignment with wrapping, bitmap dithering,
high-fidelity receipt UI preview, and zero-dependency transport decoupling.
                       DESC

  s.homepage         = 'https://github.com/Nelozx/LinePrinter'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Nelo' => 'nelozx@163.com' }
  s.source           = { :git => 'https://github.com/Nelozx/LinePrinter.git', :tag => s.version.to_s }
  s.swift_versions   = ['5.0', '5.5']

  s.ios.deployment_target = '12.0'
  s.source_files = 'LinePrinter/Sources/**/*'
  s.frameworks = 'UIKit', 'CoreGraphics', 'CoreImage'
end
