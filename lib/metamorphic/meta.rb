module Metamorphic
  class YML < YAML::Store
    def initialize(*args,&blk)
      @last_cache = Time.new(0)
      super
    end

    def base_hash
      if !File.exists? path
        return {}
      end
      if @last_cache <= File.mtime(path)
        h = {}
        @last_cache = Time.new-1 # add a small buffer
        transaction(true){|d| roots.each{|k| h[k] = d[k]}}
        @cache = h
      end
      return @cache
      # puts @cache
    end

    # def transaction(readonly=true,&blk)
    #   if !readonly
    #     super(readonly) do |d|
    #       &blk[d]
    #
    #     end
    #     rtime = Time.new
    #   end
    # end
  end
  
  class Meta < SimpleDelegator
    include Enumerable
    extend Forwardable
    def_delegators :@yml, :base_hash, :transaction

    protected
    attr_accessor :path,:yml

    def chain(obj,key)
      m = self.clone
      m.path = @path+[key]
      m.__setobj__(obj)
      return m
    end

    public
    def initialize(yml,obj=nil,path=[])
      @path = path
      @yml = YML.new(yml)
      if obj
        super obj
      else
        super(base_hash)
      end
    end
    def [](key)
      key = key.to_s if key.class == Symbol
      # puts key
      res = @path.inject(base_hash){|h,k| h[k]}[key]
      return chain(res,key)
    end

    def <<(key,contents)
      key = key.to_s if key.class == Symbol
      val = val.to_s if contents.class == Symbol
      contents = [contents] unless contents.respond_to? :each
      transaction(false) do |d|
        m = @path.inject(d){|h,k| h[k]}
        res = contents.knit(m[key])
        # puts("setting",key,res)
        m[key] = res
      end
      return chain(res,key)
    end
    def []=(key,val)
      key = key.to_s if key.class == Symbol
      val = val.to_s if val.class == Symbol
      # puts("value",val)
      transaction(false) do |d|
        m = @path.inject(d){|h,k| h[k]}
        m[key] = val
      end
      return chain(val,key)
    end
    def each(*args,&blk)
      base_hash.each(&blk)
    end
  end

  def meta(path,&blk)
    if blk
      return Meta.new(path).transaction(&blk)
    else
      return Meta.new(path)
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

class Metamorphosis2 < Mustache
  def initialize(m)
    @meta = m
  end
  class << self; alias :with :new; end
  def with(m)
    @meta = m
  end

  def method_missing(method_name, *args, &block)
    method_name = method_name.to_s
    attribute = method_name.chomp("=")
    # puts method_name
    set = args[0] != nil
    if instance_variable_defined? "@#{attribute}"
      if set
        instance_variable_set "@#{attribute}", args[0]
      else
        instance_variable_get "@#{attribute}"
      end
    else
      if set
        meta(@meta) do |m|
          m[attribute] = args[0]
        end
      else
        result = meta(@meta)[attribute]
        return result
      end
    end
  end
end