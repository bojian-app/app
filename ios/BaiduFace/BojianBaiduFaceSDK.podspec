Pod::Spec.new do |s|
  s.name = 'BojianBaiduFaceSDK'
  s.version = '1.0.0'
  s.summary = 'Bojian adapter for Baidu native identity verification, plan 27030.'
  s.homepage = 'https://ai.baidu.com/ai-doc/FACE/elu6h6fz9'
  s.license = { :type => 'Proprietary', :text => 'Baidu SDK use is subject to the supplied Baidu license.' }
  s.author = 'Bojian'
  s.source = { :path => '.' }
  s.platform = :ios, '15.0'
  s.source_files = 'Classes/*.{h,m}'
  s.public_header_files = 'Classes/*.h'
  s.vendored_frameworks = 'Frameworks/*.framework'
  s.resources = 'Resources/*'
  s.frameworks = 'AVFoundation', 'CoreMedia', 'CoreVideo', 'CoreMotion', 'CoreTelephony', 'SystemConfiguration', 'Security', 'Accelerate', 'AudioToolbox', 'AdSupport'
  s.libraries = 'c++', 'z', 'resolv'
  s.requires_arc = true
  s.pod_target_xcconfig = { 'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES' }
end
