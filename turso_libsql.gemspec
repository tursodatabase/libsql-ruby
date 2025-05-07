Gem::Specification.new do |s|
  s.name        = 'turso_libsql'
  s.version     = '0.2.0'
  s.summary     = 'libSQL'
  s.description = 'libSQL Ruby SDK'
  s.authors     = ['Levy Albuquerque']
  s.email       = 'levy@turso.tech'
  s.files       = [
    'lib/libsql.rb',
    'lib/lib/x86_64-unknown-linux-gnu/liblibsql.so',
    'lib/lib/aarch64-unknown-linux-gnu/liblibsql.so',
    'lib/lib/aarch64-apple-darwin/liblibsql.dylib'
  ]
  s.homepage = 'https://rubygems.org/gems/turso_libsql'
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.3'
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/tursodatabase/libsql-ruby/issues',
    'source_code_uri' => 'https://github.com/tursodatabase/libsql-ruby'
  }
  s.add_runtime_dependency 'ffi', '~> 1.17'
  s.add_development_dependency 'rspec', '~> 3.10'
end
