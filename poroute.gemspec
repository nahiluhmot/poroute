require_relative 'lib/poroute/version'

Gem::Specification.new do |spec|
  spec.name = 'poroute'
  spec.version = Poroute::VERSION
  spec.authors = ['Tom Hulihan']
  spec.email = ['hulihan.tom159@gmail.com']

  spec.summary = 'Routing with Plain Old Ruby Objects'
  spec.homepage = 'https://github.com/nahiluhmot/poroute'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`
      .split("\x0")
      .reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.require_paths = %w[lib]

  spec.add_development_dependency 'pry', '~> 0.12'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.80.1'
end
