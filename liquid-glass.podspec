require "json"
pkg = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "liquid-glass"
  s.version      = pkg["version"]
  s.summary      = pkg["description"]
  s.license      = pkg["license"]
  s.author       = { "liquid-glass" => "noreply@example.com" }
  s.homepage     = "https://github.com/example/liquid-glass"
  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => "https://github.com/example/liquid-glass.git", :tag => "#{s.version}" }
  s.source_files = "ios/**/*.{h,m,mm,swift}"
  # .metal is compiled into the pod's default.metallib by CocoaPods.
  s.resources    = "ios/**/*.metal"
  s.swift_version = "5.0"
  s.dependency "React-Core"
end
