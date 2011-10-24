require_relative 'spec_helper'

module TeamcityRestClient
  
  describe Project do
    before :each do
      @bt11 = stub('bt11', :id => "bt11", :name => "project1-build1", :project_id => "project1")
      @bt12 = stub('bt12', :id => "bt12", :name => "project1-build2", :project_id => "project1")
      @bt21 = stub('bt21', :id => "bt21", :name => "project2-build1", :project_id => "project2")
    
      @bt11_1 = stub('bt11_1', :id => "1", :build_type_id => "bt11")
      @bt11_2 = stub('bt11_2', :id => "2", :build_type_id => "bt11")
      @bt12_33 = stub('bt12_33', :id => "33", :build_type_id => "bt12")
      @bt21_666 = stub('bt21_666', :id => "666", :build_type_id => "bt21")
    
      @tc = stub('teamcity', :build_types => [@bt11, @bt12, @bt21], :builds => [@bt11_1, @bt11_2, @bt12_33, @bt21_666])
      @project1 = Project.new @tc, "Project 1", "project1", "http://www.example.com"
    end
  
    describe "asking it for it's build types" do
      before :each do
        @build_types = @project1.build_types
      end
    
      it "should have only those for project 1" do
        @build_types.should == [@bt11, @bt12]
      end
    end
  
    describe "asking it for it's builds" do
      before :each do
        @builds = @project1.builds
      end
    
      it "should have only builds for project 1" do
        @builds.should == [@bt11_1, @bt11_2, @bt12_33]
      end
    end
  end

  describe HttpBasicAuthentication do
    before :each do
      @host, @port, @user, @password = "auth.example.com", 2233, "john", "wayne"
      @auth = HttpBasicAuthentication.new @host, @port, @user, @password
      @io = stub(:read => "<xml/>")
    end
    
    describe "url" do
      it "should add /httpAuth to path" do
        @auth.url("/something").should == "http://auth.example.com:2233/httpAuth/something"
      end
    end
    
    describe "get" do
      it "should call open with http basic auth options" do
        @auth.should_receive(:open).with("http://auth.example.com:2233/httpAuth/somethingElse", :http_basic_authentication=>[@user, @password]).and_return(@io)
        @auth.get("/somethingElse")
      end
    end
  end
  
  describe Open do
    before :each do
      @host, @port = "auth.example.com", 2233
      @auth = Open.new @host, @port
      @io = stub(:read => "<xml/>")
    end
    
    describe "url" do
      it "should create valid url" do
        @auth.url("/something").should == "http://auth.example.com:2233/something"
      end
    end
    
    describe "get" do
      it "should call open with no auth options" do
        @auth.should_receive(:open).with("http://auth.example.com:2233/somethingElse").and_return(@io)
        @auth.get("/somethingElse")
      end
    end
  end

end

describe Teamcity do
  before :all do
    @sample_projects_xml = sample_xml "projects"
    @sample_builds_xml = sample_xml "builds"
    @sample_build_types_xml = sample_xml "buildTypes"
  end
  
  describe "specifying username and password" do
    before :each do
      @host, @port, @user, @password = "authtc.example.com", 8877, "bob", "marley"
      @authentication = mock('authentication')
      TeamcityRestClient::HttpBasicAuthentication.should_receive(:new).with(@host, @port, @user, @password).and_return(@authentication)
      @tc = Teamcity.new @host, @port, @user, @password
    end
    
    it "should create HttpBasicAuthetication" do
      @tc.authentication.should === @authentication
    end
  end

  describe "specifying no username and password" do
    before :each do
      @host, @port = "authtc.example.com", 8877
      @authentication = mock('authentication')
      TeamcityRestClient::Open.should_receive(:new).with(@host, @port).and_return(@authentication)
      @tc = Teamcity.new @host, @port
    end
    
    it "should create HttpBasicAuthetication" do
      @tc.authentication.should === @authentication
    end
  end
  
  describe "finding a specific project" do
    before :each do
      @tc = Teamcity.new "tc.example.com", 5678
      @project1 = stub('project1', :name => "First Project", :id => "project1")
      @project456 = stub('project456', :name => "Project 456", :id => "project456")
      @project3877 = stub('project3877', :name => "Some other project with a big number", :id => "project3877")
      @tc.stub(:projects).and_return [@project1, @project456, @project3877]
    end
    
    describe "by project name" do
      it "should return project with name First Project" do
        @tc.project("First Project").should === @project1
      end
      
      it "should return project with name Some other project with a big number" do
        @tc.project("Some other project with a big number").should === @project3877
      end
      
      it "should blowup when the project name doesnt exist" do
        lambda { @tc.project("bollocks") }.should raise_error "Sorry, cannot find project with name or id 'bollocks'"
      end
    end
    
    describe "by project id" do
      it "should return project with id project456" do
        @tc.project("project456").should === @project456
      end
      
      it "should return project with id project3877" do
        @tc.project("project3877").should === @project3877
      end
    end
  end
  
  describe "when authentication fails" do
    before :each do
      @host, @port = "fail.example.com", 1234
      @authentication = TeamcityRestClient::Open.new @host, @port
      TeamcityRestClient::Open.should_receive(:new).and_return(@authentication)
      fail_html = <<HTML

      <!DOCTYPE html>
      <html id="htmlId">
      something
      </html>  
HTML
      
      @authentication.should_receive(:get).with("/app/rest/buildTypes").and_return(fail_html)
      @tc = Teamcity.new @host, @port
    end
    
    it "should raise an error" do
      lambda { @tc.build_types }.should raise_error "Teamcity returned html, perhaps you need to use authentication??"
    end
  end
  
  describe "parsing xml feeds" do
    before :each do
      @host, @port = "tc.example.com", 1234
      @authentication = TeamcityRestClient::Open.new @host, @port
    end
    
    describe "projects" do
      before :each do
        xml = <<XML
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<projects>
  <project name="Amazon API client" id="project54" href="/app/rest/projects/id:project54"/>
  <project name="Apache Ant" id="project28" href="/app/rest/projects/id:project28"/>
</projects>        
XML
        @authentication.should_receive(:get).with("/app/rest/projects").and_return(xml)
        TeamcityRestClient::Open.should_receive(:new).and_return(@authentication)
        @tc = Teamcity.new @host, @port
        @projects = @tc.projects
      end
      
      it "should have 2" do
        @projects.length.should == 2
      end
      
      it "should have amazon project" do
        amazon = @projects[0]
        amazon.name.should == "Amazon API client"
        amazon.id.should == "project54"
        amazon.href.should == "http://tc.example.com:1234/app/rest/projects/id:project54"
      end
      
      it "should have ant project" do
        ant = @projects[1]
        ant.name.should == "Apache Ant"
        ant.id.should == "project28"
        ant.href.should == "http://tc.example.com:1234/app/rest/projects/id:project28"
      end
    end

    describe "buildTypes" do
      before :each do
        xml = <<XML
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<buildTypes>
  <buildType id="bt297" name="Build" href="/app/rest/buildTypes/id:bt297" 
    projectName="Amazon API client" projectId="project54" webUrl="http://teamcity.jetbrains.com/viewType.html?buildTypeId=bt297"/>
  <buildType id="bt296" name="Download missing jar" href="/app/rest/buildTypes/id:bt296" 
    projectName="Amazon API client" projectId="project54" webUrl="http://teamcity.jetbrains.com/viewType.html?buildTypeId=bt296"/>
</buildTypes>      
XML
        @authentication.should_receive(:get).with("/app/rest/buildTypes").and_return(xml)
        TeamcityRestClient::Open.should_receive(:new).and_return(@authentication)
        @tc = Teamcity.new @host, @port
        @build_types = @tc.build_types
      end
      
      it 'should have 2' do
        @build_types.length.should == 2
      end
      
      it "should have build bt297" do
        bt297 = @build_types[0]
        bt297.id.should == "bt297"
        bt297.name.should == "Build"
        bt297.href.should == "http://tc.example.com:1234/app/rest/buildTypes/id:bt297"
        bt297.project_name.should == "Amazon API client"
        bt297.project_id.should == "project54"
        bt297.web_url.should == "http://teamcity.jetbrains.com/viewType.html?buildTypeId=bt297"
      end
      
      it "should have build bt296" do
        bt296 = @build_types[1]
        bt296.id.should == "bt296"
        bt296.name.should == "Download missing jar"
        bt296.href.should == "http://tc.example.com:1234/app/rest/buildTypes/id:bt296"
        bt296.project_name.should == "Amazon API client"
        bt296.project_id.should == "project54"
        bt296.web_url.should == "http://teamcity.jetbrains.com/viewType.html?buildTypeId=bt296"
      end
    end
    
    describe "builds" do
      before :each do
        xml = <<XML
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<builds nextHref="/app/rest/builds?count=100&amp;start=100" count="100">
  <build id="56264" number="126" status="FAILURE" buildTypeId="bt212" startDate="20111021T123714+0400" href="/app/rest/builds/id:56264" 
    webUrl="http://teamcity.jetbrains.com/viewLog.html?buildId=56264&buildTypeId=bt212"/>
  <build id="56262" number="568" status="SUCCESS" buildTypeId="bt213" startDate="20111021T120639+0400" href="/app/rest/builds/id:56262" 
    webUrl="http://teamcity.jetbrains.com/viewLog.html?buildId=56262&buildTypeId=bt213"/>
</builds>
XML
        @authentication.should_receive(:get).with("/app/rest/builds").and_return(xml)
        TeamcityRestClient::Open.should_receive(:new).and_return(@authentication)
        @tc = Teamcity.new @host, @port
        @builds = @tc.builds
      end
      
      it "should have 2" do
        @builds.length.should == 2
      end
      
      it "should have build 56264" do
        build = @builds[0]
        build.id.should == "56264"
        build.number.should == "126"
        build.status.should == :FAILURE
        build.success?.should == false
        build.build_type_id.should == "bt212"
        build.start_date.should == "20111021T123714+0400"
        build.href.should == "http://tc.example.com:1234/app/rest/builds/id:56264"
        build.web_url.should == "http://teamcity.jetbrains.com/viewLog.html?buildId=56264&buildTypeId=bt212"
      end
      
      it "should have build 56262" do
        build = @builds[1]
        build.id.should == "56262"
        build.number.should == "568"
        build.status.should == :SUCCESS
        build.success?.should == true
        build.build_type_id.should == "bt213"
        build.start_date.should == "20111021T120639+0400"
        build.href.should == "http://tc.example.com:1234/app/rest/builds/id:56262"
        build.web_url.should == "http://teamcity.jetbrains.com/viewLog.html?buildId=56262&buildTypeId=bt213"
      end
    end
  end
end