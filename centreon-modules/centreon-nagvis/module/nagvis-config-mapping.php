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
	
    // get config for this module
    $nagvisConfig = getCentreonNagvisConfig($myCentreonDb);

    // get submited form data
	$post = getCentreonNagvisFormFields();

	$dataform = array();
	$formfields = array();
	
	if(isset($_GET["action"])){
		$rawdata = substr($post["hcentreon-nagvis-mapping"],0,strlen($post["hcentreon-nagvis-mapping"])-1);
		$data = array();
		$row = array();
		$elements = explode(";",$rawdata);
		
		foreach($elements as $element){
			$pair = explode(".",$element);
			$row["acl_group_id"] = $pair[0];
			$row["roleId"] = $pair[1];
			$data[] = $row;
		}
		updateCentreonNagvisMapping($data,$myCentreonDb);
		$dataform["errorMessage"]="";
	}else{
		$dataform["errorMessage"]="";
	}

	$selectMapping = buildCentreonNagvisSelect(getCentreonNagvisMapping($myCentreonDb),"ids","alias","centreon-nagvis-mapping","width:240px;"); 
	$selectNagvisRoles = buildCentreonNagvisSelect(getNagvisRoles($nagvisConfig), "roleId", "name", "centreon-nagvis-nagvis-roles","width:240px;");
	$selectCentreonGroups = buildCentreonNagvisSelect(getCentreonGroups($myCentreonDb),"acl_group_id","acl_group_alias","centreon-nagvis-centreon-groups","width:240px;"); 
	$dataform["centreon-nagvis-centreon-groups"]=$selectCentreonGroups;
	$dataform["centreon-nagvis-nagvis-roles"]=$selectNagvisRoles;
	$dataform["centreon-nagvis-mapping"]=$selectMapping;
	print displayCentreonNagvisConfigMapping($dataform);

	
?>
