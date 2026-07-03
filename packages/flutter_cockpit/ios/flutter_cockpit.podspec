Pod::Spec.new do |s|
  s.name             = 'flutter_cockpit'
  s.version          = '1.1.3'
  s.summary          = 'Native acceptance screenshot support for flutter_cockpit.'
  s.description      = <<-DESC
Native acceptance screenshot support for flutter_cockpit.
                       DESC
  s.homepage         = 'https://github.com/cockpit-dev/flutter_cockpit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'cockpit-dev' => 'devnull@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_cockpit/Sources/flutter_cockpit/**/*.swift'
  s.resource_bundles = {
    'flutter_cockpit_privacy' => ['flutter_cockpit/Sources/flutter_cockpit/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
