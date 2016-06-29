require "metamorphic/version"
require "yaml/store"
require "rake"
require "rake/clean"

module Metamorphic
  COCOON = FileList[]
  class Morph
    @@pathmap = lambda{|i,o,src| src.pathmap("%{^*#{i},#{o}}p")}.curry
    @@path_filter = lambda{|p| FileList[p]}
    @@id = lambda{|x| x}
    @@ary_id = lambda{|sources| [sources].flatten}

    def initialize(filter=nil,pre=nil,post=nil,&witheach)
      @filter = filter
      @pre = pre ? pre : @@ary_id
      @post = post ? post : @@ary_id
      @witheach = witheach ? witheach : @@id
    end

    def self.into(&blk)
      return Morph.new(&blk)
    end

    def paths!(i=nil,o=nil,&blk)
      self.instance_eval do
        @i = i
        @o = o
        @witheach = blk ? blk : @@id
        @pathmapper = true
      end
      return self
    end

    def paths(*args,&blk)
      ### this method allows us to chain path and non-path Morphs together
      nu = self.clone
      nu.instance_eval do
        @pathmapper = true
      end
      if(blk)
        return self.class.paths(*args){ |src| yield(nu.from(src)) }
      else
        return self.class.paths(*args){ |src| nu.from(src) }
      end
    end

    def self.paths(*args,&blk)
      return Morph.new.paths!(*args,&blk)
    end

    class << self; alias :move :paths; end
    class << self; alias :transplant :paths; end

    def witheach
      return @pathmapper ? lambda{|src| @@pathmap[@i][@o][@witheach[src]]} : @witheach
    end

    def from(sources=nil,&blk)
      # this method does all the heavy lifting
      pre = @pathmapper ? @@path_filter : @pre
      post = @pathmapper ? @@path_filter : @post

      exe = lambda do |sources|
        sources = pre[sources]
        sources.select!(&@filter) if @filter
        if blk
          results = sources.map{|src| yield(src,self.witheach[src])}
        else
          results = sources.map{|src| self.witheach[src]}
        end
        return post[results]
      end
      if sources
        return exe[sources]
      else
        return lambda{|*s| exe[s]}
      end
    end
    alias :with :from
    alias :as :from

    def then(task=nil,&thenwitheach)
      if task.class == Morph
        todo = lambda{|src| task.witheach[self.witheach[src]]}
      else
        todo = lambda{|src| thenwitheach[self.witheach[src]]}
      end
      return Morph.new(&todo)
    end

        # def meta!(src,opts={:type => :yaml},&blk)
        #   # takes the sources and opens a yamlstore transaction
        #
        # end

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


# module methods

  def meta(path,&blk)
    store = YAML::Store.new(path)
    if blk
      return store.transaction(&blk)
    else
      return lambda {|key| store.transaction{|d| d[key]}}
    end
  end

  YAMLFM = /(\A---\n(?<yaml>(.|\n|\r)*?)\n---\n)*(?<content>(.|\n|\r)+)/
  def cocoon(dir,&blk)
    # creates a disposable directory (if directory doesn't exist already)
    if dir.is_a? Hash
      dep = dir.values[0]
      dir = dir.keys[0]
    end

    dir.chomp!("/")
    return COCOON if COCOON.include? dir

    if dep
      directory dir => dep
    else
      directory dir
    end

    COCOON << dir
    parent = "#{File.dirname(dir)}/"
    cocoon parent if (!File.exists?(parent) && !COCOON.include?(parent))
    directory(dir => parent)

    directory dir do
      cmd = "echo ''>> #{dir}/.cocoon"
      sh cmd; #puts cmd
      CLOBBER.include dir
    end
    task :cocoon => dir
    if blk
      directory(dir,&blk)
    end

    return COCOON
  end

  def self.included(base)
    # check for existing clobberable directories... and prepare to clobber them!
    cocoon = FileList["#{@OUTPUT}/**/.cocoon"].pathmap("%d")
    CLOBBER.include cocoon
  end
end

include Metamorphic
