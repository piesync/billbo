require 'rake/testtask'

Rake::TestTask.new(:spec) do |t|
  t.libs = ['app', 'lib', 'spec']
  t.test_files = FileList['spec/**/*_spec.rb']
end

task :default => :spec
