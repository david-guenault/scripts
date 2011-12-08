<?php
/*******************************************************************************
 *
 * CoreAuthCentreon.php - Authentication module based on a Mysql database
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
 * @author David GUENAULT <dguenault@monitoring-fr.org>
 */



class CoreAuthModCentreon extends CoreAuthModule {
	private $CORE;
	private $USERCFG;
	private $SESSION;
	private $iUserId = -1;
	private $sUsername = '';
	private $sPassword = '';
	private $sPasswordnew = '';
	private $sPasswordHash = '';
	private $authlog;
	private $sCentreonNagvis = null;	
	
	public function __construct(GlobalCore $CORE) {
		$this->CORE = $CORE;
		parent::$aFeatures = Array(
			// General functions for authentication
			'passCredentials' => true,
			'getCredentials' => true,
			'isAuthenticated' => true,
			'getUser' => true,
			'getUserId' => true,
			
			// Changing passwords
			'passNewPassword' => false,
			'changePassword' => false,
			'passNewPassword' => false,
			
			// Managing users
			'createUser' => false,
		);
		$this->authlog = $this->CORE->getMainCfg()->getValue('authmysqldb', 'authlog');
		
		$this->DB = new CoreCentreonHandler();
		
		// Open mysql database
		if(!$this->DB->open(
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'host'),
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'port'),
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'user'),
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'password'),
                                        $this->CORE->getMainCfg()->getValue('authmysqldb', 'database')
                        )) {
			new GlobalMessage(
                                'ERROR', GlobalCore::getInstance()->getLang()->getText('Unable to open auth database ([DB])',
                                Array('DB' => $this->CORE->getMainCfg()->getValue('authmysqldb', 'database')))
                        );
		}
		
		if(isset($_GET["centreonnagvis"])){
			if (isset($_SESSION["centreonnagvis"])){
				$cursess = $_SESSION["centreonnagvis"]; 
				if($cursess != $_GET["centreonnagvis"]){
					//$this->cnlog("Current session and proposed one differs !(".$_GET["centreonnagvis"].",".$cursess.") => we reset the session and redirect");
					session_destroy();
					//$this->cnlog('Location:'.CoreRequestHandler::getRequestUri($this->CORE->getMainCfg()->getValue('paths', 'htmlbase')));									
					header('Location:'.CoreRequestHandler::getRequestUri($this->CORE->getMainCfg()->getValue('paths', 'htmlbase')));
				}
			}
		}		
		
		
    }

    private function cnlog($message){
		$mdate = date('Y m d H:i:s ');
		$fh = fopen($this->authlog, 'a'); 
		fwrite($fh, $mdate." ".$message."\n");
		fclose($fh);		
	}    
    
    public function getcentreonnagvis(){
		new GlobalMessage("NOTE", $this->SESSION->get("centreonnagvis"));    	
    }
        
	public function getAllUsers() {
            $aPerms = Array();
            // Get all the roles of the user
            $RES = $this->DB->query('SELECT userId, name FROM users ORDER BY name');
            while($data = $this->DB->fetchAssoc($RES)) {
                $aPerms[] = $data;
            }
            return $aPerms;
	}
	
	public function checkUserExists($name) {
            return $this->DB->count('SELECT COUNT(*) AS num FROM users WHERE name='.$this->DB->escape($name));
	}
	
	private function checkUserAuth($bTrustUsername = AUTH_NOT_TRUST_USERNAME) {
			if($bTrustUsername === AUTH_NOT_TRUST_USERNAME) {
                $query = 'SELECT userId FROM users WHERE name='.$this->DB->escape($this->sUsername).' AND password='.$this->DB->escape($this->sPasswordHash);
            } else {
                $query = 'SELECT userId FROM users WHERE name='.$this->DB->escape($this->sUsername);
            }
            $ret = $this->DB->fetchAssoc($this->DB->query($query));
            
            return intval($ret['userId']);
	}
	

	
	
	private function updatePassword() {
		$this->DB->query('UPDATE users SET password='.$this->DB->escape($this->sPasswordHash).' WHERE name='.$this->DB->escape($this->sUsername));
	}
	
	private function addUser($user, $hash) {
		$this->DB->query('INSERT INTO users (name,password) VALUES ('.$this->DB->escape($user).','.$this->DB->escape($hash).')');
	}
	
	public function passCredentials($aData) {
		////$this->cnlog("passCredentials");
		
		
		
		if(isset($aData['user'])) {
			$this->sUsername = $aData['user'];
		}
		if(isset($aData['password'])) {
			$this->sPassword = $aData['password'];
			
			// Remove the password hash when setting a new password
			$this->sPasswordHash = '';
		}
		if(isset($aData['passwordHash'])) {
			$this->sPasswordHash = $aData['passwordHash'];
		}
	}
	
	public function passNewPassword($aData) {
		if(isset($aData['user'])) {
			$this->sUsername = $aData['user'];
		}
		if(isset($aData['password'])) {
			$this->sPassword = $aData['password'];
			
			// Remove the password hash when setting a new password
			$this->sPasswordHash = '';
		}
		if(isset($aData['passwordNew'])) {
			$this->sPasswordNew = $aData['passwordNew'];
		}
	}
	
	public function getCredentials() {
		////$this->cnlog("getCredentials");
		
		return Array('user' => $this->sUsername,
		             'passwordHash' => $this->sPasswordHash,
		             'userId' => $this->iUserId);
	}
	
	public function createUser($user, $password) {
		$bReturn = false;
		
		// Compose the password hash
		$hash = $this->createHash($password);
		
		// Create user
		$this->addUser($user, $hash);
		
		// Check result
		if($this->checkUserExists($user)) {
			$bReturn = true;
		} else {
			$bReturn = false;
		}
		
		return $bReturn;
	}
	
	public function changePassword() {
		$bReturn = false;
		
		// Check the authentication with the old password
		if($this->isAuthenticated()) {
			// Set new password to current one
			$this->sPassword = $this->sPasswordNew;
			
			// Compose the new password hash
			$this->sPasswordHash = $this->createHash($this->sPassword);
			
			// Update password
			$this->updatePassword();
			
			$bReturn = true;
		} else {
			$bReturn = false;
		}
		
		return $bReturn;
	}
	
	public function isAuthenticated($bTrustUsername = AUTH_NOT_TRUST_USERNAME) {
		$bReturn = false;
		
		
		// Only handle known users
		if($this->sUsername !== '' && $this->checkUserExists($this->sUsername)) {
		
			
			// Try to calculate the passowrd hash only when no hash is known at
			// this time. For example when the user just entered the password
			// for logging in. If the user is already logged in and this is just
			// a session check don't try to rehash the password.
			if($bTrustUsername === AUTH_NOT_TRUST_USERNAME && $this->sPasswordHash === '') {
				// Compose the password hash for comparing with the stored hash
				$this->sPasswordHash = $this->createHash($this->sPassword);
			}
			
			// Check the password hash
			$userId = $this->checkUserAuth($bTrustUsername);
			if($userId > 0) {
				$this->iUserId = $userId;
				$bReturn = true;
			} else {
				$bReturn = false;
			}
		} else {
			$bReturn = false;
		}
		
		return $bReturn;
	}
	
	public function getUser() {
		return $this->sUsername;
	}
	
	public function getUserId() {
		return $this->iUserId;
	}
	
	private function createHash($password) {
		return sha1(AUTH_PASSWORD_SALT.$password);
	}
}
?>
