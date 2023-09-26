delimiter ;


INSERT IGNORE INTO SESSIONDB.macc_menu (id, title, path, param, component, priority, target, path2, automenu, use_iframe, iconcls, route_to) VALUES ('f30bc380-3216-11ee-ae05-002590c72640', 'Setup', '', null, '', 2, null, '', 0, 1, 'fa fa-cogs', '');
INSERT IGNORE INTO SESSIONDB.macc_menu (id, title, path, param, component, priority, target, path2, automenu, use_iframe, iconcls, route_to) VALUES ('087743ec-3217-11ee-b860-002590c4e7c6', 'Benutzer', '', null, '', 1, null, 'f30bc380-3216-11ee-ae05-002590c72640', 0, 1, 'fa fa-users', '#usereditor');
INSERT IGNORE INTO SESSIONDB.macc_menu (id, title, path, param, component, priority, target, path2, automenu, use_iframe, iconcls, route_to) VALUES ('1ace16ec-3217-11ee-ae05-002590c72640', 'Menü', '', null, '', 2, null, 'f30bc380-3216-11ee-ae05-002590c72640', 0, 1, 'fa fa-list', '#menueditor');
INSERT IGNORE INTO SESSIONDB.macc_menu (id, title, path, param, component, priority, target, path2, automenu, use_iframe, iconcls, route_to) VALUES ('2392d8cd-3217-11ee-ae05-002590c72640', 'Gruppen', '', null, '', 0, null, 'f30bc380-3216-11ee-ae05-002590c72640', 0, 1, 'typcn typcn-group', '#groupeditor');
INSERT IGNORE INTO SESSIONDB.macc_menu (id, title, path, param, component, priority, target, path2, automenu, use_iframe, iconcls, route_to) VALUES ('2392d8cd-3217-11ee-ae05-002590c72641', 'Datenstämme', '', null, '', 0, null, 'f30bc380-3216-11ee-ae05-002590c72640', 0, 1, 'entypo et-database', '#ds/ds');



INSERT IGNORE INTO SESSIONDB.rolle_menu (id, rolle, typ) VALUES ('087743ec-3217-11ee-b860-002590c4e7c6', 'administration', null);
INSERT IGNORE INTO SESSIONDB.rolle_menu (id, rolle, typ) VALUES ('1ace16ec-3217-11ee-ae05-002590c72640', 'administration', null);
INSERT IGNORE INTO SESSIONDB.rolle_menu (id, rolle, typ) VALUES ('2392d8cd-3217-11ee-ae05-002590c72640', 'administration', null);
INSERT IGNORE INTO SESSIONDB.rolle_menu (id, rolle, typ) VALUES ('f30bc380-3216-11ee-ae05-002590c72640', 'administration', null);
INSERT IGNORE INTO SESSIONDB.rolle_menu (id, rolle, typ) VALUES ('2392d8cd-3217-11ee-ae05-002590c72641', 'administration', null);


