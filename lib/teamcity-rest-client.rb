require 'open-uri'
require 'rexml/document'
require 'set'

module TeamcityRestClient
  
  Project = Struct.new(:teamcity, :name, :id, :href) do
    def build_types
      teamcity.build_types.find_all { |bt| bt.project_id == id }
    end
    
    def builds
      bt_ids = Set.new(build_types.collect(&:id))
      teamcity.builds.find_all { |b| bt_ids.include? b.build_type_id }
    end
  end
  
  BuildType = Struct.new(:id, :name, :href, :project_name, :project_id, :web_url)
  
  Build = Struct.new(:id, :number, :status, :build_type_id, :start_date, :href, :web_url) do
    def success?
      status == :SUCCESS
    end
  end

  class HttpBasicAuthentication
    def initialize host, port, user, password
      @host, @port, @user, @password = host, port, user, password
    end

    def get path
      open(url(path), :http_basic_authentication => [@user, @password]).read
    end

    def url path
      "http://#{@host}:#{@port}/httpAuth#{path}"
    end  
    
    def to_s
      "HttpBasicAuthentication #{@user}:#{@password}"
    end
  end

  class Open
    def initialize host, port
      @host, @port = host, port
    end

    def get path
      open(url(path)).read
    end

    def url path
      "http://#{@host}:#{@port}#{path}"
    end
    
    def to_s
      "No Authentication"
    end
  end
end

class REXML::Element
  def av name
    attribute(name).value
  end
  
  def av_or name, otherwise
    att = attribute(name) 
    att ? att.value : otherwise
  end
end

class Teamcity
  
  attr_reader :host, :port, :authentication
  
  def initialize host, port, user = nil, password = nil
    @host, @port = host, port
    if user != nil && password != nil
      @authentication = TeamcityRestClient::HttpBasicAuthentication.new host, port, user, password
    else
      @authentication = TeamcityRestClient::Open.new host, port
    end
  end
  
  def project spec
    field = spec =~ /project\d+/ ? :id : :name  
    project = projects.find { |p| p.send(field) == spec }
    raise "Sorry, cannot find project with name or id '#{spec}'" unless project
    project
  end
  
  def projects
    doc(get('/app/rest/projects')).elements.collect('//project') do |e| 
      TeamcityRestClient::Project.new(self, e.av("name"), e.av("id"), url(e.av("href")))
    end
  end
  
  def build_types
    doc(get('/app/rest/buildTypes')).elements.collect('//buildType') do |e| 
      TeamcityRestClient::BuildType.new(e.av("id"), e.av("name"), url(e.av("href")), e.av('projectName'), e.av('projectId'), e.av('webUrl'))
    end
  end
  
  def builds
    doc(get('/app/rest/builds').gsub(/&buildTypeId/,'&amp;buildTypeId')).elements.collect('//build') do |e|
      TeamcityRestClient::Build.new(e.av('id'), e.av('number'), e.av('status').to_sym, e.av('buildTypeId'), e.av_or('startDate', ''), url(e.av('href')), e.av('webUrl'))
    end
  end
  
  def to_s
    "Teamcity @ http://#{host}:#{port}"
  end

  private
  def doc string
    REXML::Document.new string
  end

  def get path
    result = @authentication.get(path)
    raise "Teamcity returned html, perhaps you need to use authentication??" if result =~ /.*<html.*<\/html>.*/im
    result
  end
  
  def url path
    @authentication.url(path)
  end
end
