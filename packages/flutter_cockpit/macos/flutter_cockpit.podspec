Pod::Spec.new do |s|
  s.name             = 'flutter_cockpit'
  s.version          = '1.0.0'
  s.summary          = 'In-app runtime primitives for AI-driven Flutter development workflows.'
  s.description      = <<-DESC
In-app runtime primitives for AI-driven Flutter development workflows.
                       DESC
  s.homepage         = 'https://github.com/cockpit-dev/flutter_cockpit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'cockpit-dev' => 'dev@cockpit.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }
end
