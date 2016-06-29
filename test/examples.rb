require 'bundler'
require 'rspec'
require 'rake'
require 'rake/clean'
Bundler.require

RSpec.describe Metamorphic do
  example "filtering" do
    m = Morph.filter{|x| x > 3}
    expect( m.with 2 ).to eq( [] )
    expect( m.with 4 ).to eq( [4] )

    m = Morph.new.filter!{|x| x > 3}
    expect( m.with 2 ).to eq( [] )
    expect( m.with 4 ).to eq( [4] )
  end

  example "transform then filter" do
    m = Morph.into{|t| t+2}.filter{|x| x > 3}
    expect( m.with 0 ).to eq( [] )
    expect( m.with 2 ).to eq( [4] )
  end

  example "filter then transform" do
    m = Morph.filter{|d| d!="grey duck"}.then{|d| d.gsub("grey","blue")}
    expect( m.with ["grey duck","grey skies"] ).to eq( ["blue skies"] )
    expect( m.with ["duck","duck","grey duck"] ).to eq( ["duck","duck"] )
  end

  example "cocoon from a file path" do
    self.extend Rake::DSL

    sh "rm -rf test/this"
    @file = "test/this/is/a/test/file.txt"
    cocoon(@file)
    Rake::Task[:cocoon].invoke
    expect(File.exist?(File.dirname(@file))).to be_truthy

    Rake::Task[:clobber].invoke
    expect(File.exist?(File.dirname(@file))).to be_falsy
  end

  example "filter paths then transform pathnames" do
    self.extend Rake::DSL

    file = "test/AAA/temporary/file.txt"
    dirs = FileList["test/AAA/dirs","test/AAA/moredirs","test/AAA/temporary"]
    dirs.each{|d| sh "mkdir -p #{d}"}
    sh "echo 'wow'>>#{file}"
    all = [file]+dirs

    filesOnly = Morph.paths.filter!{|a| File.file? a}
    expect(filesOnly.with all).to eq [file]

    dirsOnly = Morph.paths.filter!{|a| File.directory? a}
    expect(dirsOnly.with all).to eq dirs

    transplant = Morph.transplant('test/AAA','test/BBB')
    expect(filesOnly.then(transplant).with all).to eq [file.gsub("AAA","BBB")]

    sh "rm -r test/AAA"
  end

  example "meta yaml (easy YAMLStore transactions)" do
    require 'stringex'
    self.extend Rake::DSL
    d = 'test/recipes/'
    sh "rm -r #{d}" if File.exist? d
    directory d; Rake::Task[d].invoke
    sZ = Morph.into{|src| src.gsub("s","ZZZZZ!")}
    zZz = sZ.then{|src| src.gsub("ZZZ","ZzZz")}
    recipes = zZz.with do |src,recipe|
      uri = d+src.to_url+".yaml"
      meta(uri) do |y|
        y["ingredients"] = recipe
      end
      expect(File.exists? uri).to be_truthy
      expect(meta(uri)["ingredients"]).to eq recipe
    end

    dishes = ["veggies","soy sauce","thyme"]
    recipes[*dishes]
  end
end
