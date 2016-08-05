require 'bundler'
require 'rspec'
require 'rake'
require 'rake/clean'
Bundler.require

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
  example "knit into key" do
    f = "test/meta.yaml"
    Rake::sh "echo '' > #{f}"
    m = Meta.new(f)
    m[1] = {}
    m[1] << {:o=>:k}
    expect(m[1][:o]).to eq(:k)

    m << {:o=>:k}
    expect(m[:o]).to eq(:k)

    m[:b] = [1,2,3]
    m[:b] << [4]
    expect(m[:b]).to eq([1,2,3,4])
  end
  example "knit one meta store into another" do
    f = "test/f.yaml"
    g = "test/g.yaml"
    Rake::sh "echo '' > #{f}"
    Rake::sh "echo '' > #{g}"
    g = meta(g)
    g["abc"] = "efg"
    f = meta(f)
    f["xyz"] = "qrs"
    f << g
    expect(f["abc"]).to eq("efg")
    expect(f["xyz"]).to eq("qrs")
  end
end
