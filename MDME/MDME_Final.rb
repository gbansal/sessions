Shoes.app :title=>"Welcome to easy and fast MDM Deployment. 3..2..1..GO", :width=>1000, :height=>400, :top=>10, :left=>0 do
	#:fullscreen =>true
	background white
	#background "#F3F".."#F90"
	border(cadetblue, strokewidth: 2)
	
	flow :width => 1000, :margin=> 10 do
		
		stack :width => "95%" do
			border cadetblue, :strokewidth=>2
			flow(margin:8) {
			image 'http://www.humaninference.com/media/logo-hi.gif', :top =>10, :left =>10
			para "\n\n"
			#subtitle "\t\t\t MDME: MDM Deployment Made Easy", :top =>20, :left => 20
			title "\t\t\t MDME: MDM Deployment Made Easy", :top =>20, :font => "Monospace 24px"
			}
		end
		
		stack :width => "600px" do
		border cadetblue, :strokewidth=>2
			flow(margin:8) {
				para strong("Choose VM", top: 15)
				#@a = para( strong("Choose VM", top: 950))
				@env = list_box :margin=> 10, :items => ["abnapp", "abnapp-2", "mdmregtest","mdm-dev-1", "mdm-dev-2", "tstcdi1", "tstcdi2", "aix71-2", "localg", "localb"]		
			}
			flow(margin:8) {
				para strong("Choose Artifacts")
				@artifact = list_box :margin=> 10, :items => ["Jenkins-Trunk", "Jenkins-Branch", "Repository-Nexus"]		
			}
			
			flow(margin:8) { 
				para  strong("Build Number\t")
				@build_no = edit_line :width=>120
			}
			flow(margin:8) {
			para strong("Choose Wars to be deployed")
				@list = ['service', 'datarules', 'mdm-jms-bridge', 'ui-overlayed']
				
				stack do
					@list.map! do|name|
						flow(margin:8){ @c = check; para name}
						[@c, name]
					end
				end
			}
			flow(margin:8) {
				para strong("Choose Config")
				@config = list_box :margin=> 10, :items => ["demo", "default"]		
			}			
		end
		
		stack :width => "-650px" do
		border cadetblue, :strokewidth=>2
			flow(margin:8) {
				para strong("Choose Database Operation")
				@db_operation = list_box :margin=> 10, :items => ["Recreate", "Clean"]		
			}
			flow(margin:8) {
				para strong("Choose Database")
				@db = list_box :margin=> 10, :items => ["postgres", "db2", "oracle", "MySql"]		
			}
			flow(margin:8) {
				para strong("Choose modes")
				@ssl_mode = list_box :margin=> 10, :items => ["Default", "CAS", "MSEC"]		
			}	
			flow(margin:8) {
				para strong("Choose MTI Location")
				@mtilocation = list_box :margin=> 10, :items => ["suite6-stable1", "suite6-stable2"]		
			}				
			flow(margin:8) {
				para strong("Choose Tomcat Operation")
				@tomcat = list_box :margin=> 10, :items => ["app-start", "app-stop", "app-restart"]		
			}	
flow(margin:10) {			
			button "Submit" do 
				#handle check boxes of MDM wars
				selected = @list.map { |c, name| name if c.checked? }.compact
				
				#handle build number
				if(@build_no.text == "")
				else
					$bno = "bno_#{@build_no.text}"
				end
				alert "ruby Deployment.rb #{@env.text} #{@artifact.text} #{selected.join(',')} #{$bno} #{@db_operation.text} #{@db.text} #{@config.text} #{@mtilocation.text} #{@tomcat.text}"
				
				puts system("ruby Deployment.rb #{@env.text} #{@artifact.text} #{selected.join(',')} #{$bno} #{@db_operation.text} #{@db.text} #{@config.text} #{@mtilocation.text} #{@tomcat.text}")
			end
			para(link("abnapp-2", :click=>"http://abnapp-2:8080/ui"))
			para "   "
			para(link("abnapp", :click=>"http://abnapp:8080/ui"))
}			
		end
		
		
	end
	
end