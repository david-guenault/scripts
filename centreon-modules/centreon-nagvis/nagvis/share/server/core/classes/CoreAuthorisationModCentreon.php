<?php
/*******************************************************************************
 *
 * CoreAuthorisationModCentreon.php - Authorsiation module based on Mysql
 *
 * Copyright (c) 2004-2010 NagVis Project (Contact: info@nagvis.org)
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
 ******************************************************************************/

/**
 * @author David GUENAULT <dguenault@nagios-fr.org>
 */
class CoreAuthorisationModCentreon extends CoreAuthorisationModule {
	private $AUTHENTICATION = null;
	private $CORE = null;
	private $DB = null;
	
	public function __construct(GlobalCore $CORE, CoreAuthHandler $AUTHENTICATION) {
		$this->AUTHENTICATION = $AUTHENTICATION;
		$this->CORE = $CORE;
		//$this->cnlog("init CoreAuthorisationModMysql");
		$this->DB = new CoreCentreonHandler();
		
		// Open mysql database
		if(!$this->DB->open(
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'host'),
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'port'),
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'user'),
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'password'),
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'database')
                        )) {
			new GlobalMessage('ERROR', GlobalCore::getInstance()->getLang()->getText('Unable to open auth database ([DB])',
                                      Array('DB' => $this->CORE->getMainCfg()->getValue('authmysqldb', 'database'))));
		} //else {
//			// Create initial db scheme if needed
//			if(!$this->DB->tableExist('users')) {
//				$this->DB->createInitialDb();
//			} else {
//				// Maybe an update is needed
//				$this->DB->updateDb();
//			}
//		}
	}
	
	private function cnlog($message){
		$myFile="/opt/centreon/www/modules/nagvis/logs/cn.log";
		$mdate = date('Y m d H:i:s ');
		$fh = fopen($myFile, 'a'); 
		fwrite($fh, $mdate." ".$message."\n");
		fclose($fh);		
	}	
	
	public function deletePermission($mod, $name) {
		if($name === '') {
			return false;
		}
		
		switch($mod) {
			case 'Map':
			case 'AutoMap':
			case 'Rotation':
				return $this->DB->deletePermissions($mod, $name);
			default:
				return false;
			break;
		}
	}
	
	public function createPermission($mod, $name) {
		if($name === '') {
			return false;
		}
		
		switch($mod) {
			case 'Map':
				return $this->DB->createMapPermissions($name);
			case 'AutoMap':
				return $this->DB->createAutoMapPermissions($name);
			case 'Rotation':
				return $this->DB->createRotationPermissions($name);
			default:
				return false;
			break;
		}
	}
	
	public function deleteRole($roleId) {
		// Delete user
		$this->DB->exec('DELETE FROM roles WHERE roleId='.$this->DB->escape($roleId));
		
		// Delete role permissions
		$this->DB->exec('DELETE FROM roles2perms WHERE roleId='.$this->DB->escape($roleId));
		
		// Check result
		if(!$this->checkRoleExists($roleId)) {
			return true;
		} else {
			return false;
		}
	}
	
	public function deleteUser($userId) {
		// Delete user
		$this->DB->exec('DELETE FROM users WHERE userId='.$this->DB->escape($userId));
		
		// Delete user roles
		$this->DB->exec('DELETE FROM users2roles WHERE userId='.$this->DB->escape($userId));
		
		// Check result
		if($this->checkUserExistsById($userId) <= 0) {
			return true;
		} else {
			return false;
		}
	}
	
	public function updateUserRoles($userId, $roles) {
		// First delete all role perms
		$this->DB->exec('DELETE FROM users2roles WHERE userId='.$this->DB->escape($userId));
		
		// insert new user roles
		foreach($roles AS $roleId) {
			$this->DB->exec('INSERT INTO users2roles (userId, roleId) VALUES ('.$this->DB->escape($userId).', '.$this->DB->escape($roleId).')');
		}
		
		return true;
	}
	
	public function getUserRoles($userId) {
		$aRoles = Array();
		
		// Get all the roles of the user
	  $RES = $this->DB->query('SELECT users2roles.roleId AS roleId, roles.name AS name FROM users2roles LEFT JOIN roles ON users2roles.roleId=roles.roleId WHERE userId='.$this->DB->escape($userId));
	  while($data = $this->DB->fetchAssoc($RES)) {
	  	$aRoles[] = $data;
	  }
	  
	  return $aRoles;
	}
	
	public function getAllRoles() {
		$aRoles = Array();
		
		// Get all the roles of the user
	  $RES = $this->DB->query('SELECT roleId, name FROM roles ORDER BY name');
	  while($data = $this->DB->fetchAssoc($RES)) {
	  	$aRoles[] = $data;
	  }
	  
	  return $aRoles;
	}
	
	public function getRoleId($sRole) {
		$ret = $this->DB->fetchAssoc($this->DB->query('SELECT roleId FROM roles WHERE name='.$this->DB->escape($sRole)));
		
		return intval($ret['roleId']);
	}
	
	public function getAllPerms() {
		$aPerms = Array();
		
		// Get all the roles of the user
	  $RES = $this->DB->query('SELECT permId, `mod`, act, obj FROM perms ORDER BY `mod`,act,obj');
	  while($data = $this->DB->fetchAssoc($RES)) {
	  	$aPerms[] = $data;
	  }
	  
	  return $aPerms;
	}
	
	public function getRolePerms($roleId) {
		$aRoles = Array();
		
		// Get all the roles of the user
	  $RES = $this->DB->query('SELECT permId FROM roles2perms WHERE roleId='.$this->DB->escape($roleId));
	  while($data = $this->DB->fetchAssoc($RES)) {
	  	$aRoles[$data['permId']] = true;
	  }
	  
	  return $aRoles;
	}
	
	public function updateRolePerms($roleId, $perms) {
		// First delete all role perms
		$this->DB->exec('DELETE FROM roles2perms WHERE roleId='.$this->DB->escape($roleId));
		
		// insert new role perms
		foreach($perms AS $permId => $val) {
			if($val === true) {
				$this->DB->query('INSERT INTO roles2perms (roleId, permId) VALUES ('.$this->DB->escape($roleId).', '.$this->DB->escape($permId).')');
			}
		}
		
		return true;
	}
	
	public function checkRoleExists($name) {
		if($this->DB->count('SELECT COUNT(*) AS num FROM roles WHERE name='.$this->DB->escape($name)) > 0) {
			return true;
		} else {
			return false;
		}
	}
	
	public function createRole($name) {
		$this->DB->exec('INSERT INTO roles (name) VALUES ('.$this->DB->escape($name).')');
		
		// Check result
		if($this->checkRoleExists($name)) {
			return true;
		} else {
			return false;
		}
	}
	
	public function parsePermissions() {
		$aPerms = Array();
		
		$sUsername = $this->AUTHENTICATION->getUser();
		
		// Only handle known users
		$userId = $this->getUserId($sUsername);
		if($userId > 0) {
		  // Get all the roles of the user
		  $RES = $this->DB->query('SELECT perms.mod AS `mod`, perms.act AS act, perms.obj AS obj '.
		                          'FROM users2roles '.
		                          'INNER JOIN roles2perms ON roles2perms.roleId = users2roles.roleId '.
		                          'INNER JOIN perms ON perms.permId = roles2perms.permId '.
		                          'WHERE users2roles.userId = '.$this->DB->escape($userId));
		  
			while($data = $this->DB->fetchAssoc($RES)) {
				if(!isset($aPerms[$data['mod']])) {
					$aPerms[$data['mod']] = Array();
				}
				
				if(!isset($aPerms[$data['mod']][$data['act']])) {
					$aPerms[$data['mod']][$data['act']] = Array();
				}
				
				if(!isset($aPerms[$data['mod']][$data['act']][$data['obj']])) {
					$aPerms[$data['mod']][$data['act']][$data['obj']] = Array();
				}
			}
		}
		
		return $aPerms;
	}
	
	private function checkUserExistsById($id) {
		return $this->DB->count('SELECT COUNT(*) AS num FROM users WHERE userId='.$this->DB->escape($id));
	}
	
	public function getUserId($sUsername) {
		$ret = $this->DB->fetchAssoc($this->DB->query('SELECT userId FROM users WHERE name='.$this->DB->escape($sUsername)));
		
		return intval($ret['userId']);
	}
}
?>
