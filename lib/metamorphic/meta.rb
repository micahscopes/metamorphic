require "knit"

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
  class YML < YAML::Store
    private
    def needs_refreshment
       return @last_cache <= File.mtime(path) rescue true
    end
    def refresh
      if !File.exists? path
        @cache = {}
        @cache_hash = nil
      end
      if needs_refreshment
        h = {}
        transaction(true){|d| roots.each{|k| h[k] = d[k]}}
        @cache = h
        @last_cache = Time.new-1
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
      @last_cache = Time.new(0)
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

    def content=(str)

    end

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
            result = super(readonly,&blk) rescue Exception
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

  class Meta < SimpleDelegator
    include Enumerable
    extend Forwardable
    def_delegators :@yml, :path, :root_hash, :transaction, :content, :has_yaml_suffix

    protected
    attr_accessor :branch,:yml
    def self.about(source_path,kargs={})
      kargs = kargs.merge({:src => source_path})
      return Meta.new(kargs)
    end
    public
    def __getobj__
      return @branch.inject(root_hash){|h,k| h[k]}
    end

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
    def clone
      cl = Object.instance_method(:clone).bind(self)
      new = cl.call
      obj = __getobj__.clone rescue __getobj__
      new.__setobj__(obj)
      new
    end
    def scan(src=@src,data_key=@data_key)
      if src == nil || src == path
        return false
      end
      # puts src
      # puts path

      previous_hash = @last_hash
      src = meta(src)
      self << src
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
    def <<(contents)
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
    def []=(key,val)
      transaction(false) do |d|
        m = @branch.inject(d){|h,k| h[k]}
        m[key] = val
      end
      return descend(key,val)
    end

    def each(*args,&blk)
      obj = __getobj__
      transaction(false) do |d|
        m = @branch.inject(d){|h,k| h[k]}
        if obj.respond_to? :keys
          obj.each do |k,v|
            blk[k,v]
          end
        else
          obj.each do |k|
            blk[k]
          end
        end
      end
      return __getobj__
    end
  end
end
