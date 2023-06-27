Pod::Spec.new do |s|
  s.name                  = "ArsdkEngine"
  s.version               = "7.7.0"
  s.summary               = "Parrot Drone SDK, arsdk based engine"
  s.homepage              = "https://developer.parrot.com"
  s.license               = "{ :type => 'BSD 3-Clause License', :file => 'LICENSE' }"
  s.author                = 'Parrot Drone SAS'
  s.source                = { :git => 'https://github.com/Parrot-Developers/pod_arsdkengine.git', :tag => "7.7.0" }
  s.platform              = :ios
  s.ios.deployment_target = '12.0'
  s.source_files          = 'ArsdkEngine/**/*', 'Proto/**/*.{swift,h,m}'
  s.dependency            'GroundSdk', '7.7.0'
  s.dependency            'SwiftProtobuf', '1.13.0'
  s.swift_version         = '5'
  s.pod_target_xcconfig   = {'SWIFT_VERSION' => '5'}
  s.xcconfig              = { 'ONLY_ACTIVE_ARCH' => 'YES' }
end
