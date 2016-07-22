require 'bundler'
require 'rspec'
require 'rake'
require 'rake/clean'
Bundler.require

# RSpec.describe Metamorphosis do
#   example "set and get attributes dynamically from yaml" do
#     m = Metamorphosis.new("test/meta.yaml")
#     m.junk="fluff"
#     expect(m.junk).to eq("fluff")
#
#     m.junk "treasure"
#     expect(m.junk).to eq("treasure")
#
#     m.junk 'a' => 'b'
#     expect(m.junk['a']).to eq('b')
#   end
# end


RSpec.describe Meta do
  example "get/set by key" do
    f = "test/meta.yaml"
    Rake::sh "echo '' > #{f}"
    m = Meta.new(f)
    m["a"] = "b"
    expect(m["a"]).to eq("b")
  end
  example "chaining getters" do
    f = "test/meta.yaml"
    Rake::sh "echo '' > #{f}"
    m = Meta.new(f)
    h = {2=>{3=>4}}
    m[1] = nil
    m[1] = h
    # 100000.times{m[1][2][3]}
    expect(m[1]).to eq(h)
    expect(m[1][2]).to eq({3=>4})
  end
  example "setting on a nested key" do
    f = "test/meta.yaml"
    Rake::sh "echo '' > #{f}"
    m = Meta.new(f)
    h = {2=>{3=>4}}
    m[1] = nil
    m[1] = h
    b = "buckle my shoe"
    m[1][2] = b
    m[1][2]

    expect(m[1][2]).to eq(b)
  end
end
