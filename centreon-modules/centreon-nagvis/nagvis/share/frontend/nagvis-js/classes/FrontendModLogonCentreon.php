<?php
/*****************************************************************************
 *
 * FrontendModLogonCentreon.php - Module for handling shared auth with centreon and NagVis
 *
 * Copyright (c) 2010 Monitoring-fr.org (Contact: contac@monitoring-fr.org)
 *
 * License:
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 *****************************************************************************/
 
/**
 * @author	David GUENAULT <dguenault@monitoring-fr.org>
 */
class FrontendModLogonCentreon extends FrontendModule {
	protected $CORE;
	private $SESS;
	private $centreondb;
	private $authlog;
	public function __construct($CORE) {
		$this->CORE = $CORE;
		$this->aActions = Array('view' => 0);
		$this->SESS = new CoreSessionHandler();
		$this->centreondb = $this->CORE->getMainCfg()->getValue('authmysqldb', 'centreondatabase');
		$this->authlog = $this->CORE->getMainCfg()->getValue('authmysqldb', 'authlog');
	}
	
	private function go2login(){
		//$this->cnlog("go2login");
		$VIEW = new NagVisLoginView($this->CORE);
		$sReturn = $VIEW->parse();
		return $sReturn;
	}
	
	private function checkDeauth(){
		$authId = $this->AUTHENTICATION->getUserId();
		$query = "
			SELECT 
				* 
			FROM
				".$this->centreondb.".session s
			WHERE
				id=".$this->SESS->get("centreonnagvis")." AND
				ip_address = '".$_SERVER["REMOTE_ADDR"]."'
		";		
		$index = 0;
		$res = $db->query($query);	 
		while($row = $res->fetch(PDO::FETCH_ASSOC)){
			$realId = $row["id"];	
			$index ++;
		}
	
		if($authId !="" && $realId !="" && $authId != $realId){
			return false;
		}else{
			return true;
		}
	}
	
	private function cnlog($message){
		$mdate = date('Y m d H:i:s ');
		$fh = fopen($this->authlog, 'a'); 
		fwrite($fh, $mdate." ".$message."\n");
		fclose($fh);		
	}

	public function handleAction() {
		$sReturn = '';
		if($this->offersAction($this->sAction) || $rehaut) {
			if($rehaut) $this->sAction = "view";
			switch($this->sAction) {
				case 'view':
					// Check if user is already authenticated
					if(!isset($this->AUTHENTICATION) || !$this->AUTHENTICATION->isAuthenticated()) {
						//$this->cnlog("user not authenticated");
						// is there a parameter named centreonnagvis in the called nagvis uri  or a session var named centreonnagvis?
						if(isset($_GET["centreonnagvis"])){
							$this->SESS->set("centreonnagvis",intval($_GET["centreonnagvis"]));
						}else{
							//$this->cnlog("_GET centreonagvis was not found");
							return $this->go2login();
						}
						// initialise authentication and authorisation handler
						$this->AUTHENTICATION = new CoreAuthHandler($this->CORE, $this->SESS, $this->CORE->getMainCfg()->getValue('global', 'authmodule'));
						//$this->AUTHENTICATION = $this->CORE->getAuthentication();
						$this->AUTHORISATION = new CoreAuthorisationHandler($this->CORE, $this->AUTHENTICATION, $this->CORE->getMainCfg()->getValue('global', 'authorisationmodule'));
						// initialise db access 
						$host = $this->CORE->getMainCfg()->getValue('authmysqldb', 'host');
						$port = $this->CORE->getMainCfg()->getValue('authmysqldb', 'port');
						$user = $this->CORE->getMainCfg()->getValue('authmysqldb', 'user');
				        $password = $this->CORE->getMainCfg()->getValue('authmysqldb', 'password');
				        $database = $this->CORE->getMainCfg()->getValue('authmysqldb', 'database');		
						$db = new PDO("mysql:host=".$host.";port=".$port.";dbname=".$database,$user,$password);
						
						if(intval($this->SESS->get("centreonnagvis"))>0){
							////$this->cnlog("get session centreonagvis ok");
							// get user id from session table id
							$query = "
								SELECT count(user_id) AS num 
								FROM ".$this->centreondb.".session
								WHERE id=".$this->SESS->get("centreonnagvis")." AND
								ip_address = '".$_SERVER["REMOTE_ADDR"]."'
							";
							$result = $db->query($query)->fetch(PDO::FETCH_ASSOC);
							////$this->cnlog("There are ".$result["num"]." centreon users logged in with session table id ".$this->SESS->get("centreonnagvis")." and ip addres ".$_SERVER["REMOTE_ADDR"]);
							if(intval($result["num"]) != 1){
								////$this->cnlog("there was no active session detected");
								return $this->go2login();
							}else{
								////$this->cnlog("try to get nagvis credentials");
								// now get nagvis credentials
								$query = "
									SELECT 
										u.userId,u.name,u.password
									FROM 
										".$this->centreondb.".session s
										INNER JOIN ".$this->centreondb.".contact c ON s.user_id = c.contact_id
											INNER JOIN ".$this->centreondb.".acl_group_contacts_relations agcr ON c.contact_id = agcr.contact_contact_id
												INNER JOIN ".$this->centreondb.".acl_groups g ON agcr.acl_group_id = g.acl_group_id
													INNER JOIN ".$this->centreondb.".centreonnagvis cn ON g.acl_group_id = cn.acl_group_id
														INNER JOIN nagvis.users2roles u2r ON cn.roleId = u2r.roleId
															INNER JOIN nagvis.users u ON u2r.userId = u.userId
									WHERE 
										id=".$this->SESS->get("centreonnagvis")." AND
										ip_address = '".$_SERVER["REMOTE_ADDR"]."'									
								";
								//$this->cnlog($query);
								// take care that if there is more than 1 result, only the first one is used
								$row = $db->query($query)->fetch(PDO::FETCH_ASSOC);
								$this->AUTHENTICATION->passCredentials(array("user"=>$row["name"],"passwordHash"=>$row["password"]));
								if($this->AUTHENTICATION->isAuthenticated()){
									//$this->cnlog("get credentials ok !");
									Header('Location:'.CoreRequestHandler::getRequestUri($this->CORE->getMainCfg()->getValue('paths', 'htmlbase')));
								}else{
									//$this->cnlog("get credentials failed ".$row["name"]."/".$row["password"]);									
									return $this->go2login();
								}									
							}												
						}else{		
							return $this->go2login();
						}
					}else{
						// When the user is already authenticated redirect to start page (overview)
						////$this->cnlog("Allready authenticated !");
						header('Location:'.CoreRequestHandler::getRequestUri($this->CORE->getMainCfg()->getValue('paths', 'htmlbase')));
					}			
				break;
			}
		}
		
		return $sReturn;
				
	}
}

?>
