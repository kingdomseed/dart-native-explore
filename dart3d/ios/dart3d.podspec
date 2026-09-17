Pod::Spec.new do |s|
  s.name             = 'dart3d'
  s.version          = '0.1.0'
  s.summary          = 'General-purpose 3D scene plugin for DartNative (SceneKit on iOS).'
  s.description      = <<-DESC
    dart3d renders .fscene scene documents on the platform's native 3D
    stack — SceneKit on iOS, Filament + Jolt on Android. Scene updates
    arrive as PluginMutation bytes; no method channels.
  DESC
  s.homepage         = 'https://dartpub.dev/packages/dart3d'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Jason Holt Digital' => 'hello@jasonholtdigital.com' }
  s.platform         = :ios, '13.0'

  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.swift'
  s.frameworks       = 'UIKit', 'SceneKit', 'Foundation', 'Metal'

  s.swift_version    = '5.9'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }
end
