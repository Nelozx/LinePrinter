Pod::Spec.new do |s|
  s.name             = 'LinePrinter'
  s.version          = '0.2.0'
  s.summary          = 'A declarative ESC/POS thermal printer layout engine and driver for iOS.'
  s.description      = <<-DESC
LinePrinter is a declarative ESC/POS thermal receipt layout engine and driver for iOS.
It supports standard text styling, smart multi-column alignment with wrapping, bitmap dithering,
and zero-dependency network (TCP) and Bluetooth (BLE) printing.
                       DESC

  s.homepage         = 'https://github.com/Nelo/LinePrinter'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Nelo' => '[EMAIL_ADDRESS]' }
  s.source           = { :git => 'https://github.com/Nelo/LinePrinter.git', :tag => s.version.to_s }
  s.swift_versions   = ['5.0', '5.5']

  s.ios.deployment_target = '12.0'
  s.source_files = 'LinePrinter/Sources/**/*'
  s.frameworks = 'UIKit'
end
