Gem::Specification.new do |s|
  s.version = "0.1.3"
  s.author = "Sven Riedel"
  s.files = %w[ README.md CHANGELOG ] +
             Dir.glob( "bin/**/*" ) +
             Dir.glob( "lib/**/*" )
  s.name = "sideq"
  s.bindir = "bin"
  s.executables = [ "sideq" ]

  s.platform = Gem::Platform::RUBY
  s.require_paths = [ "lib" ]
  s.summary = "Access the sidekiq api from the command line"
  s.email = "sr@gimp.org"
  s.homepage = "https://github.com/sriedel/sideq"
  s.description = "A command line tool to access the sidekiq api methods, making actions available to shell scripts and command prompts"
  s.licenses = [ "GPL-2.0" ]

  s.add_runtime_dependency 'sidekiq', '~> 4.1', '>= 4.1.0'
end
