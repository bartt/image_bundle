# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "image_bundle/version"

Gem::Specification.new do |s|
  s.name        = "image_bundle"
  s.version     = ImageBundle::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bart Teeuwisse"]
  s.email       = ["bart@thecodemill.biz"]
  s.homepage    = "https://github.com/bartt/image_bundle"
  s.summary     = %q{ImageBundle bundles individual images into a single sprite and CSS rules to match}
  s.description = %q{ImageBundle adds a helper to Ruby on Rails to create image sprites and matching CSS rules on the fly. Overhead is minimal as sprites are cached. ImageBundle is rendering framework agnostic.}
  s.license     = "LGPL-2"

  s.rubyforge_project = "image_bundle"
  s.add_dependency "actionpack", ">= 3.0.7", "< 6.2.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
