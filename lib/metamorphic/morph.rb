module Metamorphic
  class Morph
    @@chpath = lambda{|i,o,s| s.pathmap("%{^*#{i},#{o}}p")}.curry
    @@id = lambda{|x| x}
    @@ary_id = lambda{|sources| [sources].flatten}
    def initialize(pre=nil,post=nil,chain=nil,&witheach)
      # puts chain.inspect
      # @filter = filter ? filter : lambda{|src| true}
      # chain = [Morph.new(&chain)].flatten if chain.class == Proc
      @chain = chain ? chain : []
      @pre = pre ? pre : @@ary_id
      @post = post ? post : @@ary_id
      @witheach = witheach ? witheach : @@id
    end

    def self.static
      return Morph.new()
    end
    def self.into(&blk)
      return Morph.new(&blk)
    end

    def paths!(frm=nil,to=nil,&blk)
      self.instance_eval do
        if frm || to
          frm = frm ? frm : ""
          to = to ? to : ""
          chpath = @@chpath[frm,to]
          @witheach = blk ? lambda{|s| chpath[blk[s]]} : chpath
        elsif blk
          @witheach = blk
        end
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

    def transformation
      return lambda do |x|
        prex = pre[x]
        y = post[prex.map{|j| @witheach[j]}]
        return [prex,y]
      end
    end
    def chain
      return [self.transformation]+@chain.map{|m| m.class==Morph ? m.chain : m}.flatten
    end
    def doChainWith(x,returnAll=false)
      originals = []
      results = []
      chain = self.chain
      latest = nil

      throw("Error: self.chain should not empty") if chain.empty?
      chain.each do |t|
        x2y = t[x]
        # puts x2y.inspect
        if x2y[0].length != originals.length
          originals = x2y[0]
        end
        latest = originals.zip(x2y[1]).select{|k| k[0]!=nil && k[1]!=nil}
        x = latest.map{|k| k[1]}
        # puts latest
        results << x
      end
      if returnAll
        return latest.map{|k| k[0]}.zip(*results.reverse)
      else
        return latest.map{|k| k[1]}
      end
    end

    public
    def from(sources=nil,&blk)
      exe = lambda do |sources|
        if blk
          return doChainWith(sources,true).map{|x| yield(*x)}
        else
          return doChainWith(sources)
        end
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
      if nextTask
        return Morph.new(nil,nil,[self,nextTask],&thenWithEach)
      elsif thenWithEach
        return Morph.new(nil,nil,[self,Morph.into(&thenWithEach)])
      else
        return lambda{|later| m.then(later)}
      end
    end
    alias :into :then

    def filter!(&blk)
      pre = self.pre.clone
      @pre = lambda{|src| pre[src].map{|s| blk[s] ? s : nil} }
      return self
    end

    def filter(&blk)
      return self.then(Morph.new.filter!(&blk))
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
end
