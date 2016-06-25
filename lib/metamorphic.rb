require "metamorphic/version"
require "rake"
require "rake/clean"

module Metamorphic
  YAMLFM = /(\A---\n(?<yaml>(.|\n|\r)*?)\n---\n)*(?<content>(.|\n|\r)+)/
  def clobberDirectory(dir)
    directory dir # initialize a basic directory task
    directory dir do # modify it to create .clobberthis file for new directory
      cmd = "echo ''>> #{dir+".clobberthis"}"
      sh cmd; puts cmd
      CLOBBER.include dir
    end
  end

  def self.included(base)
    clobberdirs = FileList["#{@OUTPUT}/**/.clobberthis"].pathmap("%d")
    CLOBBER.include clobberdirs
  end
end
