require "knit"

module Metamorphic
  class YML < YAML::Store
    def initialize(*args,&blk)
      @last_cache = Time.new(0)
      super
    end

    def root_hash
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
    end
  end

  class Meta < SimpleDelegator
    include Enumerable
    extend Forwardable
    def_delegators :@yml, :root_hash, :transaction

    protected
    attr_accessor :path,:yml

    def chain(obj,key)
      m = self.clone
      m.path = @path+[key]
      m.__setobj__(obj)
      return m
    end

    public
    def __getobj__
      return @path.inject(root_hash){|h,k| h[k]}
    end
    def initialize(yml,obj=nil,path=[])
      @path = path
      @yml = YML.new(yml)
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
      res = @path.inject(root_hash){|h,k| h[k]}[key]
      return chain(res,key)
    end

    def <<(contents)
      contents = [contents] unless contents.respond_to? :each
      res = nil
      transaction(false) do |d|
        unless @path == []
          upto = @path.clone
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
      # key = key.to_s if key.class == Symbol
      # val = val.to_s if val.class == Symbol
      # puts("value",val)
      transaction(false) do |d|
        m = @path.inject(d){|h,k| h[k]}
        m[key] = val
      end
      return chain(val,key)
    end

    def each(*args,&blk)
      obj = __getobj__
      transaction(false) do |d|
        m = @path.inject(d){|h,k| h[k]}
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
#
# class Metamorphosis2 < Mustache
#   def initialize(m)
#     @meta = m
#   end
#   class << self; alias :with :new; end
#   def with(m)
#     @meta = m
#   end
#
#   def method_missing(method_name, *args, &block)
#     method_name = method_name.to_s
#     attribute = method_name.chomp("=")
#     # puts method_name
#     set = args[0] != nil
#     if instance_variable_defined? "@#{attribute}"
#       if set
#         instance_variable_set "@#{attribute}", args[0]
#       else
#         instance_variable_get "@#{attribute}"
#       end
#     else
#       if set
#         meta(@meta) do |m|
#           m[attribute] = args[0]
#         end
#       else
#         result = meta(@meta)[attribute]
#         return result
#       end
#     end
#   end
# end
