# encoding: utf-8
require "rubygems"
require "bundler"
Bundler.require
require 'pathname'
require 'rake'
require 'rake/hooks'
require 'rake/clean'

YMLFM = /(\A---\n(?<yaml>(.|\n|\r)*?)\n---\n)*(?<content>(.|\n|\r)+)/
# Dir.glob('lib/tasks/*.rake').each { |r| load r}
@@DOMAIN = ""
@@BASE_URL = "/"
# Rake.application.options.trace_rules = true
@INPUT = "in"
@OUTPUT = "out"

file 'Rakefile'
@config = 'config.rb'
file @config => 'Rakefile' do
  puts "initializing config.rb..."
  sh %Q[echo ''>>#{@config}]
end
load @config if File.file?(@config)

class Beard < Mustache
  def base
    return @@BASE_URL
  end
  def domain
    return @@DOMAIN
  end
end

@MAINMETA = "#{@OUTPUT}/meta.yaml"

# compass doesn't like having nothing to do...
defaultSCSS = "#{@INPUT}/style.scss"
file defaultSCSS do
  sh "echo '' >> #{defaultSCSS}"
end

def pathswap(src,output_prefix="",input_prefix=@INPUT)
  src.sub(input_prefix,output_prefix)
end

dirs = [@OUTPUT+"/"]+pathswap(FileList["#{@INPUT}/**/*/"],@OUTPUT)
# ^ since directory tasks use 'mkdir -p ...', make sure the @OUTPUT comes first
# so that it can get a .clobberthis file too

def addClobberDir(dir)
  directory dir # initialize a basic directory task
  directory dir do # modify it to create .clobberthis file for new directory
    cmd = "echo ''>> #{dir+".clobberthis"}"
    sh cmd
    puts cmd
  end
end

dirTasks = []
dirs.each do |dir|
  addClobberDir dir
  dirTasks << dir
end

task :till => dirTasks

clobberdirs = FileList["#{@OUTPUT}/**/.clobberthis"].pathmap("%d")
CLOBBER.include clobberdirs

# gather metadata about each specimen
sources = FileList["#{@INPUT}/**/*"]
uris = sources.collect{|e| pathswap(e)}.pathmap("%X")
exts = sources.pathmap("%x")

theme = "theme.mustache"
feedTemplate = "feed.mustache"
file theme
task :template => theme do
  @template = File.read(theme)
end

fileTasks = []
metaTasks = []
sources.zip(uris,exts).each do |source,uri,ext|
  next if File.directory? source

  meta = @OUTPUT+uri+ext+".meta.yaml"
  metaSource = @INPUT+uri+ext+".meta.yaml"
  src = File.read(source)
  local_outpath = @OUTPUT+uri+ext
  info = { 'uri' => uri+ext}
  sourceinfo = {}
  if File.exists? metaSource
    file metaSource
    sourceinfo = YAML.load(File.read(metaSource))
  end
  info = info.knit(sourceinfo)
  content = {}
  case ext
  when ".html"
    src = "<!DOCTYPE html>\n"+src
    h = Nokogiri.parse(src)
    info["title"] = h.css("title").remove.inner_text
    info["links_to"] = h.xpath("//a").collect{|a|a.attribute("href").value}.uniq
    info["uri"] = uri
    info["date"] = h.xpath("//time").inner_html
    content["main"] = h.css("body").inner_html
    content["head"] = h.css("head").inner_html
    content["navigation"] = !info["links_to"].empty? || !info["tags"].to_s.strip.empty? ? info["links_to"].collect{|uri|"<li><a href=#{uri}>#{uri}</a></li>"}.join : nil
    info["summary"] = h.css("summary").inner_html if h.css("summary")
  when ".md"
    src = YMLFM.match(src)
    info = info.knit(YAML.load(src["yaml"])) if src["yaml"]
    info["uri"] = uri
    content["main"] = RDiscount.new(src["content"]).to_html
    content["head"] = ""
    h = Nokogiri.parse("<!DOCTYPE html>"+content["main"])
    info["summary"] = h.css("summary").inner_html if h.css("summary")
    info["links_to"] = h.xpath("//a").collect{|a|a.attribute("href").value}.uniq
    content["navigation"] = !info["links_to"].empty? || !info["tags"].to_s.strip.empty? ? info["links_to"].collect{|uri|"<li><a href=#{uri}>#{uri}</a></li>"}.join : nil
    local_outpath = @OUTPUT + uri + ".html"
  when ".scss"
    local_outpath = @OUTPUT + uri + ".css"
    # puts local_outpath
    file local_outpath => [source] do
      # puts File.exists? local_outpath
      sh "compass compile --sass-dir #{@INPUT} --css-dir #{@OUTPUT} --force"
    end
    fileTasks << local_outpath
  when ".yaml"
    #idk
  else
    file local_outpath => [source] do
      sh "ln -rs '#{source}' '#{local_outpath}'" if !File.exist?(local_outpath)
    end
    fileTasks << local_outpath
  end

  info["date"] = Chronic.parse info["date"] if info["date"]
  info["updated"] = Chronic.parse info["updated"] if info["updated"]
  if info["tags"]
    info["tags"].map!{|t| t.strip}
    # puts info["tags"].inspect
    info["tags"].delete(nil)
    info["tags"].delete("")
    info["original_tags"] = info["tags"].clone
    info["original_tags"].map! do |t|
      {t=>t.to_url}
    end
    info["tags"].map!{|t| t.to_url}
  end

  if ext == ".html" || ext == ".md"
    prereqs = [source]
    if File.exists? metaSource
      prereqs.push metaSource
    end

    file meta => prereqs do
      File.write(meta,info.knit(content).to_yaml)
    end
    metaTasks << meta

    # puts final
    file local_outpath => [:template,source,@MAINMETA] do
      m = YAML.load(File.read(@MAINMETA))
      themed = Beard.render(@template,info.knit(content).knit(m))
      # sh "rm #{source}"
      File.write(local_outpath,themed)
    end
    fileTasks << local_outpath
  end
end

(fileTasks+metaTasks).each do |t|
  file t => [@config,File.dirname(t)+"/"]
end


CLOBBER.include fileTasks
CLEAN.include metaTasks

file @MAINMETA => metaTasks do
  siteMetaSource = @INPUT+"/meta.yaml"
  mainMeta = File.exist?(siteMetaSource) ? YAML.load(File.read(siteMetaSource)) : {}
  mainMeta = mainMeta.knit({"posts"=>[],"site"=>{}})
  metaTasks.each do |m|
    m = YAML.load(File.read(m))
    mainMeta["posts"] << m
  end
  mainMeta["posts"].sort!{|e,f| f["date"].to_i <=> e["date"].to_i}
  tags = mainMeta["posts"].collect{|e| e["tags"]}.flatten.uniq
  tags.delete(nil)
  tags.delete("")
  mainMeta["site"]["tags"] = tags
  File.write(@MAINMETA, mainMeta.to_yaml)
end
CLEAN.include @MAINMETA
task :meta => @MAINMETA

tagsDir = "#{@OUTPUT}/tags/"
addClobberDir tagsDir
CLOBBER.include FileList[tagsDir+"*.xml"]

navigatorTemplate = "navigator.mustache"
file navigatorTemplate do
  sh "echo ''>>#{navigatorTemplate}"
end
navigator = "#{@OUTPUT}/tags/index.html"
file navigator => [tagsDir,@MAINMETA,navigatorTemplate] do
  m = YAML.load(File.read(@MAINMETA))
  navpage = Beard.render( File.read(navigatorTemplate), m)
  File.write(navigator,navpage)
end
CLOBBER.include navigator

task :navigator => navigator

file feedTemplate
mainFeed = "#{@OUTPUT}/feed.xml"
CLOBBER.include mainFeed

task :feed => [@MAINMETA] do
  m = YAML.load(File.read(@MAINMETA))
  tags = m["site"]["tags"]
  tags.each do |tag|
    tagFeed = tagsDir+tag+".xml"
    file tagFeed => [@MAINMETA,tagsDir] do
      haveTag = m["posts"].find_all do |e|
        e['tags'] ? e['tags'].map{|t| t.to_url}.include?(tag) : false
      end
      puts haveTag
      feed = Beard.render( File.read(feedTemplate), 'posts' => haveTag )
      File.write(tagFeed, feed)
    end
    Rake::Task[tagFeed].invoke
  end

  file mainFeed => [@MAINMETA,feedTemplate] do
    feedData = {'posts' => m["posts"]}
    m = YAML.load(File.read(@MAINMETA))
    feed = Beard.render(File.read(feedTemplate),feedData.knit({'site'=>m["site"]}))
    File.write(mainFeed, feed)
  end
  Rake::Task[mainFeed].invoke
end

task :files => fileTasks

task build: [:feed,:files,:navigator]
