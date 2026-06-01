lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'micro/authorization/version'

Gem::Specification.new do |spec|
  spec.name         = 'u-authorization'
  spec.version      = Micro::Authorization::VERSION
  spec.authors      = ['Rodrigo Serradura']
  spec.email        = ['rodrigo.serradura@gmail.com']

  spec.summary      = 'Authorization library and role managment'
  spec.description  = 'Simple authorization library and role managment for Ruby.'
  spec.homepage     = 'https://github.com/serradura/u-authorization'
  spec.license      = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/serradura/u-authorization'
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '~> 13.0'
end
