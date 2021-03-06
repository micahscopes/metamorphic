require "knit"
# require "pry"
# require "pry-remote"
# require "pry-nav"

module Metamorphic
  def parse_yaml_stream(str,lim=1)
    blocks = []
    current = nil
    n = 0
    str.each_line do |l|
      is_delim = l[0,3] == "---"
      if is_delim && (!lim || n<lim)
        if current
          blocks<<current
          n+=1
          # next if n==lim
        end
        info = l.clone
        info.slice!(0,3)
        info.strip!
        if n<lim
          current = {:info=>info,:head=>l+"\n",:body=>""}
        else
          current = {:head=>l,:body=>""}
        end
      else
        if current
          current[:body]<<l
        else
          current = {:head=>"",:body=>l}
        end
      end
    end
    blocks << current if current
    return blocks
  end

  DATAKEY = "content"

  # A wrapper for YAML::Store.  Supports YAML front matter.
  # Does caching based on file modification time.
  class YML < YAML::Store
    private
    def needs_refreshment
       return @cache_timestamp <= File.mtime(path) rescue true
    end
    def refresh
      if !File.exists? path
        @cache = {}
      end
      if needs_refreshment
        h = {}
        transaction(true){|d| roots.each{|k| h[k] = d[k]}}
        @cache = h
        @cache_timestamp = Time.new-1
        needed_refreshment = true
      end
      return needed_refreshment
    end

    attr_reader :last_hash
    protected
    def has_yaml_suffix
      [".yaml",".yml"].index path.pathmap("%x")
    end

    public
    def initialize(*args,&blk)
      @cache_timestamp = Time.new(0)
      super
    end

    def root_hash
      refresh
      return @cache
    end

    def content
      refresh
      return @data
    end

    # def content=(str)
    #
    # end

    def transaction(readonly=false,data=nil,&blk)
      if File.exists?(path) && (!readonly || needs_refreshment)
        raw = File.read(path)
        parsed = parse_yaml_stream(raw)
        # puts parsed.inspect
        # puts "PARSED INTO #{parsed.length} BLOCKS"
        if parsed.length == 1
          p = parsed[0]
          @data = data ? data : p[:body]
          if !readonly # then something may have changed, write data (content)
            # File.write(path,"") if !readonly
            result = begin
              super(readonly,&blk)
            rescue PStore::Error
              {}
            end
            if (data &&  result != Exception) || (result == Exception) && !has_yaml_suffix
              # result = super(readonly,&blk) rescue Exception
              f = File.open(path,"a")
              f.write(p[:head]+@data)
              f.close
            end
          else
            result = super(readonly,&blk) rescue Exception
          end
        elsif parsed.length == 2
          p = parsed[1]
          data = p[:body] if !data
          @data = data ? data : p[:body]
          result = super(readonly,&blk) rescue Exception
          if !readonly # then something may have changed, write data (content)
            if @data && result != Exception && !has_yaml_suffix
              f = File.open(path,"a")
              p[:head] = "---"+p[:head] if p[:head][0,3]!="---"
              f.write(p[:head]+@data)
              f.close
            end
          end
        elsif parsed.length == 0
          result = super(readonly,&blk) rescue Exception
          if @data && result != Exception && !has_yaml_suffix
            f = File.open(path,"a")
            f.write("---\n"+@data)
            f.close
          end
        end
      else
        result = super(readonly,&blk) rescue Exception
      end
      # puts result
      result = {} if result == Exception
      return result
    end
  end

  # Delegator for a Metamorphic::YML store,
  # providing a direct interface to an arbitrary branch
  # of a data structure.
  class Meta < SimpleDelegator
    include Enumerable
    extend Forwardable
    # @!method path
    #   @see YML#path
    # @!method transaction
    #   @see YML#transaction
    # @!method root_hash
    #   @see YML#root_hash
    # @!method root_hash
    #   @see YML#content
    # @!method has_yaml_suffix
    #   @see YML#has_yaml_suffix
    def_delegators :@yml, :path, :root_hash, :transaction, :content

    protected
    def_delegators :@yml, :has_yaml_suffix
    attr_accessor :branch,:yml
    def self.about(source_path,kargs={})
      kargs = kargs.merge({:src => source_path})
      return Meta.new(kargs)
    end
    def __getobj__
      return @branch.inject(root_hash){|h,k| h[k]}
    end
    public
    def initialize(pth=nil,kargs={})
      defaults = {:branch=>[],:data_key=>DATAKEY,:suffix=>".meta.yaml"}

      if pth.class == Hash
        kargs = pth
        kargs = defaults.merge(kargs)
        pth = kargs[:path]
      else
        kargs = defaults.merge(kargs)
      end
      @src = kargs[:src]

      src_is_yaml = [".yaml",".yml"].index @src.pathmap("%x") rescue false
      if src_is_yaml
        pth = kargs[:src] unless pth
        @src = nil
      else
        pth = kargs[:src]+kargs[:suffix] unless pth
      end

      @data_key = kargs[:data_key]
      @branch = kargs[:branch]
      @yml = YML.new(pth)

      scan if @src
      super __getobj__
    end

    def descend(key,obj=nil)
      m = self.clone
      m.branch = @branch+[key]
      m.__setobj__(obj) if obj
      return m
    end
    def ascend
      # puts self
      m = self.clone
      m.branch = @branch[0,@branch.length-1]
      return m
    end
    def root
      m = self.clone
      m.branch = []
      return m
    end
    def initialize_clone(other)
      # cl = Object.instance_method(:clone).bind(self)
      obj = other.__getobj__.clone rescue other__getobj__
      __setobj__(obj)
    end
    def scan(src=@src,data_key=@data_key)
      if src == nil || src == path
        return false
      end
      # puts src
      # puts path

      previous_hash = @last_hash
      src = meta(src)
      self ** src
      if has_yaml_suffix
        # puts "putting data in yaml with key '#{data_key}'"
        self[data_key] = src.content
      end
      return previous_hash != @last_hash
    end
    def [](key=nil)
      if key == nil
        __setobj__(root_hash)
        return self
      end
      # key = key.to_s if key.class == Symbol
      # puts key
      # res = @branch.inject(root_hash){|h,k| h[k]}[key]
      return descend(key)
    end
    def **(contents)
      # knit
      # throw(Exception.new("WTF")) if false
      contents = [contents] unless contents.respond_to? :each
      contents = contents.to_h if contents.respond_to? :keys
      k = @branch.last
      if k
        ascend[k]=__getobj__.knit(contents)
      else
        transaction(false) do |d|
          contents.each do |k,v|
            d[k] = v
          end
        end
      end
      return self
    end
    def <<(contents)
      # push
      # throw(Exception.new("WTF")) if false
      contents = [contents] unless contents.respond_to? :each
      contents = contents.to_h if contents.respond_to? :keys
      k = @branch.last
      if k
        ary = __getobj__
        ary = ary.respond_to?(:push) ? ary : [ary]
        ascend[k]=ary.push(contents)
      else
        # ::Kernel.binding.pry
        transaction(false) do |d|
          contents.each do |k,v|
            d[k] = v
          end
        end
      end
      return self
    end
    def []=(key,val)
      transaction(false) do |d|
        m = @branch.inject(d){|h,k| h[k]}
        m[key] = val
      end
      return descend(key,val)
    end

    def each(*args,&blk)
      obj = __getobj__.clone rescue __getobj__
      return obj.each(*args,&blk)
    end
  end

  def meta(path,&blk)
    if blk
      return Meta.new(path).transaction(&blk)
    else
      return Meta.new(path)
    end
  end
end
