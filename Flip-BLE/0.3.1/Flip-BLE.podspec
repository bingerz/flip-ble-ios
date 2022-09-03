#
# Be sure to run `pod lib lint Flip-BLE.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Flip-BLE'
  s.version          = '0.3.1'
  s.summary          = 'An easy-to-use Bluetooth development framework for the iOS platform.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  This framework is already in production. After several iterations,
  it has been relatively stable and reliable. This framework was developed
  to increase the ease of use and stability of using the iOS Bluetooth API.
                       DESC

  s.homepage         = 'https://github.com/bingerz/flip-ble-ios'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'hanbing0604@aliyun.com' => 'Bingerz' }
  s.source           = { :git => 'https://github.com/bingerz/flip-ble-ios.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'Flip-BLE/Classes/**/*'
  
  s.requires_arc = true
  
  # s.resource_bundles = {
  #   'Flip-BLE' => ['Flip-BLE/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
