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
 
// Be Carefull with internal_name, it's case sensitive (with directory module name)
$module_conf['nagvis']["name"] = "nagvis";
$module_conf['nagvis']["rname"] = "nagvis Module";
$module_conf['nagvis']["mod_release"] = "2.1b";
$module_conf['nagvis']["infos"] = "Module nagvis";
$module_conf['nagvis']["is_removeable"] = "1";
$module_conf['nagvis']["author"] = "david GUENAULT <dguenault@monitoring-fr.org>";
$module_conf['nagvis']["lang_files"] = "1";
$module_conf['nagvis']["sql_files"] = "1";
$module_conf['nagvis']["php_files"] = "1";
$module_conf['nagvis']["svc_tools"] = "0";  
$module_conf['nagvis']["host_tools"] = "0";


?>
