require 'rake/testtask'

Rake::TestTask.new(:spec) do |t|
  t.libs = ['app', 'lib', 'spec']
  t.test_files = FileList['spec/**/*_spec.rb']
end

task :environment do
  require './config/environment'
end

task :console => :environment do
  require 'irb'
  require 'irb/completion'
  ARGV.clear
  IRB.start
end

task :default => :spec

# Task that generates PDF's for all invoices that were not
# generated already.
task :generate_pdfs => :environment do
  PdfService.new.generate_missing
end
