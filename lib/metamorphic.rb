require "metamorphic/version"
require "yaml/store"
require "rake"
require "rake/clean"
require "knit"
require "mustache"
require "metamorphic/morph"
require "metamorphic/meta"

# class Metamorphosis < Mustache
#   extend Forwardable
#   attr_accessor :meta
#   def_delegators :@meta, :[], :[]=
#
# end

include Metamorphic
