require 'Check_watir'

class Monitoringfrblog < TC_Check_watir 
	####################################################
	# Scenario
	####################################################

	$BASEURL='http://www.monitoring-fr.org'
	$LOGIN='dguenault'
	$PASSWORD='yourpassword'
	$DISCONNECT='http://www.monitoring-fr.org/wp-login.php?action=logout&_wpnonce=fffb6c5b7d&redirect_to=http%3A%2F%2Fwww.monitoring-fr.org%2F'


	# Report parameters
	$REPORT='/tmp/monitoringfrblog'
	$REPORTTITLE='http://monitoring-fr.org Blog testing'
	$REPORTURI='http://localhost/reports'
	
	def test_2_blog_home
		$current="blog_home"
		$browser.goto $BASEURL
		textPresent("Francophone de la Supervision Libre")
	end

	def test_3_blog_login
		$current="blog_login"
		$browser.text_field(:name => 'log').set $LOGIN
		$browser.text_field(:name => 'pwd').set $PASSWORD
		$browser.checkbox(:value => 'forever').clear
		$browser.button(:name => 'submit').click
		textPresent("Panneau de contr")
	end
	
	def test_4_blog_logout
		$current="blog_logout"
		$browser.goto $DISCONNECT	
		textPresent("enregistrer")
	end
end

