Pod::Spec.new do |s|
  s.name = 'BojianPangleAds'
  s.version = '7.9.0.0'
  s.summary = 'Bojian iOS discovery banner bridge for the supplied CSJ SDK.'
  s.homepage = 'https://www.csjplatform.com/'
  s.license = { :type => 'Proprietary', :text => 'CSJ SDK usage is subject to the vendor license.' }
  s.author = 'Bojian'
  s.source = { :path => '.' }
  s.platform = :ios, '15.0'
  s.source_files = 'Classes/*.{h,m}'
  s.public_header_files = 'Classes/*.h'
  sdk = 'vendor/union_platform_iOS_7.9.0.0/SDK'
  s.vendored_frameworks = "#{sdk}/BUAdSDK.xcframework", "#{sdk}/CSJMediation.xcframework"
  s.resources = "#{sdk}/CSJAdSDK.bundle"
  s.frameworks = 'UIKit', 'MapKit', 'WebKit', 'MediaPlayer', 'CoreLocation', 'AdSupport', 'CoreMedia', 'AVFoundation', 'CoreTelephony', 'StoreKit', 'SystemConfiguration', 'MobileCoreServices', 'CoreMotion', 'Accelerate', 'AudioToolbox', 'JavaScriptCore', 'Security', 'CoreImage', 'ImageIO', 'QuartzCore', 'CoreGraphics', 'CoreText', 'SpriteKit'
  s.weak_frameworks = 'AppTrackingTransparency', 'DeviceCheck', 'CoreML', 'CoreHaptics'
  s.libraries = 'c++', 'resolv', 'z', 'sqlite3', 'bz2', 'xml2', 'iconv', 'c++abi'
  s.dependency 'Flutter'
  s.requires_arc = true
end
