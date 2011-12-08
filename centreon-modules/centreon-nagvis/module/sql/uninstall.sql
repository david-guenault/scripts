DELETE FROM `options` WHERE `key` LIKE 'centreon-nagvis-%';
DELETE FROM `topology` WHERE `topology_page` IN (403,613,61301,61302,61303);
