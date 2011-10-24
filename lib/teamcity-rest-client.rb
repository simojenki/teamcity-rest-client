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

end

class REXML::Element
  def att name
    attribute(name).value
  end
end

class Teamcity
  
  attr_reader :host, :port, :user, :password
  
  def initialize host, port, user = nil, password = nil
    @host, @port, @user, @password = host, port, user, password
  end
  
  def project spec
    field = spec =~ /project\d+/ ? :id : :name  
    project = projects.find { |p| p.send(field) == spec }
    raise "Sorry, cannot find project with name or id '#{spec}'" unless project
    project
  end
  
  def projects
    doc(get(url('/app/rest/projects'))).elements.collect('//project') do |e| 
      TeamcityRestClient::Project.new(self, e.att("name"), e.att("id"), url(e.att("href")))
    end
  end
  
  def build_types
    doc(get(url('/app/rest/buildTypes'))).elements.collect('//buildType') do |e| 
      TeamcityRestClient::BuildType.new(e.att("id"), e.att("name"), url(e.att("href")), e.att('projectName'), e.att('projectId'), e.att('webUrl'))
    end
  end
  
  def builds
    doc(get(url('/app/rest/builds')).gsub(/&buildTypeId/,'&amp;buildTypeId')).elements.collect('//build') do |e|
      TeamcityRestClient::Build.new(e.att('id'), e.att('number'), e.att('status').to_sym, e.att('buildTypeId'), e.att('startDate'), url(e.att('href')), e.att('webUrl'))
    end
  end

  def url path
    if user != nil && password != nil
      "http://#{user}:#{password}@#{host}:#{port}#{path}"
    else
      "http://#{host}:#{port}#{path}"
    end
  end
  
  private
  def doc string
    REXML::Document.new string
  end
  
  def get url
    open(url).read
  end
end