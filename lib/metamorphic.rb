require "metamorphic/version"
require "yaml/store"
require "rake"
require "rake/clean"
# require "mustache"
require "metamorphic/morph"
require "metamorphic/meta"

module Metamorphic
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

include Metamorphic
