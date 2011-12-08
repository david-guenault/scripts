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

	// 
	$post = getCentreonNagvisFormFields();
	
	// DB initialisation
	$nagvisDb = new CentreonDB();
	
	// init template data
	$dataform=array("errorMessage"=>"");
	
	// deal with saving
	if(isset($_GET["action"])){
		// check if uri is filed
		if($post["centreon-nagvis-uri"] == ""){
			$dataform["errorMessage"] = "URI is mandatory !";
    		$nagvisConfig = getCentreonNagvisConfig($nagvisDb);
			$dataform["centreon-nagvis-uri"] = $nagvisConfig["centreon-nagvis-uri"];
		}else{
			// save configuration
			$uri = $post["centreon-nagvis-uri"];
			$queryDelete = "DELETE FROM `options` where `key` = 'centreon-nagvis-uri'";
			$queryInsert = "INSERT INTO `options` (`key`,`value`) VALUES ('centreon-nagvis-uri','".$uri."')";
			$nagvisDb->query($queryDelete);
			$nagvisDb->query($queryInsert);
		}
	}

    // get config for this module
    $nagvisConfig = getCentreonNagvisConfig($nagvisDb);
	$dataform["centreon-nagvis-uri"] = $nagvisConfig["centreon-nagvis-uri"];
    
	foreach(array_keys($post) as $key){
		$dataform[$key]=$post[$key];
	}
    
    print displayCentreonNagvisUriForm($dataform);
	
?>
