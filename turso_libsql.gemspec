Gem::Specification.new do |s|
  s.name        = 'turso_libsql'
  s.version     = '0.1.0'
  s.summary     = 'libSQL'
  s.description = 'libSQL Ruby SDK'
  s.authors     = ['Levy Albuquerque']
  s.email       = 'levy@turso.tech'
  s.files       = [
    'lib/libsql.rb',
    'lib/lib/x86_64-unknown-linux-gnu/liblibsql.so',
    'lib/lib/aarch64-unknown-linux-gnu/liblibsql.so',
    'lib/lib/universal2-apple-darwin/liblibsql.dylib'
  ]
  s.homepage = 'https://rubygems.org/gems/turso_libsql'
  s.license = 'MIT'
end
