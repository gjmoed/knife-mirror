# -*- encoding: utf-8 -*-

$:.unshift(File.dirname(__FILE__) + '/lib')
require 'knife-mirror/version'

Gem::Specification.new do |s|
  s.name = 'knife-mirror'
  s.version = KnifeMirror::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = 'Knife support for mirroring Chef Supermarket contents'
  s.description = s.summary
  s.authors = ['G.J. Moed']
  s.email = 'gmoed@kobo.com'
  s.files = `git ls-files`.split("\n")
  s.homepage = 'https://github.com/gjmoed/knife-mirror'
  s.licenses = ['Apache-2.0']
  # s.required_ruby_version = '>= 1.9.1'
  s.add_dependency('chef', ['>= 0.10.10'])
  s.require_paths = ['lib']
end
