# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'metamorphic/version'

Gem::Specification.new do |spec|
  spec.name          = "metamorphic"
  spec.version       = Metamorphic::VERSION
  spec.authors       = ["Micah"]
  spec.email         = ["fitchmicah@gmail.com"]

  spec.summary       = "Meta-morphosize human readable meta-data into wonderous digital creations."
  spec.description   = "Various tools for collecting, transforming and creating with metadata.  Designed to build static pages with Rake... useful for much more!"
  spec.homepage      = "http://github.com/micahscopes/metamorphic"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "stringex"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-remote"
  spec.add_development_dependency "pry-nav"
  spec.add_dependency "rake"
  spec.add_dependency "knit", "~> 0.1"
end
