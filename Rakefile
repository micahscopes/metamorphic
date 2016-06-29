require "bundler/gem_tasks"

tests = FileList["test/*"]
task :spec do
  tests = FileList["test/*.{rb,spec,feature,test}"]
  tests.each do |t|
    sh "rspec #{t}"
  end
end
task :default => :spec
