require "metamorphic/version"
require "yaml/store"
require "rake"
require "rake/clean"
require "knit"

module Metamorphic
  class Morph
    @@pathmap = lambda{|i,o,src| src.pathmap("%{^*#{i},#{o}}p")}.curry
    @@id = lambda{|x| x}
    @@ary_id = lambda{|sources| [sources].flatten}

    def initialize(pre=nil,post=nil,&witheach)
      # @filter = filter ? filter : lambda{|src| true}
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

    protected
    def pre
      pre = @pre.clone
      return @pathmapper ? lambda{|s| FileList[pre[s]]} : pre
    end

    protected
    def post
      post = @post.clone
      return @pathmapper ? lambda{|s| FileList[post[s]]} : post
    end

    public
    def from(sources=nil,&blk)
      exe = lambda do |sources|
        sources = pre[sources]
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
    alias :each :from

    def then(nextTask=nil,&thenWithEach)
      if nextTask && nextTask.class == Morph
        pre = lambda{|sources| nextTask.pre[self.from[sources]]}
        todo = nextTask.witheach
        if thenWithEach
          post = lambda{|results| nextTask.post[thenWithEach[results]]}
        else
          post = nextTask.post
        end
        return Morph.new(pre,post,&todo)
      elsif nextTask == nil
        pre = lambda{|sources| self.from[sources]}
        return Morph.new(pre,&thenWithEach)
      end
    end
    alias :into :then

    def filter!(&blk)
      pre = self.pre.clone
      @pre = lambda{|src| pre[src].select(&blk) }
      return self
    end

    def filter(&blk)
      nu = self.then.filter!(&blk)
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


#### module methods

  def meta(path,&blk)
    store = YAML::Store.new(path)
    if blk
      return store.transaction(&blk)
    else
      return lambda {|key| store.transaction{|d| d[key]}}
    end
  end

  YAMLFM = /(\A---\n(?<yaml>(.|\n|\r)*?)\n---\n)*(?<content>(.|\n|\r)+)/

  COCOON = FileList[]
  def cocoon(path,&blk)
    task :cocoon
    # creates a disposable directory (if directory doesn't exist already)
    if path.is_a? Hash
      dep = path.values[0]
      path = path.keys[0]
    end

    parent = "#{File.dirname(path)}/"
    # puts "--"
    # puts parent
    cocoon parent if (!File.exists?(parent) && !COCOON.include?(parent))

    dir = path.clone.chomp!("/")
    unless dir
      # puts path
      file path => parent
      return COCOON
    end

    return COCOON if COCOON.include?(path)
    directory(path => parent)

    if path
      directory path => dep
    else
      directory path
    end

    COCOON << path
    directory path do
      cmd = "echo ''>> #{dir}/.cocoon"
      sh cmd; #puts cmd
      CLOBBER.include path
    end
    task :cocoon => path
    if blk
      directory(path,&blk)
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
