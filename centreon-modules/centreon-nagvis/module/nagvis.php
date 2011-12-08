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
	
	require_once 'utils.php';
	
	// DB initialisation
	$nagvisDb = new CentreonDB();

	$id = getCentreonDbSessionId($nagvisDb);	
	
	#Path to the configuration dir
	global $path;
	$path = "./modules/nagvis/";


	// if admin full access
	if(isUserAdmin(session_id()) == 1){
		
	}else{
	    // get config for this module
	    // centreon-nagvis-uri = relative path to nagvis 
	    $nagvisConfig = array();
		$nagvisDb = new CentreonDB();
		$dbResult = $nagvisDb->query("SELECT * FROM `options` where `key` like 'centreon-nagvis-%'");
		while ($row = $dbResult->fetchRow()) {
			$nagvisConfig[$row['key']] = $row['value'];
		}
		print displayCentreonNagvis(array("centreon-nagvis-uri"=>$nagvisConfig["centreon-nagvis-uri"]."?centreonnagvis=".$id));		
	}
	
	
	

?>
