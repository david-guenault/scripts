require 'Check_watir'

class GoogleMail < TC_Check_watir 
	####################################################
	# Scenario
	####################################################

	$BASEURL='https://mail.google.com/mail/?shva=1#inbox'
	$LOGIN=''
	$PASSWORD=''
	$DISCONNECT='https://mail.google.com/mail/?logout&hl=fr'

	# Report parameters
	$REPORT='/var/www/reports/GoogleMail'
	$REPORTTITLE='Google Mail testing'
	$REPORTURI='http://localhost/reports'
	
	def test_1_mail_auth_form
		$current="mail_auth_form"
		$browser.goto $BASEURL
		textPresent("Connectez-vous à l'aide de votre")
	end

	def test_2_mail_do_login
		$current="mail_do_login"
		$browser.text_field(:name => 'Email').set $LOGIN
		$browser.text_field(:name => 'Passwd').set $PASSWORD
		$browser.checkbox(:value => 'yes').clear
		$browser.button(:name => 'signIn').click
		waitTextPresent("Chargement de la version standard")
	end
	
	def test_3_mail_do_logout
		$current="mail_do_logout"
		$browser.goto $DISCONNECT	
	end
end

