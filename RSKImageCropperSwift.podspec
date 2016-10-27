Pod::Spec.new do |s|
  s.name          = 'RSKImageCropperSwift'
  s.version       = '1.5.1.swift'
  s.summary       = 'An image cropper for iOS like in the Contacts app with support for landscape orientation.'
  s.homepage      = 'https://github.com/ruslanskorb/RSKImageCropper'
  s.license       = { :type => 'MIT', :file => 'LICENSE' }
  s.authors       = { 'Ruslan Skorb' => 'ruslan.skorb@gmail.com' }
  s.source        = { :git => 'https://github.com/tapz/RSKImageCropper.git', :tag => s.version.to_s }
  s.platform      = :ios, '9.0'
  s.source_files  = 'RSKImageCropper/*.{swift}'
  s.resources     = 'RSKImageCropper/RSKImageCropperStrings.bundle'
  s.frameworks    = 'QuartzCore', 'UIKit'
  s.requires_arc  = true
end
