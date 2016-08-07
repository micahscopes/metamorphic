require "knit"

module Metamorphic
  class YML < YAML::Store
    private
    def needs_refreshment
       return @last_cache <= File.mtime(path) rescue true
    end
    def refresh
      if !File.exists? path
        @cache = {}
      end
      if needs_refreshment
        needed_refreshment = true
        h = {}
        transaction(true){|d| roots.each{|k| h[k] = d[k]}}
        # puts ("h"+h.inspect)
        @cache = h
      end
      # make sure all the refreshment is finished before time stamping
      @last_cache = Time.new-1 if needed_refreshment # with a small buffer
      return needed_refreshment
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

    def transaction(readonly=false,&blk)
      # todo: make this happen in a single write by writing a lower level
      # version mimicking the the YAML::Store transaction method.
      # todo: get front matter detection for free from YAML::Store parsing?
      if File.exists?(path) && (!readonly || needs_refreshment)
        src = File.read(path)
        yamlfm = src.scan YAMLFM
        # puts yamlfm
        # don't do the regex if the file hasn't changed since last read
        metadata = yamlfm[0][1] rescue nil
        r = /\-\-\-(?:\n|\r|.)*?(?:\-\-\-\s*?.*?\n)((.|\n|\r|\Z)*)/
        @data = src.match(r)[1] rescue (metadata ? nil : src)
        if !readonly && (metadata == nil || metadata.empty?)
          File.write(path,"")
        end
      end
      result = super(readonly,&blk) rescue {}
      if !readonly && result != {}
        if @data
          f = File.open(path,'a') if @data
          f.write("---\n")
          f.write(@data)
          f.close
        end
      end
      return result
    end
  end

  class Meta < SimpleDelegator
    include Enumerable
    extend Forwardable
    def_delegators :@yml, :root_hash, :transaction, :content

    protected
    attr_accessor :branch,:yml
    def self.about(source_path,target_meta_path=nil,frontmatter=false,suffix=".meta.yaml")
      if target_path
        fm = YAMLFM(File.read(source_path))
        m = initialize(target_meta_path)
      end
    end
    def chain(obj,key)
      m = self.clone
      m.branch = @branch+[key]
      m.__setobj__(obj)
      return m
    end

    public
    def __getobj__
      return @branch.inject(root_hash){|h,k| h[k]}
    end
    def initialize(src,obj=nil,branch=[])
      @src = src
      @branch = branch
      @yml = YML.new(src)
      if obj
        super obj
      else
        super root_hash
      end
    end
    def [](key=nil)
      if key == nil
        __setobj__(root_hash)
        return self
      end
      # key = key.to_s if key.class == Symbol
      # puts key
      res = @branch.inject(root_hash){|h,k| h[k]}[key]
      return chain(res,key)
    end

    def <<(contents)
      contents = [contents] unless contents.respond_to? :each
      res = nil
      transaction(false) do |d|
        unless @branch == []
          upto = @branch.clone
          last = upto.pop

          m = upto.inject(d){|h,k| h[k]}
          m[last] = [m[last]] unless m[last].respond_to? :each
          res = m[last].knit(contents)
          m[last] = res
        else
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
      return chain(val,key)
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
