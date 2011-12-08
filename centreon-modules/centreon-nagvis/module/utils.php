<?php

if (!isset ($oreon)) {
		exit ();
}


function getCentreonNagvisConfig($myCentreonDb){
	$nagvisConfig = array();
	$dbResult =& $myCentreonDb->query("SELECT * FROM `options` where `key` like 'centreon-nagvis-%'");
	while ($row = $dbResult->fetchRow()) {
		$nagvisConfig[$row['key']] = $row['value'];
	}
	
	if(!array_key_exists("centreon-nagvis-uri",$nagvisConfig)) $nagvisConfig["centreon-nagvis-db-uri"] = "";
	if(!array_key_exists("centreon-nagvis-db-host",$nagvisConfig)) $nagvisConfig["centreon-nagvis-db-host"] = "";
	if(!array_key_exists("centreon-nagvis-db-port",$nagvisConfig)) $nagvisConfig["centreon-nagvis-db-port"] = "";
	if(!array_key_exists("centreon-nagvis-db-user",$nagvisConfig)) $nagvisConfig["centreon-nagvis-db-user"] = "";
	if(!array_key_exists("centreon-nagvis-db-password",$nagvisConfig)) $nagvisConfig["centreon-nagvis-db-password"] = "";
	if(!array_key_exists("centreon-nagvis-db-name",$nagvisConfig)) $nagvisConfig["centreon-nagvis-db-name"] = "";
	
	return $nagvisConfig;
	
}

function getCentreonDbSessionId($myCentreonDb){
	// get id from session table
	$query = "
		SELECT id
		FROM session
		WHERE 
		session_id = '".session_id()."'
	";
	
	$result = $myCentreonDb->query($query);
	$row = $result->fetchRow();
	return $row["id"];
}

function getNagvisRolesAdmin(){
	
}

function getCentreonNagvisMapping($myCentreonDb){
	$mapping = array();
	$config = getCentreonNagvisConfig($myCentreonDb);
	$dbResult =& $myCentreonDb->query("
		SELECT
			CONCAT(ag.acl_group_id,'.',ng.roleId) ids, CONCAT(ag.acl_group_alias, ' -> ' ,ng.name) alias
		FROM
			centreonnagvis AS cn
			INNER JOIN acl_groups ag ON cn.acl_group_id = ag.acl_group_id
			INNER JOIN ".$config["centreon-nagvis-db-name"].".roles ng ON cn.roleId = ng.roleId
	");
	while ($row = $dbResult->fetchRow()) {
			$mapping[] = $row;
	}
	return $mapping;
}

function getCentreonGroups($myCentreonDb){
	$centreonGroups = array();
	$dbResult =& $myCentreonDb->query("SELECT * FROM `acl_groups` where `acl_group_activate` = '1' order by acl_group_alias");
	while ($row = $dbResult->fetchRow()) {
			$centreonGroups[] = $row;
	}
	return $centreonGroups;
}

function getNagvisRoles($data){
	$nagvisRoles=array();
	$options = array('debug' => 2,'portability' => DB_PORTABILITY_ALL ^ DB_PORTABILITY_LOWERCASE);
	$dsn = array(
		'phptype'  => "mysql",
	    'username' => $data["centreon-nagvis-db-user"],
	    'password' => $data["centreon-nagvis-db-password"],
	    'hostspec' => $data["centreon-nagvis-db-host"].":".$data["centreon-nagvis-db-port"],
	    'database' => $data["centreon-nagvis-db-name"],
	);		
	$dbtest =& DB::connect($dsn, $options);
	if(PEAR::isError($dbtest)){
		return false;
	}else{
		$dbResult =& $dbtest->query("SELECT `roleId`,`name` FROM `roles` ORDER BY `name`");
		while ($row = $dbResult->fetchRow(DB_FETCHMODE_ASSOC)) {
			$nagvisRoles[] = $row;
		}
	}	
	return $nagvisRoles;
}

function buildCentreonNagvisSelect($data,$key,$value,$id,$style=""){
	$options = "";
	foreach($data as $row){
		$options.="<option value=\"".$row[$key]."\">".$row[$value]."</option>";		
	}
	return "
		<select multiple size=\"10\" id=\"".$id."\" name=\"".$id."\" style=\"".$style."\">".$options."</select>
		<input type=\"hidden\" id=\"h".$id."\" name=\"h".$id."\"/>
	";
}

function updateCentreonNagvisMapping($data,$myCentreonDb){
	// first drop all existing mapping
	$queryDelete = "DELETE from `centreonnagvis`";
	$myCentreonDb->query($queryDelete);
	// create mapping
	foreach($data as $row){
		$queryCheckExist="SELECT COUNT(*) AS `exist` FROM `centreonnagvis` WHERE `acl_group_id` = '".$row["acl_group_id"]."' and `roleId` = '".$row["roleId"]."'";
		$resultExist =& $myCentreonDb->query($queryCheckExist);
		$rowExist =& $resultExist->fetchRow();
		if(isset($rowExist) && $rowExist[`exist`] == 0){
			// create entry
			$queryInsert = "INSERT INTO `centreonnagvis` (`acl_group_id`,`roleId`) VALUES ('".$row["acl_group_id"]."','".$row["roleId"]."')";
			$myCentreonDb->query($queryInsert);
		}
	}
	return;
}

function updateCentreonNagvisConfig($myCentreonDb,$key,$value){
	$queryCheckExist="SELECT COUNT(*) AS `exist` FROM `options` WHERE `key` = '".$key."'";
	$resultExist =& $myCentreonDb->query($queryCheckExist);
	$row =& $resultExist->fetchRow();
	if(isset($row) && $row[`exist`] == 0){
		// create entry
		$queryUpdate = "INSERT INTO `options` (`key`,`value`) VALUES ('".$key."','".$value."')";
	}else{
		$queryUpdate = "UPDATE `options` SET `value` = '".$value."' WHERE `key` = '".$key."'";
	}
	
	$myCentreonDb->query($queryUpdate);
	
	return;
}

function getCentreonNagvisFormFields(){
	$post = array();
	foreach(array_keys($_POST) as $key){
		if (preg_match("/^centreon-nagvis/", $key)) {
    		$post[$key] = sanitize($_POST[$key]);
		}
		if (preg_match("/^hcentreon-nagvis/", $key)) {
    		$post[$key] = sanitize($_POST[$key]);
		}		
	}
	return $post;
}		

function sanitize($data){
	$sdata = stripslashes($data);
	$sdata = mysql_real_escape_string($data);
	return $sdata;
}

function testCentreonNagvisDbAccess($data){
	$options = array('debug' => 2,'portability' => DB_PORTABILITY_ALL ^ DB_PORTABILITY_LOWERCASE);
	$dsn = array(
		'phptype'  => "mysql",
	    'username' => $data["centreon-nagvis-db-user"],
	    'password' => $data["centreon-nagvis-db-password"],
	    'hostspec' => $data["centreon-nagvis-db-host"].":".$data["centreon-nagvis-db-port"],
	    'database' => $data["centreon-nagvis-db-name"],
	);		
	$dbtest =& DB::connect($dsn, $options);
	if(PEAR::isError($dbtest)){
		return false;
	}else{
		return true;
	}
}

function displayCentreonNagvis($data){

$form = '
<script type="text/javascript" src="./modules/nagvis/javascript/jquery.js"></script>
<script type="text/javascript" src="./modules/nagvis/javascript/jquery.autoheight.js"></script>
<iframe id="frmnagvis" name="frmnagvis" class="autoHeight" frameborder="0" scrolling="yes" src="##centreon-nagvis-uri##" style="width:100%"></iframe> 	
';

foreach(array_keys($data) as $key){
	$form = str_replace("##".$key."##", $data[$key], $form);
}
return $form;

}

function displayCentreonNagvisUriForm($data){
$p = intval($_GET["p"]);
$form='
<form  action="?p='.$p.'&action=save" method="post" name="Form" id="Form"> 
    <input type="hidden" name="level" value="1"> 
	<table class="ListTable"> 
	    <tr class="">
	    	<td class="" colspan="2" style="color:red">##errorMessage##</td>
	    </tr> 
	    <tr class="ListHeader">
	    	<td class="FormHeader" colspan="2">&nbsp;&nbsp;Centreon-Nagvis Configuration</td>
	    </tr> 
	 	
	 	<tr class="list_lvl_1">
	 		<td class="ListColLvl1_name" colspan="2">&nbsp;&nbsp;Nagvis Location</td>
	 	</tr>	 	
		<tr class="list_one">
			<td class="FormRowField">URI</td>
			<td class="FormRowValue"><input type="text" style="width:350px;" name="centreon-nagvis-uri" id="centreon-nagvis-uri" value="##centreon-nagvis-uri##"></td>
		</tr> 
	</table> 
	<div align="center" id="validForm"><p class="oreonbutton"><input name="submit" value="Save" type="submit" /></p></div> 
</form>	
';	
foreach(array_keys($data) as $key){
	$form = str_replace("##".$key."##", $data[$key], $form);
}
return $form;
}

function displayCentreonNagvisConfigDbForm($data){
$p = intval($_GET["p"]);
$form = '
<form  action="?p='.$p.'&action=save" method="post" name="Form" id="Form"> 
    <input type="hidden" name="level" value="1"> 
	<table class="ListTable"> 
	    <tr class="">
	    	<td class="" colspan="2" style="color:red">##errorMessage##</td>
	    </tr> 
	    <tr class="ListHeader">
	    	<td class="FormHeader" colspan="2">&nbsp;&nbsp;Nagvis Database Configuration</td>
	    </tr> 
	 	<tr class="list_lvl_1">
	 		<td class="ListColLvl1_name" colspan="2">&nbsp;&nbsp;Mysql Server</td>
	 	</tr>	 	
		<tr class="list_one">
			<td class="FormRowField">Host</td>
			<td class="FormRowValue"><input type="text" style="width:350px;" name="centreon-nagvis-db-host" id="centreon-nagvis-db-host" value="##centreon-nagvis-db-host##"></td>
		</tr> 
		<tr class="list_one">
			<td class="FormRowField">Port</td>
			<td class="FormRowValue"><input type="text" style="width:350px;" name="centreon-nagvis-db-port" id="centreon-nagvis-db-port" value="##centreon-nagvis-db-port##"></td>
		</tr> 
		<tr class="list_one">
			<td class="FormRowField">Database</td>
			<td class="FormRowValue"><input type="text" style="width:350px;" name="centreon-nagvis-db-name" id="centreon-nagvis-db-name" value="##centreon-nagvis-db-name##"></td>
		</tr>
	 	<tr class="list_lvl_1">
	 		<td class="ListColLvl1_name" colspan="2">&nbsp;&nbsp;Credentials</td>
	 	</tr>	 	
		<tr class="list_one">
			<td class="FormRowField">Username</td>
			<td class="FormRowValue"><input type="text" style="width:350px;" name="centreon-nagvis-db-user" id="centreon-nagvis-db-user" value="##centreon-nagvis-db-user##"></td>
		</tr> 
		<tr class="list_one">
			<td class="FormRowField">Password</td>
			<td class="FormRowValue"><input type="text" style="width:350px;" name="centreon-nagvis-db-password" id="centreon-nagvis-db-password" value="##centreon-nagvis-db-password##"></td>
		</tr> 
	</table> 
	<div align="center" id="validForm"><p class="oreonbutton"><input name="submit" value="Save" type="submit" /></p></div> 
</form>	
';

foreach(array_keys($data) as $key){
	$form = str_replace("##".$key."##", $data[$key], $form);
}

return $form;

}


function displayCentreonNagvisConfigMapping($data){
$p=intval($_GET["p"]);

$form = '
<script type="text/javascript">
	function addOption(select,value,text){
		myOption = new Option(text,value);
		if(select.length == 0){
			select.options[0] = myOption;
		}else{
			select.options[select.length] = myOption;
		} 
	}
	
	function removeSelectedOption(select){
		select = document.getElementById(select);
		sel = select.selectedIndex;
		if(sel != -1){
			select.options[sel] = null;
		}
	}
	
	function setMultipleSelect(selectName){
		select = document.getElementById(selectName);
		hiddenvalues = document.getElementById("h"+selectName);
		values="";
		for(i=0;i<select.length;i++){
			values = values + select.options[i].value+";";
		}	
		hiddenvalues.value = values;
		return false;
	}
	
	function setMapping(groupSelect,roleSelect,mappingSelect){
		groupId=document.getElementById(groupSelect).options[document.getElementById(groupSelect).options.selectedIndex].value;
		roleId=document.getElementById(roleSelect).options[document.getElementById(roleSelect).options.selectedIndex].value;
		groupText=document.getElementById(groupSelect).options[document.getElementById(groupSelect).options.selectedIndex].text;
		roleText=document.getElementById(roleSelect).options[document.getElementById(roleSelect).options.selectedIndex].text;
		
		mappingId=groupId+"."+roleId;
		mappingText=groupText+" -> "+roleText;

		exist=0;
		mappingSelect=document.getElementById(mappingSelect);
		
		for(i=0; i<mappingSelect.length;i++){
			if(mappingSelect.options[i].value == mappingId){
				exist=1
			}
		}
		if(exist == 1){
			alert("Mapping allready done");
		}else{
			addOption(mappingSelect,mappingId,mappingText);
		}
	}
</script>
<form  action="?p='.$p.'&action=save" method="post" name="Form" id="Form"> 
    <input type="hidden" name="level" value="1"> 
	<table class="ListTable"> 
	    <tr class="">
	    	<td class="" colspan="5" style="color:red">##errorMessage##</td>
	    </tr> 
	    <tr class="ListHeader">
	    	<td class="FormHeader" colspan="5">&nbsp;&nbsp;Centreon-Nagvis Groups/Rôles mapping</td>
	    </tr> 
	 	
	 	<tr class="list_lvl_1">
	 		<td class="ListColLvl1_name" style="text-align:center;">&nbsp;&nbsp;Centreon groups</td>
	 		<td class="ListColLvl1_name" style="text-align:center;">&nbsp;&nbsp;Nagvis roles</td>
	 		<td class="ListColLvl1_name" style="text-align:center;">&nbsp;&nbsp;</td>
	 		<td class="ListColLvl1_name" style="text-align:center;">&nbsp;&nbsp;Mapping</td>
			<td class="FormRowField"></td>
	 	</tr>	 	
		<tr class="list_one">
			<td class="FormRowField" style="text-align:center;width:250px;">##centreon-nagvis-centreon-groups##</td>
			<td class="FormRowField" style="text-align:center;width:250px;">##centreon-nagvis-nagvis-roles##</td>
			<td class="FormRowField" style="vertical-align:middle;width:60px;">
				<input type="button" style="width:200px;" value="Set mapping >>" onclick="setMapping(\'centreon-nagvis-centreon-groups\',\'centreon-nagvis-nagvis-roles\',\'centreon-nagvis-mapping\')">
				<br/><br/>
				<input type="button" style="width:200px;" value="<< Remove mapping" onclick="removeSelectedOption(\'centreon-nagvis-mapping\')">			
			</td>
			<td class="FormRowField" style="text-align:center;width:250px;">##centreon-nagvis-mapping##</td>
			<td class="FormRowField" style="width:*"></td>
		</tr> 
	</table> 
	<div align="center" id="validForm"><p class="oreonbutton"><input name="submit" value="Save" type="submit" onclick="setMultipleSelect(\'centreon-nagvis-mapping\');" /></p></div> 
</form>	
';	

foreach(array_keys($data) as $key){
	$form = str_replace("##".$key."##", $data[$key], $form);
}

return $form;	
}
