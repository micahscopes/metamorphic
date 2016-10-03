require 'bundler'
require 'rspec'
require 'rake'
require 'rake/clean'
Bundler.require

RSpec.describe Metamorphic do
  example "cocoon a previously non-existing directory" do
    COCOON.clear
    CLOBBER.clear
    self.extend Rake::DSL
    sh 'rm -rf test/cozy_cocoon'
    COZY_COCOON = 'test/cozy_cocoon'
    cocoon "#{COZY_COCOON}/"

    Rake::Task[:clobber_cocoons].reenable
    Rake::Task[:cocoon].reenable
    Rake::Task[:cocoon].invoke
    expect(File.exist?(COZY_COCOON)).to be_truthy
    expect(File.exist?("#{COZY_COCOON}/.cocoon")).to be_truthy
  end
  example "cocooned directories will be clobbered" do
    COCOON.clear
    CLOBBER.clear
    self.extend Rake::DSL

    sh "mkdir #{COZY_COCOON}/BUTTERFLY"
    expect(File.exist?("#{COZY_COCOON}/BUTTERFLY/.cocoon")).to be_falsey
    expect(File.exist?("#{COZY_COCOON}/BUTTERFLY/")).to be_truthy

    Rake::Task[:clobber_cocoons].reenable
    Rake::Task[:clobber].reenable
    Rake::Task[:clobber].invoke
    expect(File.exist?(COZY_COCOON)).to be_falsey
  end

  example "nested cocoon from a file path" do
    COCOON.clear
    CLOBBER.clear
    self.extend Rake::DSL

    sh "rm -rf test/this"
    sh "mkdir test/this"
    NESTED_FILE = "test/this/is/a/test/file.txt"
    cocoon(NESTED_FILE)

    Rake::Task[:clobber_cocoons].reenable
    Rake::Task[:cocoon].reenable
    Rake::Task[:cocoon].invoke
    expect(File.exist?(File.dirname(NESTED_FILE))).to be_truthy
  end

  example "clobber directories only if they contain a .cocoon" do
    COCOON.clear
    CLOBBER.clear
    self.extend Rake::DSL

    Rake::Task[:clobber_cocoons].reenable
    Rake::Task[:clobber].reenable
    Rake::Task[:clobber].invoke
    expect(File.exist?(File.dirname(NESTED_FILE))).to be_falsy
    expect(File.exist?("test/this")).to be_truthy
  end
end
