require 'net/ssh'
require 'net/http'
require 'postgres-pr/connection'
require 'mswin32/ibm_db'
#require 'selenium-webdriver'
#require 'watir-webdriver'
require "yaml"


def initialize_var

	config = YAML.load_file('env_details.yaml')
	$conf_type = ""

	$url = config[$env]['url']
	$webapp_dir = config[$env]['webapp_dir']
	$tomcat_string = config[$env]['tomcat_string']
	
	$tenant = config[$env]['tenant']
	$tenant_Person = config[$env]['tenantPerson']
	$tenant_Organization = config[$env]['tenantOrganization']
	$service_Endpoint = config[$env]['serviceEndpoint']
	$ssh_user = config[$env]['ssh_user']
	$ssh_password = config[$env]['ssh_password']
	 
	$web_url = config[$env]['web_url']
	$person_file = config[$env]['person_file']
	$org_file = config[$env]['org_file']
	 
	$tenant_loc = config[$env]['tenant_loc']
  
end

def init_db(db_t)
	config = YAML.load_file('env_details.yaml')
	$db = db_t
	if(db_t == "db2")
		$conn_string = config[$env]['db2']['conn_string']
		$db_port = config[$env]['db2']['db_port']
		$db_username = config[$env]['db2']['db_username']
		$db_password = config[$env]['db2']['db_password']
		$db_name = config[$env]['db2']['db_name']
	elsif(db_t == "postgres")
		$conn_string = config[$env]['postgres']['conn_string']
		$db_port = config[$env]['postgres']['db_port']
		$db_username = config[$env]['postgres']['db_username']
		$db_password = config[$env]['postgres']['db_password']
		$db_name = config[$env]['postgres']['db_name']
	elsif(db_t == "oracle")
		$conn_string = config[$env]['oracle']['conn_string']
		$db_port = config[$env]['oracle']['db_port']
		$db_username = config[$env]['oracle']['db_username']
		$db_password = config[$env]['oracle']['db_password']
		$db_name = config[$env]['oracle']['db_name']
	end
	
	#$db = config[$env]['db']
	#$conn_string = config[$env]['conn_string']
	#$db_port = config[$env]['db_port']
	#$db_username = config[$env]['db_username']
	#$db_password = config[$env]['db_password']
	#$db_name = config[$env]['db_name']

end

def check_artifact(arguments)
	$artifact_list = ""
	arguments.each do |x|
		if x.include?("service") || x.include?("mdm-jms-bridge") || x.include?("datarules") || x.include?("ui-overlayed")
			$artifact_list = x
			puts "Modules to be deployed: #{$artifact_list}"
		end
	end

end

def check_buildno(arguments)
	$build_no = ""
	arguments.each do |x|
		if x.include?("bno_")
			$build_no = x.split(/_/)[1]
			puts "Build no: #{$build_no}"
		end
	end
end

def stop_server
	Net::SSH.start($url, $ssh_user, :password => $ssh_password) do |ssh|
		puts "Connected to #{$env} to stop the tomcat"
		output = ssh.exec!(" ps -ef|grep tomcat")
  
   
	# Number of Lines in output
	lines = output.split(/\n/)
	line_count = lines.size
	puts "Number of Lines = #{line_count}"

	items = Array.new
	
	lines.each do |line|
		if line.strip.include? $tomcat_string
			items = line.split(/\s+/)
		end
	end

	puts "Killing existing tomcat process id"
	process_id =  items[1]
	# Killing the tomcat process
	ssh.exec!("kill -9 #{process_id}")
	
	puts "Closing the ssh connection to #{$env}"
	end
end

def start_server
	Net::SSH.start($url, $ssh_user, :password => $ssh_password) do |ssh|
		puts "Connected to #{$env} to start the tomcat"

	puts "Starting tomcat"
	if $env == "abnapp-2" || $env == "abnapp" || $env == "mdm-dev-1"
		puts ssh.exec!("service tomcat6 start")
	else
		output = puts ssh.exec!("cd #{$webapp_dir}../bin; ./startup.sh")
		puts output
	end
	puts "Closing the ssh connection to #{$env}"	
	end
	
	check_server_up

end

def restart_server
	stop_server
	start_server
	check_server_up
end

def download_confFile
		Net::SSH.start($url, $ssh_user, :password => $ssh_password) do |ssh|

		puts "Going to /home/latest_config to delete existing stuff and download required configuration.zip file"
		ssh.exec!("rm -rf /home/latest_config; mkdir /home/latest_config")
		#ssh.exec!("cd /home/latest_config; rm -rf config/ configurations*.zip")
		
			if $repo_url.include?("repo")
				$build  = "HumanInference Reposiory"
				puts "Downloading configuration.zip  from #{$build}..............."
				puts ssh.exec!("cd /home/latest_config; wget http://repo.humaninference.com/content/groups/public/com/hi/cdi/configurations/#{$snapshot_version}/configurations-#{$snapshot_version}-all.zip")				
				ssh.exec!("cd /home/latest_config; unzip configurations-#{$snapshot_version}-all.zip")				
			else 
				puts "Downloading configuration.zip  from #{$build}..............."
				puts ssh.exec!("cd /home/latest_config; wget #{$repo_url}/#{$build}/#{$build_no}/com.hi.cdi%24configurations/artifact/com.hi.cdi/configurations/#{$snapshot_version}-SNAPSHOT/configurations-#{$snapshot_version}-SNAPSHOT-all.zip")
				
				ssh.exec!("cd /home/latest_config; unzip configurations-#{$snapshot_version}-SNAPSHOT-all.zip")
			end
		puts "Closing the ssh connection to #{$env}. Configuration has been downloaded and unzipped"
		end
		
		
end

def setup_conf (conf)
	$conf_type = conf
	Net::SSH.start($url, $ssh_user, :password => $ssh_password) do |ssh|
		puts "connection established"
		
		puts ssh.exec!("unalias cp")
		puts ssh.exec!("rm -rf #{$tenant_loc}/config")
		
		puts "Deploying #{$conf_type} configuration...."
		puts ssh.exec!("cp -rf /home/latest_config/config/#{$conf_type}/config #{$tenant_loc}/.")
		
		# Remove mode.cas only if it is non-cas enviorment
		if $env == "proc2"
			puts ssh.exec!("mv #{$tenant_loc}/config/repository/demo #{$tenant_loc}/config/repository/mdm4tc")
		elsif $env == "abnapp"
			puts ssh.exec!("mv #{$tenant_loc}/config/repository/demo #{$tenant_loc}/config/repository/appdemo")
			puts ssh.exec!("rm -rf #{$tenant_loc}/config/mode.cas")
		elsif $env == "abnapp-2"
			puts ssh.exec!("mv #{$tenant_loc}/config/repository/demo #{$tenant_loc}/config/repository/app2demo")
			puts ssh.exec!("rm -rf #{$tenant_loc}/config/mode.cas")
			
		else
			puts ssh.exec!("rm -rf #{$tenant_loc}/config/mode.cas")
			
		end
	
		
		
		puts ssh.exec!("cd #{$tenant_loc}")
		puts ssh.exec!("find . -name .svn -exec rm -rf {} \;")
		puts ssh.exec!("cd")
		
		if $db == "postgres"
			puts "Database is postgres so not doing any change in cleanse jobs."
			puts "CASEnable=false; db=devcdidb1\\:5432; MTI=suite6-stable-1"
			puts "updaing config/database/scripts/postgresql/cdi_tables.sql file to have required postgres properties"
			puts ssh.exec!("cd /home/utils/#{$conf_type}; ruby cdi_config_4_postgres.rb")
			puts ssh.exec!("cd /home/utils/#{$conf_type}; ruby postgres_files.rb")
		
		elsif $db == "db2"
			puts "Changing public to DB2INST1 in all cleanse jobs, disable postgres properties and enable db2"
			puts "CASEnable=false; db=mdmdb2\\:50001; MTI=suite6-stable-1"
			puts ssh.exec!("cd /home/utils/#{$conf_type}; ruby public_2_db2inst1.rb")
			puts ssh.exec!("cd /home/utils/#{$conf_type}; ruby cdi_config.rb")
			
			puts "Copying db2 files to mdmdb2"
			puts ssh.exec!("scp -r /home/latest_config/config/database/scripts/db2/*  root@mdmdb2:/home/db2inst1/db2/.")
	
		
		elsif $db == "oracle"
			puts "Changing public to DEMO in all cleanse jobs, disable postgres properties and enable ORACLE"
			puts "CASEnable=false; db=jdbc\\:oracle\\:thin:@devdb.easydq.local\\:1522\\:devdeman; MTI=suite6-stable-1"
			puts "updaing config/database/scripts/oracle/create-oracle-database.sh file to have required oracle DB properties"
			puts ssh.exec!("cd /home/utils/#{$conf_type}; ruby public_2_oracle.rb")
			puts ssh.exec!("cd /home/utils/#{$conf_type}; ruby cdi_config_4_oracle.rb")
			puts ssh.exec!("cd /home/utils/#{$conf_type}; ruby oracle_files.rb")
			
		end
		
		
		puts ssh.exec!("cd #{$tenant_loc}; chmod -R 777 config")
		
 		#puts "Copying default plans and default ruby scripts"
		#puts ssh.exec!("cp -rf /home/latest_config/config/#{$conf_type}/suite6/config/multitenant/DefaultPlans/* /home/cdi/suite6/config/multitenant/DefaultPlans/. ")
		#puts ssh.exec!("cp -rf /home/latest_config/config/#{$conf_type}/suite6/config/multitenant/DefaultScripts/universal-search.rb /home/cdi/suite6/config/multitenant/DefaultScripts/.")
		#puts ssh.exec!("cp -rf /home/latest_config/config/#{$conf_type}/suite6/config/multitenant/#{$conf_type}-person/universal-search.rb /home/cdi/suite6/config/multitenant/#{$conf_type}-person/.")
		#puts ssh.exec!("cp -rf /home/latest_config/config/#{$conf_type}/suite6/config/multitenant/#{$conf_type}-organization/universal-search.rb /home/cdi/suite6/config/multitenant/#{$conf_type}-organization/.")
		
		#puts "Restarting suite6"
		#puts ssh.exec!("service suite6 restart")
		
		
	end



end

#def deploy_build(artifact_source, wars, b_no=0)
def deploy_build(artifact_source, wars)
stop_server
  
  	if artifact_source == "Jenkins-Trunk"
		$build = "CDI%20Build" #trunk
		$snapshot_version = "7.8-RC4" # Trunk Snapshot
		#$build_no = b_no # trunk / branch
		$repo_url = "http://ci.humaninference.com:8080/view/CDI%20Build/job"
		
	elsif artifact_source == "Jenkins-Branch"
		$build = "MDM-Build-7.8-RC" # CI 7.8 branch
		$snapshot_version = "7.8" # CI 7.8 Branch Snapshot
		#$build_no = b_no # trunk / branch
		$repo_url = "http://ci.humaninference.com:8080/view/CDI%20Build/job"
		
	elsif artifact_source == "Repository-Nexus"
		$build = "HI Repo"
		$snapshot_version = "7.8-RC4" #HI Repo Release Candidate
		$repo_url = "http://repo.humaninference.com/content/repositories/releases/com/hi/cdi/"

	end
	
	#client = Selenium::WebDriver::Remote::Http::Default.new
	#client.timeout = 180

	#driver = Watir::Browser.new :phantomjs, :http_client => client
	#driver.goto "ci.humaninference.com/job/CDI%20Build/lastSuccessfulBuild/"
	
	#element = driver.find_element(:css, 'h1.build-caption.page-headline')
	#puts "Last Suucessfull Build + #{element.text}"
	#driver.quit
	puts "wars are to be deployed #{wars}"
	$modules = wars.split(/,/)
	puts "module size is #{$modules.size}"
	puts "module =  #{$modules}"
	
	if($modules.empty?)
		puts "There is no wars to be deployed"
	else
		#$modules = wars.split(/,/)
	
		Net::SSH.start($url, $ssh_user, :password => $ssh_password) do |ssh|
			$modules.each do |artifact| 
				if(artifact.include?("datarules"))
					puts "removing datarules.war"
					puts ssh.exec!("cd #{$webapp_dir}; rm -rf data*")
					#puts ssh.exec!("cd #{$webapp_dir}; ls -l")
					
				elsif(artifact.include?("service"))
					puts "removing service.war"
					puts ssh.exec!("cd #{$webapp_dir}; rm -rf service*")
				elsif(artifact.include?("mdm-jms-bridge"))
					puts "removing mdm-jms-server.war"
					puts ssh.exec!("cd #{$webapp_dir}; rm -rf mdm-jms*")
				elsif(artifact.include?("ui-overlayed"))
					puts "removing ui-overlayed.war"
					puts ssh.exec!("cd #{$webapp_dir}; rm -rf ui*")
				end

			end
			puts "Going to required webapps directory & deleting existing deployed war(s) and their folders"
			#puts ssh.exec!("cd #{$webapp_dir}; rm -rf data* ui* mdm-jms* service*")
			
			$modules.each do |artifact| 
				if $repo_url.include?("repo")
					$build  = "HumanInference Repository"
					puts "Deploying #{artifact}.war  from #{$build}..............."
					puts ssh.exec!("cd #{$webapp_dir}; wget #{$repo_url}/#{artifact}/#{$snapshot_version}/#{artifact}-#{$snapshot_version}.war")
				else 
					puts "Deploying #{artifact}.war  from #{$build}..............."
					puts ssh.exec!("cd #{$webapp_dir}; wget #{$repo_url}/#{$build}/#{$build_no}/com.hi.cdi%24#{artifact}/artifact/com.hi.cdi/#{artifact}/#{$snapshot_version}-SNAPSHOT/#{artifact}-#{$snapshot_version}-SNAPSHOT.war")
				end
			
				if artifact == "ui-overlayed"
					puts ssh.exec!("cd #{$webapp_dir}; mv #{artifact}*.war ui.war")
				else
					puts "desired war file #{artifact}.war"
					puts ssh.exec!("cd #{$webapp_dir}; mv #{artifact}*.war #{artifact}.war")
				end
			end
		
		puts "Closing the ssh connection to #{$env} after downloading all the artifacts"
		end
	
	#start_server

	end

end

def deploy_conf(conf_t)
	download_confFile
	setup_conf(conf_t)
	
end

def refresh_db(db_type)

	if db_type == "postgres"
		Net::SSH.start($conn_string, $db_username, :password => $db_password) do |ssh|
			puts "connection established"
			puts ssh.exec!("cd /home/postgres/db_scripts/; chmod 777 *")
			puts ssh.exec!("cd /home/postgres/db_scripts/; ./cdi-schema.sh")
			
	
		end
	
	elsif db_type == "db2"
		Net::SSH.start($conn_string, $db_username, :password => $db_password) do |ssh|
			#puts "connection established to mdmdb2 having #{$conn_string}, #{$db_username}, #{$db_password}"
			puts "connection established with mdmdb2 with root user"
			puts ssh.exec!("chmod -R 777 /home/db2inst1/db2/*")
			puts "after permission"
			#puts ssh.exec!("su - db2inst1")
			#puts "after changing user"
			#puts ssh.exec!("cd /home/db2inst1/db2; ./create-db2-database.sh -d demo")
			
			#puts ssh.exec!("db2 connect to demo")
				
		end
	
		Net::SSH.start($conn_string, "db2inst1", :password => "db2inst1") do |ssh|
			"Connection established with mdmdb2 with db2inst1"
			puts ssh.exec!("cd /home/db2inst1/db2; ./create-db2-database.sh -d demo")
			puts ssh.exec!("cd /home/db2inst1/db2; ./create-db2-database.sh -d demo")
			
			puts ssh.exec!("db2 connect to demo")
		end
	end
end

def clean_db(db_type)
  puts "Connecting to #{$db_name} database of #{$db} type on #{$env} to clean database"
 
if db_type == "postgres"
  conn = PostgresPR::Connection.new("#{$db_name}", "#{$db_username}", "#{$db_password}", "#{$conn_string}" + ':' + "#{$db_port}")
  
  if conn
  puts "We're connected to #{$db} on #{$env}. Hostname of database = #{$conn_string}"
  puts conn.query("delete from source_golden_mapping")
  puts conn.query("delete from SOURCEDATA")
  puts conn.query("delete from RAW_SOURCEDATA")
  puts conn.query("delete from GOLDEN_RECORD")
  puts conn.query("delete from ORCHESTRATION_LOG")
  puts conn.query("delete from orchestration_inprogress")
  puts conn.query("delete from ORCHESTRATION_STATUS")
  puts conn.query("delete from GOLDEN_RECORDS_STATUS")
  puts conn.query("update GOLDEN_RECORDS_STATUS_LOG set pointer = '1'")
  puts conn.query("UPDATE LAST_SYNCHRONIZED_ID SET GOLDEN_RECORD_ID = 0, SOURCE_RECORD_ID = 0")
  puts conn.query("DELETE FROM TEMP_GR_PHASE")
  puts conn.query("DELETE FROM TEMP_SLAVEJOB_STATUS")
  puts conn.query("delete from nodes")
  puts conn.query("delete from file_content")
  puts conn.query("delete from enrichment_service_calls_log")
  puts conn.query("delete from METRICVALUES")
  puts conn.query("update cdi_system_config set value = '0' where key  = 'gr_Max'")
  puts conn.query("delete from ONBOARDS")
  puts conn.query("delete from MANUAL_ONBOARDS")
  puts conn.query("delete from MANUAL_PROCESSING_DUP_GROUP")
  puts conn.close
  else
   puts "There was an error in the connection"
  end
  
elsif db_type == "db2"
  conn = IBM_DB.connect("DATABASE=#{$db_name};HOSTNAME=#{$conn_string};PORT=#{$db_port};PROTOCOL=TCPIP;UID=#{$db_username};PWD=#{$db_password};", "", "")                       
                       
  if conn
    puts "We're connected to #{$db} on #{$env}. Hostname of database = #{$conn_string}"
 
    IBM_DB.exec conn,'delete from source_golden_mapping'
	IBM_DB.exec conn,'delete from MANUAL_PROCESSING_DUP_GROUP'
    IBM_DB.exec conn,'delete from SOURCEDATA'
	IBM_DB.exec conn,'delete from RAW_SOURCEDATA'
    IBM_DB.exec conn,'delete from GOLDEN_RECORD'
    IBM_DB.exec conn,'delete from ORCHESTRATION_LOG'
    IBM_DB.exec conn,'delete from orchestration_inprogress'
    IBM_DB.exec conn,'delete from ORCHESTRATION_STATUS'
    IBM_DB.exec conn,'delete from GOLDEN_RECORDS_STATUS'
    IBM_DB.exec conn,'update GOLDEN_RECORDS_STATUS_LOG set pointer = \'1\''
    IBM_DB.exec conn,'UPDATE LAST_SYNCHRONIZED_ID SET GOLDEN_RECORD_ID = 0, SOURCE_RECORD_ID = 0'
    IBM_DB.exec conn,'DELETE FROM TEMP_GR_PHASE'
    IBM_DB.exec conn,'DELETE FROM TEMP_SLAVEJOB_STATUS'
    IBM_DB.exec conn,'DELETE FROM TEMP_SOURCEDATA'
    IBM_DB.exec conn,'delete from nodes'
    IBM_DB.exec conn,'delete from file_content'
    IBM_DB.exec conn,'delete from enrichment_service_calls_log'
	IBM_DB.exec conn,'delete from METRICVALUES'
	IBM_DB.exec conn,'update cdi_system_config set value = \'0\' where key  = \'gr_Max\''
	IBM_DB.exec conn,'delete from ONBOARDS'
	IBM_DB.exec conn,'delete from MANUAL_ONBOARDS'
 
    IBM_DB.close(conn)
  else
    puts "There was an error in the connection: #{IBM_DB.conn_errormsg}"
  end
end
  
end

def refresh_tenant
	puts "Running windows command from ruby for refreshing the tenant '#{$tenant}'"

	soapUIBatchFile="C:\\Program Files\\SmartBear\\SoapUI-Pro-4.6.4\\bin\\testrunner.bat"

	args = %Q[-Ptenant=#{$tenant} -PtenantPerson=#{$tenant_Person} -PtenantOrganization=#{$tenant_Organization} -PdbInstance_Person="db-oracle-11r2.humaninference.com:1521/dedup" -PdbPassword_Person=cbsdedup -PdbType_Person=oracle -PdbUser_Person=cbsdedup -PPerson_Plan="default-cdi.xml;default-cdi_ww.xml" -PdbInstance_Organization="db-oracle-11r2.humaninference.com:1521/dedup" -PdbPassword_Organization=cbsdedup -PdbType_Organization=oracle -PdbUser_Organization=cbsdedup -POrganization_Plan="default-organization-cdi.xml;default-organization-cdi_ww.xml" -PServiceEndpoint=#{$service_Endpoint}]

	#args = %Q[-Ptenant=#{$tenant} -PtenantPerson=#{$tenant_Person} -PtenantOrganization=#{$tenant_Organization} -PdbInstance_Person="db-oracle-11r2.humaninference.com:1521/dedup" -PdbPassword_Person=cbsdedup -PdbType_Person=oracle -PdbUser_Person=cbsdedup -PPerson_Plan="demo-cdi.xml;demo-cdi_ww.xml" -PdbInstance_Organization="db-oracle-11r2.humaninference.com:1521/dedup" -PdbPassword_Organization=cbsdedup -PdbType_Organization=oracle -PdbUser_Organization=cbsdedup -POrganization_Plan="demo-organization-cdi.xml;demo-organization-cdi_ww.xml" -PServiceEndpoint=#{$service_Endpoint}]
		
	projectFile = "C:\\work\\HI\\svn_code\\integration-tests\\soapui-cdi-integration-test\\src\\test\\java\\com\\hi\\cdi\\CDIProj-soapui-projectRefreshTenant.xml"
	
	puts system("\"#{soapUIBatchFile}\" #{args} #{projectFile}")

  
end

def check_server_up
puts "Checking whether tomcat server is up or not by hitting http request"
$count = 0




def get_Web_document(url)
  puts url
  puts "Waiting for server to come up. It usually takes some time"
  sleep(30)
  $count = $count + 1
  uri =  URI.parse(url)
  ssl_mode = false
  ssl_mode = true if url =~ /^https/
  response = ""
  if url =~ /^https/ 
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: "#{ssl_mode}", verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|  
    http.get uri.request_uri
  end
  else 
  response = Net::HTTP.start(uri.host, uri.port) do |http|  
  http.get uri.request_uri
  end
   
  end


  case response
    when Net::HTTPSuccess
      return response.body
    when Net::HTTPNotFound
      fireRequestAgain

    else
      return nil
  end
  
  rescue Timeout::Error => e 
    puts "Request got timeout, seems server is not up yet. Will try after 30 seconds"
    fireRequestAgain
    
end


def fireRequestAgain
  if $count > 10
        return nil
      else 
        sleep(30)
        return get_Web_document($web_url)  
      end
end

puts get_Web_document($web_url)
  
end


def onboard_data
puts "Onboarding Person data1"
system("C:\\work\\HI\\DataCleaner\\datacleaner.cmd -job C:\\work\\HI\\DataCleaner\\examples\\SAPCRM\\" + "#{$person_file}")

#sleep(5)

#puts "Onboarding Organization data"
#system("C:\\work\\HI\\DataCleaner\\datacleaner.cmd -job C:\\work\\HI\\DataCleaner\\examples\\SAPCRM\\" + "#{$org_file}")
  
end

def enable_debug_logs
	Net::SSH.start($url, $ssh_user, :password => $ssh_password) do |ssh|
		puts "connection established"
		
		puts ssh.exec!("cd /home/utils/#{$conf_type}; ruby enable_debug_logs.rb")
		
		
	end
end
puts "Please specify the env followed by step(s) you want to execute e.g. 'mdmregtest 1 4' or 'mdm4tc' "
puts "Please choose option(s) to execute the step(s):"
puts "Press '1' to deploy latest build"
puts "Press '2' to clean db"
puts "Press '3' to refresh tenant"
puts "Press '4' to check whether server is up"
puts "Press '5' to onboard data. 5p for person, 5o for organization"
puts "Enter 'app-restart' to restart the MDM server"
puts "Enter 'app-stop' to stop tomcat"
puts "Enter 'app-start' to start tomcat"
puts "Press '9' to deploy fresh configuration"
puts "Press '10' to refresh db"
puts "Press '11' to enable debug logs"



input = ARGV
#input = input.split(/\s/)
puts input.inspect

if input.size == 1
  puts "Running all the steps on #{input[0]}"
  $env = input[0]
  #initialize_var
  #deploy_build
  #clean_db
  #refresh_tenant
  #check_server_up
  #onboard_data
  puts "Env is #{$env}" 
else 
  $env = input[0]
  puts "Running given #{input.size - 1} steps(s) on #{input.shift}"
  initialize_var
  check_artifact(input)
  check_buildno(input)
  
  if(input.include?("db2"))
		init_db("db2")
	elsif(input.include?("postgres"))
		init_db("postgres")
	elsif(input.include?("oracle"))
		init_db("oracle")
  end
  input.each do|step| 
    case step
    when "Jenkins-Trunk"
      deploy_build("Jenkins-Trunk", $artifact_list)
    when "Jenkins-Branch"
      deploy_build("Jenkins-Branch", $artifact_list)
    when "Repository-Nexus"
	  deploy_build("Repository-Nexus", $artifact_list)
    when "Clean"
      clean_db(input[input.index("Clean")+1])
	when "Recreate"
	  refresh_db(input[input.index("Recreate")+1])
    when "suite6-stable1"
      refresh_tenant
	when "suite6-stable2"
      refresh_tenant
    when "4"
      check_server_up
    when "5"
      onboard_data
	when "app-restart"
      restart_server
	when "app-stop"
		stop_server
	when "app-start"
		start_server
	when "demo"
		deploy_conf("demo")
	when "default"
		deploy_conf("default")
	when "11"
		enable_debug_logs		
    else
      puts ""
    end
  end
  
end


def useless
#wget http://ci.humaninference.com:8080/view/CDI%20Build/job/CDI%20Build/229/com.hi.cdi%24metadata-generator/artifact/com.hi.cdi/metadata-generator/1.52-SNAPSHOT/metadata-generator-1.52-SNAPSHOT-jar-with-dependencies.jar


#wget http://ci.humaninference.com:8080/view/CDI%20Build/job/CDI%20Build/229/com.hi.cdi%24onboarding-datacleaner/artifact/com.hi.cdi/onboarding-datacleaner/1.52-SNAPSHOT/onboarding-datacleaner-1.52-SNAPSHOT-jar-with-dependencies.jar

end

# To recreate/refresh postgres db on devcdidb1
# Go to abnapp-2 and run 'cd /home/latest_config/config/database/scripts/postgresql'
# scp -r * root@devcdidb1:/home/postgres/db_scripts/.
# Go to devcdidb1 (root/Zaphod561) and run 'cd /home/postgres/db_scripts'		
# ./cdi-schema.sh

# To recreate/refresh db2 database on mdmdb2
# Go to abnapp-2 and run 'cd /home/latest_config/config/database/scripts/db2'
# run 'scp * db2inst1@mdmdb2:db2/.'
# Go to mdmdb2 (db2inst1/db2inst1) and run 'cd db2'		
# run './create-db2-database.sh -d demo -tune 1'
# run 'db2 connect demo'

# To recreate/refresh oracle database on devapp.easydq.local
# Go to abnapp-2 and run 'cd /home/latest_config/config/database/scripts/oracle'
# run 'scp * root@devapp.easydq.local:/home/DBSCRIPTs/.'
# Go to devapp.easydq.local (root/dichUjder) and run 'su - hicso' & 'cd /home/DBSCRIPTs'		
# run './create-oracle-database.sh'


#http://ci.humaninference.com:8080/view/CDI%20Build/job/MDM%20packaging/223/com.hi.mdm%24mdm-contact-data-ear/artifact/com.hi.mdm/mdm-contact-data-ear/1.62-SNAPSHOT/mdm-contact-data-ear-1.62-SNAPSHOT.ear

#mv mdm-contact-data-ear-1.62-SNAPSHOT.ear  mdm-contact-data-ear.ear
#tomemw
#-DCDI_HOME=/opt/humani/cdi

#zip utils.zip -r utils/
#unzip utils.zip

############################################################################################

#VM: aix71-2
#username/password: root/tomemw
#Tenant Location: /opt/humani/cdi

#Open in FF only, it does not work in chrome:
#IBM Web Console: https://aix71-2:9043/ibm/console/secure/securelogon.do
#username/password: wasadmin/wasadmin

#bin -> /opt/IBM/WebSphere/AppServer/profiles/AppSrv01/bin
#stopServer.sh server1
#startServer.sh server1

#logs -> /opt/IBM/WebSphere/AppServer/profiles/AppSrv01/logs/server1/
#logs> tail -f SystemOut.log


#MDM: http://aix71-2:9080/ui/login.jsf


#########################################################################33
# Oracle START
#database.dbcp.driverClassName=oracle.jdbc.driver.OracleDriver
#database.dbcp.url=jdbc\:oracle\:thin:@devdb.easydq.local\:1522\:devdeman
#database.dbcp.username=DEMO
#database.dbcp.password=oracle
# Below property is used for oracle data
#database.dbcp.validationQuery=select 1 from dual
# Oracle END

# MSSQl START
#database.dbcp.driverClassName=net.sourceforge.jtds.jdbc.Driver
#database.dbcp.url=jdbc:jtds:sqlserver://db-mssql-2012;DatabaseName=MDM_RC2
#database.dbcp.username=sa
#database.dbcp.password=password
#database.dbcp.selectMethod=cursor
#database.dbcp.validationQuery=select 1
# MSSQl END
