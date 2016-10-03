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
    m[1] ** {:o=>:k}
    expect(m[1][:o]).to eq(:k)

    m ** {:o=>:k}
    expect(m[:o]).to eq(:k)

    m[:b] = [1,2,3]
    m[:b] ** [4]
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
    f ** g
    expect(f["abc"]).to eq("efg")
    expect(f["xyz"]).to eq("qrs")
  end
  example "knit one meta store into another's child" do
    f = "test/f.yaml"
    g = "test/g.yaml"
    Rake::sh "echo '' > #{f}"
    Rake::sh "echo '' > #{g}"
    g = meta(g)
    g[1] = {2=>{3=>{4=>5}}}
    f = meta(f)
    f["xyz"] = "qrs"
    g[1][2] ** f
    expect(g[1][2]["xyz"]).to eq("qrs")
  end
  example "another knitting example" do
    f = "test/f.yaml"
    g = "test/g.yaml"
    Rake::sh "echo '' > #{f}"
    Rake::sh "echo '' > #{g}"
    m = meta(f); n = meta(g)
    m ** {"ary"=>[],"hsh"=>{}} # `a ** b` <=> `a.knit! b`
    n["stuff"] = {1=>2,3=>4,5=>["abc","def"]}
    m["ary"] ** n["stuff"]
  end
  example "get yaml front matter" do
    # todo...
  end
  example "preserve yaml front matter and data" do
    s=<<-DOC
a: b
c: d
---
lorem ipsum bla bla bla
DOC

    path = 'test/some_very_nice.md'
    File.write(path,s)
    m = meta path
    m['c'] = 'd'
    expect(m['c']).to eq('d')
    s = "---\n"+s
    expect(File.read(path)).to eq(s)

    File.write(path,s)
    m['c'] = 'd'
    expect(File.read(path)).to eq(s)
  end
  example "meta from source" do
    content = "abc"
    s=<<-DOC
a: b
c: d
---
DOC
s = s+content
    path = 'test/some_very_nice.md'
    src = path+".meta.yaml"
    File.write(path,s)
    File.write(src,"")
    m = Meta.about(path)
    expect(m["a"]).to eq("b")
    expect(m["content"]).to eq("#{content}")

    content2 = "12345"

    f = File.open(path,"a")
    f.write(content2)
    f.close
    expect(m["content"]).to eq("#{content}")
    m.scan
    expect(m["content"]).to eq("#{content}#{content2}")

    f = File.open(path,"a")
    f.write(content2)
    f.close
    expect(m["content"]).to eq("#{content}#{content2}")
    m.scan
    expect(m["content"]).to eq("#{content}#{content2}#{content2}")
  end
end
