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
      nu = self.clone
      nu.instance_eval { @filter = blk }
      return nu
    end

    def self.filter(&blk)
      return Morph.new.filter!(&blk)
    end

    def select_ext!(exts)
      exts = [exts].flatten
      return filter!{|p| exts.include? p.pathmap("%x")}
    end

    def self.select_ext(exts)
      return Morph.new.select_ext!(exts)
    end
  end

  YAMLFM = /(\A---\n(?<yaml>(.|\n|\r)*?)\n---\n)*(?<content>(.|\n|\r)+)/
  def clobberDirectory(dir)
    # creates a disposable directory if directory doesn't exist
    directory dir # initialize a basic directory task
    directory dir do # modify it to create .clobberthis file for new directory
      cmd = "echo ''>> #{dir+".clobberthis"}"
      sh cmd; puts cmd
      CLOBBER.include dir
    end
  end

  def self.included(base)
    clobberdirs = FileList["#{@OUTPUT}/**/.clobberthis"].pathmap("%d")
    CLOBBER.include clobberdirs
  end
end

include Metamorphic
