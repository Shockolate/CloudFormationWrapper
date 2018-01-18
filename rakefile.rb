require 'rake'
require 'rake/clean'
require 'rake/testtask'

require './lib/cloudformation_wrapper/version'

ROOT = File.dirname(__FILE__)
REPORTS_DIR = File.join(ROOT, 'reports')
DOC_DIR = File.join(ROOT, 'doc')


CLEAN.include('*.gem')
CLEAN.include(REPORTS_DIR)
CLEAN.include(DOC_DIR)

desc 'Builds the Gem.'
task :build => [:clean, :lint, :create]

task :commit_job => [:clean, :lint, :create]

desc 'Runs RuboCop'
task :lint do
  puts `rubocop -a -F`
end

task :create => [:clean] do
  puts "Creating Gem: #{CloudFormationWrapper::Version}"
  puts `gem build cloudformation_wrapper.gemspec`
end

task :uninstall do
  puts "Uninstalling all: #{NAME}"
  puts `gem uninstall #{NAME} --all`
end

desc 'Bumps and pushes new minor version.'
task :bump_minor do
  puts 'Bumping minor.'
  cmd = 'gem bump --version minor --tag --push'
  raise 'Error bumping minor version!' unless system(cmd)
end

desc 'Bumps and pushes new major version.'
task :bump_major do
  puts 'Bumping major.'
  cmd = 'gem bump --version major --tag --push'
  raise 'Error bumping major version!' unless system(cmd)
end

desc 'Bumps and pushes new patch version.'
task :bump_patch do
  puts 'Bumping patch.'
  cmd = 'gem bump --version patch --tag --push'
  raise 'Error bumping patch version!' unless system(cmd)
end