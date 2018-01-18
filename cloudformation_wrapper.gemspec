$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'cloudformation_wrapper/version'

Gem::Specification.new do |s|
  s.name                    = 'cloudformation_wrapper'
  s.version                 = CloudFormationWrapper::VERSION
  s.authors                 = ['Ted Armstrong']
  s.email                   = ['theodorecarmstrong@gmail.com']
  s.homepage                = 'https://github.com/Shockolate/CloudFormationWrapper'
  s.summary                 = 'Easy deployment of AWS CloudFormation stacks'
  s.description             = 'Deploys and Manages AWS CloudFormation.'
  s.files                   = Dir['lib/**/*.rb']
  s.platform                = Gem::Platform::RUBY
  s.require_paths           = ['lib']
  s.license                 = 'Apache-2.0'
  s.required_ruby_version   = '>= 2.1'
  s.add_runtime_dependency('aws-sdk-cloudformation', '~> 1')
end
