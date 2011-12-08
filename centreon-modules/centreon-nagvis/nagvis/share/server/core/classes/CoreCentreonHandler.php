<?php
/*******************************************************************************
 *
 * CoreCentreonHandler.php - Class to handle Mysql databases
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
class CoreCentreonHandler {
	private $DB = null;
	
	public function __construct() {}
	
	public function open($host,$port,$user,$password,$database) {
		// First check if the php installation supports mysql
            if($this->checkMysqlSupport()) {
                try {
                    $this->DB = new PDO("mysql:host=".$host.";port=".$port.";dbname=".$database,$user,$password);
                } catch(PDOException $e) {
                    echo $e->getMessage();
                    return false;
                }
			
                if($this->DB === false || $this->DB === null) {
                    return false;
		} else {
                    return true;
                }
            } else {
                return false;
            }
	}
	
	public function tableExist($table) {
	  $RET = $this->query('SELECT COUNT(*) AS num FROM mysql_master WHERE type=\'table\' AND name='.$this->escape($table))->fetch(PDO::FETCH_ASSOC);
	  return intval($RET['num']) > 0;
	}
	
	public function query($query) {
		return $this->DB->query($query);
	}
	
	public function exec($query) {
		return $this->DB->exec($query);
	}
	
	public function count($query) {
            $RET = $this->query($query)->fetch(PDO::FETCH_ASSOC);
            return intval($RET['num']) > 0;
	}
	
	public function fetchAssoc($RES) {
		return $RES->fetch(PDO::FETCH_ASSOC);
	}
	
	public function close() {
		$this->DB = null;
	}
	
	public function escape($s) {
		return $this->DB->quote($s);
	}
	
	private function checkMysqlSupport($printErr = 1) {
		if(!class_exists('PDO')) {
			if($printErr === 1) {
				new GlobalMessage('ERROR', GlobalCore::getInstance()->getLang()->getText('Your PHP installation does not support PDO. Please check if you installed the PHP module.'));
			}
			return false;
		} elseif(!in_array('mysql', PDO::getAvailableDrivers())) {
			if($printErr === 1) {
				new GlobalMessage('ERROR', GlobalCore::getInstance()->getLang()->getText('Your PHP installation does not support PDO Mysql. Please check if you installed the PHP module.'));
			}
			return false;
		} else {
			return true;
		}
	}

	public function deletePermissions($mod, $name) {
		// Only create when not existing
		if($this->count('SELECT COUNT(*) AS num FROM perms WHERE `mod`='.$this->escape($mod).' AND act=\'view\' AND obj='.$this->escape($name)) > 0) {
			if(DEBUG&&DEBUGLEVEL&2) debug('auth.db: delete permissions for '.$mod.' '.$name);
			$this->DB->query('DELETE FROM perms WHERE `mod`='.$this->escape($mod).' AND obj='.$this->escape($name).'');
			$this->DB->query('DELETE FROM roles2perms WHERE permId=(SELECT permId FROM perms WHERE `mod`='.$this->escape($mod).' AND obj='.$this->escape($name).')');
		} else {
			if(DEBUG&&DEBUGLEVEL&2) debug('auth.db: won\'t delete '.$mod.' permissions '.$name);
		}
	}
	
	public function createMapPermissions($name) {
		// Only create when not existing
		if($this->count('SELECT COUNT(*) AS num FROM perms WHERE `mod`=\'Map\' AND act=\'view\' AND obj='.$this->escape($name)) <= 0) {
			if(DEBUG&&DEBUGLEVEL&2) debug('auth.db: create permissions for map '.$name);
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'view\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'getMapProperties\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'getMapObjects\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'getObjectStates\', '.$this->escape($name).')');

			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'edit\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'delete\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'doEdit\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'doDelete\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'doRename\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'modifyObject\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'createObject\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'deleteObject\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Map\', \'addModify\', '.$this->escape($name).')');
		} else {
			if(DEBUG&&DEBUGLEVEL&2) debug('auth.db: won\'t create permissions for map '.$name);
		}
		
		return true;
	}
	
	public function createAutoMapPermissions($name) {
		// Only create when not existing
		if($this->count('SELECT COUNT(*) AS num FROM perms WHERE `mod`=\'AutoMap\' AND act=\'view\' AND obj='.$this->escape($name)) <= 0) {
			if(DEBUG&&DEBUGLEVEL&2) debug('auth.db: create permissions for automap '.$name);
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'view\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'getAutomapProperties\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'getAutomapObjects\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'getObjectStates\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'parseAutomap\', '.$this->escape($name).')');

			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'edit\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'delete\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'doEdit\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'doDelete\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'doRename\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'modifyObject\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'createObject\', '.$this->escape($name).')');
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'AutoMap\', \'deleteObject\', '.$this->escape($name).')');
		} else {
			if(DEBUG&&DEBUGLEVEL&2) debug('auth.db: won\'t create permissions for automap '.$name);
		}
		
		return true;
	}
	
	public function createRotationPermissions($name) {
		// Only create when not existing
		if($this->count('SELECT COUNT(*) AS num FROM perms WHERE `mod`=\'Rotation\' AND act=\'view\' AND obj='.$this->escape($name)) <= 0) {
			if(DEBUG&&DEBUGLEVEL&2) debug('auth.db: create permissions for rotation '.$name);
			$this->DB->query('INSERT INTO perms (`mod`, act, obj) VALUES (\'Rotation\', \'view\', '.$this->escape($name).')');
		} else {
			if(DEBUG&&DEBUGLEVEL&2) debug('auth.db: won\'t create permissions for rotation '.$name);
		}
		
		return true;
	}

	private function addRolePerm($roleId, $mod, $act, $obj) {
		$this->DB->query('INSERT INTO roles2perms (roleId, permId) VALUES ('.$roleId.', (SELECT permId FROM perms WHERE `mod`=\''.$mod.'\' AND act=\''.$act.'\' AND obj=\''.$obj.'\'))');
	}

	public function updateDb() {

	}

	private function updateDb15b4() {

	}

	private function createVersionTable() {

	}
	
	public function createInitialDb() {

	}
}
?>
