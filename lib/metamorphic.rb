require "metamorphic/version"
require "rake"
require "rake/clean"

module Metamorphic
  class Morph
    def initialize(i=nil,o=nil,&blk)
      @i = i
      @o = o
      @filter = nil
      @blk = blk
      if @blk == nil
        @blk = lambda{|path| path.pathmap("%{^#{@i}*,#{@o}}d/%f")}
      end
    end

    def self.into(&blk)
      return Morph.new(&blk)
    end

    def self.transplant(i,o)
      return Morph.new(i,o)
    end
    class << self; alias :move :transplant; end

    def from(src,&blk)
      sources = FileList[src]
      results = FileList[]
      if @filter
        sources.select!(&@filter)
      end
      sources.each do |path|
        if blk && (@i || @o)
          results << yield(path.to_s,@blk[path].to_s)
        else
          results << @blk[path].to_s
        end
      end
      return results
    end
    alias :with :from

    def then(&blk)
      return Morph.new {|src| yield(from(src))}
    end

    def filter!(&blk)
      @filter = blk
      return self
    end

    def filter(&blk)
      return self.clone.instance_eval { @filter = blk }
    end

    def self.filter(&blk)
      return Morph.new.filter!(&blk)
    end

    def by_ext!(exts)
      exts = [exts].flatten
      return filter!{|p| exts.include? p.pathmap("%x")}
    end

    def by_ext(exts)
      return self.clone.by_ext!(exts)
    end

    def self.by_ext(exts)
      return Morph.new.by_ext!(exts)
    end
  end

  def meta(path,&blk)
    store = YAML::Store.new(path)
    if blk
      return store.transaction(&blk)
    else
      return lambda {|key| store.transaction{|d| d[key]}}
    end
  end

  YAMLFM = /(\A---\n(?<yaml>(.|\n|\r)*?)\n---\n)*(?<content>(.|\n|\r)+)/
  def clobberDirectory(dir,&blk)
    # creates a disposable directory (if directory doesn't exist already)
    directory dir
    directory dir do
      cmd = "echo ''>> #{dir+".clobberthis"}"
      sh cmd; puts cmd
      CLOBBER.include dir
    end
    if blk
      directory(dir,&blk)
    end
  end

  def self.included(base)
    # check for existing clobberable directories... and prepare to clobber them!
    clobberdirs = FileList["#{@OUTPUT}/**/.clobberthis"].pathmap("%d")
    CLOBBER.include clobberdirs
  end
end

include Metamorphic
