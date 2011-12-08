<?php
/*
 * Centreon is developped with GPL Licence 2.0 :
 * http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
 * Developped by : Julien Mathis - Romain Le Merlus - Christophe Coraboeuf
 * 
 * The Software is provided to you AS IS and WITH ALL FAULTS.
 * Centreon makes no representation and gives no warranty whatsoever,
 * whether express or implied, and without limitation, with regard to the quality,
 * any particular or intended purpose of the Software found on the Centreon web site.
 * In no event will Centreon be liable for any direct, indirect, punitive, special,
 * incidental or consequential damages however they may arise and even if Centreon has
 * been previously advised of the possibility of such damages.
 * 
 * For information : contact@centreon.com
 */
 
	if (!isset ($oreon)) {
		exit ();
	}
		
	# Utility functions
	require_once 'utils.php';
	
	#Path to the configuration dir
	global $path;
	$path = "./modules/nagvis/";

	// DB initialisation
	$myCentreonDb = new CentreonDB();
	
	// load existing config
    // get config for this module
    $nagvisConfig = getCentreonNagvisConfig($myCentreonDb);

	$post = getCentreonNagvisFormFields();
	$dataform = array();

	if(isset($_GET["action"])){
		if($post["centreon-nagvis-db-host"] == "" | $post["centreon-nagvis-db-port"] == "" | $post["centreon-nagvis-db-name"] == "" | $post["centreon-nagvis-db-user"] == "" | $post["centreon-nagvis-db-password"] == ""){
			$dataform["errorMessage"] = "All fields are mandatory !";
		}else{
			// test nagvis database connection
			if(testCentreonNagvisDbAccess($post)){
				// save configuration
				foreach (array_keys($post) as $key){
					updateCentreonNagvisConfig($myCentreonDb,$key,$post[$key]);
				}
				$dataform["errorMessage"] = "OK";
			}else{
				$dataform["errorMessage"] = "Test connection to nagvis database failed";
			}
		}
	}else{
		foreach(array_keys($nagvisConfig) as $key){
			$dataform[$key]=$nagvisConfig[$key];
		}
		$dataform["errorMessage"]="";
		
	}

	foreach(array_keys($post) as $key){
		$dataform[$key]=$post[$key];
	}
    
    print displayCentreonNagvisConfigDbForm($dataform);

	
?>
