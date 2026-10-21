Pod::Spec.new do |s|
  s.name             = 'pangle_ads'
  s.version          = '0.1.0'
  s.summary          = '博简穿山甲 GroMore 原生广告通道（开屏 / Banner）'
  s.description      = <<-DESC
Flutter 与穿山甲 GroMore iOS SDK 之间的最小桥接层，只暴露开屏与 Banner 两种能力。
                       DESC
  s.homepage         = 'https://github.com/fahnzjan/bojian-mobile'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Bojian' => 'dev@kelance.cn' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  # 穿山甲 ADN + GroMore 聚合。版本请与「接入与测试 → SDK → IOS」页面显示的一致；
  # 若 pod install 提示找不到，按该页面给出的 Pod 名称与版本替换下面两行。
  s.dependency 'Ads-CN'
  s.dependency 'Ads-Mediation-CN'
  s.platform = :ios, '13.0'
  s.static_framework = true
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
