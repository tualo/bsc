# tualo/bsc

`tualo/bsc` stellt grundlegende PHP-Bausteine für Tualo-Office-Anwendungen
bereit. Das Paket ergänzt den HTTP-Server `tualo/server` um
Anwendungszustand, Routing und Middleware, Benutzer- und Mandantensitzungen,
MySQL/MariaDB-Zugriff, Logging sowie Installations- und Diagnosebefehle. Es
enthält außerdem die Pug-Startseite und SQL-Dateien für Basisfunktionen und
Route-Scopes.

Wichtige Einstiegspunkte sind [`TualoApplication`](src/TualoApplication.php),
[`Route`](src/Route.php), [`Session`](src/Session.php) und der
[Kommandozeilen-Client](src/commandline/Cli.php). Die Composer-Abhängigkeiten
stehen in [`composer.json`](composer.json); weitere Tualo-Pakete können
zusätzliche Konfigurationen und Funktionen mitbringen.

Der Quellcode verwendet PHP-8-Syntax; für Datenbankverbindungen wird `mysqli`
benötigt. Die Anwendung benötigt außerdem ihre konfigurierte
Sitzungsdatenbank und ein beschreibbares Cache-Verzeichnis. Für einige
SQL-Installationsbefehle wird das externe Programm `mysql` verwendet. Das
Composer-Manifest nennt derzeit keine explizite PHP-Mindestversion.

## Konfiguration

Im üblichen Server- und CLI-Start wird
`<Anwendungsverzeichnis>/configuration/.htconfig` durch
`Tualo\Office\Server\Server::loadIniFile()` eingelesen. Der Server bestimmt
das Anwendungsverzeichnis anhand des Einstiegsskripts, die CLI verwendet das
aktuelle Arbeitsverzeichnis. Beim ersten CLI-Start kann eine fehlende Datei
mit einem `[ext-compiler]`-Grundabschnitt angelegt werden; dessen Einstellungen
werden vom Compiler-Paket verwendet.

Die Datei wird mit `INI_SCANNER_RAW` gelesen. Werte sind daher zunächst
Strings: Für Schalter sind `0` und `1` geeigneter als `false` oder `off`, die
als nichtleere Strings in PHP wahr sein können. Einzelne Aufrufstellen können
einen Wert trotzdem anders interpretieren. Listen wie `csp` und `pmp` müssen
als wiederholte `[]`-Einträge angegeben werden.

PHP-Code liest Werte mit
`TualoApplication::configuration($section, $key, $default)`. Ein leerer
Abschnitt bezeichnet einen Schlüssel außerhalb aller INI-Abschnitte. Wenn ein
Schlüssel fehlt, wird der angegebene Fallback zurückgegeben; ohne expliziten
Fallback ist das `false`.

Die folgenden Tabellen umfassen die im BSC-Code gelesenen Einstellungen sowie
die unmittelbar verwendeten Einstellungen seines Server-Starters. Andere
Pakete können weitere Abschnitte aus derselben Datei lesen. Eine ausführliche
Referenz mit Quellcodeverweisen steht in [CONFIGURATION.md](CONFIGURATION.md).

## HTTP-Sicherheitsheader der Startseite

[`Routes/Index.php`](src/Routes/Index.php) setzt beim Aufruf der Startseite
`/` sowohl `Permissions-Policy` als auch `Content-Security-Policy`. Die
Einstellungen gelten damit für diese Antwort; andere Routen oder ein
vorgelagerter Webserver können eigene Header setzen. Die Header ersetzen keine
serverseitige Anmeldung oder Berechtigungsprüfung.

### Permissions-Policy

`[tualo-backend] pmp` ist eine Liste von Direktiven. Ihre Einträge werden mit
Kommas zu einem Header verbunden. Ohne Konfiguration sendet der Code:

```http
Permissions-Policy: geolocation=(),microphone=(),sync-xhr=(self),camera=(),usb=(),unload=self
```

`()` schließt alle Origins aus; `(self)` erlaubt die Funktion für den eigenen
Origin. Browser-Unterstützung und die tatsächlich wirksame Policy hängen von
Browser und Kontext ab. Der unverändert ausgegebene Standard `unload=self`
entspricht nicht der üblichen Allowlist-Syntax mit Klammern; Browser können
diesen Eintrag ignorieren. Eine eigene Liste ersetzt die gesamte
Standardliste, sie wird nicht mit ihr zusammengeführt:

```ini
[tualo-backend]
pmp[]="geolocation=()"
pmp[]="microphone=()"
pmp[]="sync-xhr=(self)"
pmp[]="camera=()"
pmp[]="usb=()"
pmp[]="unload=(self)"
```

Dieses Beispiel ist an die jeweilige Anwendung anzupassen. Siehe auch die
[Permissions-Policy-Referenz von MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Permissions-Policy).

### Content-Security-Policy (CSP)

`[tualo-backend] csp` ist ebenfalls eine Liste; ihre Einträge werden mit
Semikolons verbunden. Ohne Konfiguration wird folgende Policy gesendet:

```http
Content-Security-Policy: base-uri 'self'; default-src 'self' data:; script-src 'self' 'unsafe-eval' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; form-action 'self'; img-src 'self' data:; worker-src 'self' 'unsafe-inline' * blob:; frame-src 'self';
```

Eine eigene Liste ersetzt die gesamte Vorgabe. Beispiel:

```ini
[tualo-backend]
csp[]="base-uri 'self'"
csp[]="default-src 'self'"
csp[]="script-src 'self'"
csp[]="style-src 'self'"
csp[]="form-action 'self'"
csp[]="img-src 'self' data:"
csp[]="worker-src 'self' blob:"
csp[]="frame-src 'self'"
```

Die Vorgabe enthält unter anderem `unsafe-eval`, `unsafe-inline` und einen
Wildcard für Worker. Das Beispiel ist keine universell passende
Produktions-Policy: benötigte Skripte, Styles, Frames und Origins müssen für
die jeweilige Installation geprüft werden.

## Konfigurationsübersicht

### Datenbank

| Abschnitt / Schlüssel | Verwendung und Fallback |
|---|---|
| `[database] db_name`, `db_user`, `db_pass`, `db_host` | Zugang zur Sitzungsdatenbank; alle vier Schlüssel müssen bei der Session-Initialisierung vorhanden sein. |
| `[database] db_port` | Datenbankport; Fallback der Verbindung: `3306`. |
| `[database] force_db_host`, `force_db_port` | Überschreiben Host bzw. Port aus dem jeweiligen Verbindungsdatensatz. |
| `[database] key_file`, `cert_file`, `ca_file` | TLS-Dateien für die Sitzungsdatenbank; für eine Mandantenverbindung können sie auch im Verbindungsdatensatz stehen. Alle drei müssen für den entsprechenden TLS-Zweig gesetzt sein. |
| `[database] ca_path`, `cipher_algos` | Werden vom Server-Loader übernommen, aber von `Session::newDBByRow()` nicht an den BSC-Datenbanktreiber weitergegeben. |
| `[database] force_client` | Erzwingt einen Mandanten beim Login und wird von Installationsbefehlen berücksichtigt. |
| `[database] lc_time_names` | Wenn gesetzt und nicht leer, wird `SET SESSION lc_time_names=...` ausgeführt. |
| `[database] set_names` | Wenn gesetzt und nicht leer, wird der enthaltene SQL-Befehl für die Verbindung ausgeführt, z. B. `SET NAMES 'utf8mb4'`. |
| `client.mysql.connect_timeout` (flach) | MySQL-Verbindungs-Timeout; Fallback: `10`. Der `configuration`-Befehl lässt diesen Schlüssel beim Neuschreiben der Datei aus. |

Der aktuelle BSC-MySQL-Treiber deaktiviert die Prüfung des Serverzertifikats;
konfigurierte TLS-Dateien allein garantieren daher keine verifizierte
Serveridentität. Passwörter und Schlüssel außerhalb der Versionskontrolle
bereitstellen und den Verbindungsweg entsprechend absichern.

Der Server-Loader verwendet folgende Umgebungsvariablen nur, wenn der
jeweilige `[database]`-Schlüssel in der Datei fehlt:

| Umgebungsvariable | Schlüssel |
|---|---|
| `TUALO_DB_SESSION` | `db_name` |
| `TUALO_DB_USER` / `TUALO_DB_PASSWORD` | `db_user` / `db_pass` |
| `TUALO_DB_HOST` / `TUALO_DB_PORT` | `db_host` / `db_port` |
| `TUALO_DB_KEY_FILE` / `TUALO_DB_CERT_FILE` / `TUALO_DB_CA_FILE` | `key_file` / `cert_file` / `ca_file` |
| `TUALO_DB_CA_PATH` / `TUALO_DB_CIPHER_ALGOS` | `ca_path` / `cipher_algos`; im BSC-Treiber nicht weitergegeben |

Alte flache INI-Schlüssel `__SESSION_DSN__`, `__SESSION_USER__`,
`__SESSION_PASSWORD__`, `__SESSION_HOST__` und `__SESSION_PORT__`
überschreiben, wenn alle fünf vorhanden sind, die entsprechenden
`[database]`-Werte. Ebenso überschreiben `FORCE_DB_HOST` und `FORCE_DB_PORT`
die jeweiligen `force_db_*`-Werte; die drei gemeinsam gesetzten
`__DB_SSL_KEY__`, `__DB_SSL_CERT__` und `__DB_SSL_CA__` überschreiben die
TLS-Dateien.

### Darstellung und Dateien

| Abschnitt / Schlüssel | Verwendung und Fallback |
|---|---|
| `[tualo-backend] pmp`, `csp` | Listen für die HTTP-Header der Startseite; siehe oben. |
| `[tualo-backend] pugfile` | Startseiten-Template; Fallback: `src/tpl/pages/basic/index.pug`. |
| `[tualo-backend] maintenance` | Template, wenn `maintanceMode` auf `on` steht; Fallback: `src/tpl/pages/basic/maintance.pug`. |
| `[tualo-backend] shortcut_iconurl` | Icon-URL; ohne Wert werden je nach Größe `./bscimg/favicon-32x32.png` bzw. `./bscimg/favicon-128x128.png` verwendet. |
| `[tualo-backend] public_path` | Verzeichnis für `/public/...`; ohne Wert liefert diese Route keine Dateien aus. Nur bewusst freigegebene Dateien ablegen. |

### Login, Netzwerk und CORS

| Abschnitt / Schlüssel | Verwendung und Fallback |
|---|---|
| `FORCE_CLIENT` (flach) | Erzwingt beim Login einen Mandanten und hat Vorrang vor `[database] force_client`. |
| `[cookie] cookie_post_field_name` | POST-Feld, dessen nichtleerer Wert als Session-ID verwendet wird; Fallback: leer, also deaktiviert. |
| `[cookie] backend_name`, `authorization_name`, `cms_name` | Vom Server verwendete Session-Cookie-Namen; Fallbacks: `tualo`, `tualoauth`, `tualocms`. |
| `[cookie] cms_samesite` | Wird vom Server für den OAuth-Pfad gelesen. Die aktuelle Zuweisung übergibt das Ergebnis eines Vergleichs statt des konfigurierten Strings; Verhalten vor Verwendung prüfen. |
| `[options_request] accessControlAllowOrigin` | Origin für `OPTIONS` und Login; dort Fallback `*`. Bei normalen Router-Requests wird der Header nur bei gesetztem Wert hinzugefügt. |
| `[oauth] accessControlAllowOrigin` | Origin bei OAuth-Authentifizierung; Fallback `*`. |
| `[oauth] key` | Optionaler Pfad zum PGP-Schlüssel für OAuth-Token; erfordert bei Verwendung das Paket `TualoPGP`. |
| `[basic] forward_headers` | JSON-Array von Servervariablen für die Client-IP. Fallback: `HTTP_X_DDOSPROXY`, `HTTP_X_FORWARDED_FOR`, `HTTP_CLIENT_IP`, `REMOTE_ADDR`. |
| `__CMS_ALLOWED_IP_FIELD__` (flach) | Servervariable für die Client-IP-Middleware; sonst `REMOTE_ADDR`. |
| `[basic] log_scope_access` | Der String `1` aktiviert das Protokollieren von Scope-Zugriffen in der Session. |
| `[compiler] allowedExtern` | Für `needsActiveLogin()` bei bool-wahrem Wert kein Login erforderlich; Fallback `false`. |
| `[compiler] allowed_clientip_headers` | JSON-Array für die IP-Prüfung von `needsActiveLogin()`; Fallback wie `forward_headers`. |
| `[compiler] allowed_cidrs` | Leerzeichengetrennte erlaubte Netze; Fallback `127.0.0.1`. Eine passende IP benötigt laut diesem Helfer keinen Login. |

Die letzten drei Schlüssel werden vom Helfer auch in einem anderen Abschnitt
gelesen, wenn dieser beim Aufruf angegeben wird. Beispiel für ein JSON-Array
in der **roh** gelesenen INI-Datei:

```ini
[basic]
forward_headers=["HTTP_X_FORWARDED_FOR", "REMOTE_ADDR"]
```

Proxy-Header nur von vertrauenswürdigen Proxies übernehmen und CORS-Origins
bewusst einschränken.

### Ausführung und Logging

| Abschnitt / Schlüssel | Verwendung und Fallback |
|---|---|
| `[sanitizer] disabled` | Bei bool-wahrem Wert werden unerwartete Felder nicht als Fehler behandelt und der Sanitizer setzt für ungültige Eingaben keinen HTTP-400-Status. Ungültige Eingaben können dennoch zu einer Fehlerantwort führen. |
| `[deferred] enabled` | Aktiviert aufgeschobene SQL-Aufgaben; Fallback `false`. |
| `[deferred] use_by_user` | Bei `1` wird `proc_deferred_sql_tasks_by_current_user()` statt `proc_deferred_sql_tasks()` aufgerufen. |
| `use_base_url` (flach) | Überschreibt die ermittelte Basis-URL für zeitversetzte Routenaufrufe. |
| `TIMEZONE` (flach) | Zeitzone für `date_default_timezone_set()`; sonst gilt die PHP-Standardzeitzone. |
| `[php-settings] <Direktive>` | PHP-INI-Werte für die Middleware, gesetzt mit `ini_set()`. |
| `[php-client] <Direktive>` | PHP-INI-Werte beim CLI-Start. |
| `[php-server] <Direktive>` | PHP-INI-Werte beim Webstart über `tualo/server`. |
| `[logger-file] filename`, `level` | Aktivieren den Datei-Handler, wenn beide Werte gesetzt und die Datei beschreibbar ist. |
| `[logger-slack] token`, `channel`, `botname`, `useAttachment`, `iconEmoji`, `level` | Slack-Handler; `token` und `channel` aktivieren ihn. `level` sollte explizit gesetzt werden. |
| `[logger-slackwebhook] url`, `channel`, `botname`, `useAttachment`, `iconEmoji`, `level` | Weiterer Slack-Handler; `url` und `channel` aktivieren ihn. Der aktuelle Code verwendet `SlackHandler` und greift für einige Optionen auf `[logger-slack]` zurück. |
| `[logger-options] ROUTERUN` | `1` aktiviert zusätzliche Router-Meldungen zu Session-Pfaden. |
| `[logger-options] TualoApplicationTiming` | Im auskommentierten Timing-Code vorgesehen; derzeit ohne Wirkung. |

Beim Webstart verwirft der aktuelle Server-Loader `[php-server]`, wenn der
Abschnitt `[database]` fehlt. Logger werden pro Kanal zwischengespeichert;
Konfigurationsänderungen erfordern üblicherweise einen neuen Prozess.

Der optionale Datenbank-Session-Handler verwendet die PHP-Konstanten
`__SESSION_DSN__`, `__SESSION_USER__`, `__SESSION_PASSWORD__`,
`__SESSION_HOST__`, `__SESSION_PORT__` und optional die drei
`__DB_SSL_*__`-Konstanten. Diese PHP-Konstanten sind nicht dasselbe wie die
gleichnamigen flachen INI-Werte. Für seine Verschlüsselung liest er
`__USE_DB_SESSION_HANLDER_ENCRYPTION__` (Schreibweise wie im Code); ohne
gesetzten Wert verwendet er einen fest kodierten, für Produktion ungeeigneten
Fallback. Der Handler ist nicht Teil der normalen `Session`-Middleware und
muss gesondert registriert werden.

Die PHP-Konstante `__LOG_DB_COMMANDS__` aktiviert ein SQL-Log unter dem
angegebenen Dateipfad. Dieses kann Abfragewerte enthalten und muss geschützt
werden. Instanzbezogenes SQL-Logging lässt sich außerdem über
`Database::setLogFile()`, `enableLogging()` und `disableLogging()` einstellen.
`__QUERY_CHECK__` wird im Diagnosecode referenziert; der Aufruf von
`check_stop()` in `execute()` liegt derzeit nach den Rückgaben und ist daher
kein verlässlicher Konfigurationsschalter.

## Route-Scopes

Route-Scopes sind serverseitige Berechtigungen und unabhängig von der
Permissions-Policy des Browsers. `Route::add()` verwendet standardmäßig den
Scope `basic` und verlangt standardmäßig keine aktive Session. Für angemeldete
Benutzer ermittelt `Session::getUserScopes()` die erlaubten Scopes aus
`route_scopes`, `route_scopes_permissions` (`allowed=1`) und
`view_session_groups` und speichert sie in der Session zwischen.

`Route::runpath()` protokolliert die Scope-Prüfung, verweigert bei einem
negativen Ergebnis aber nur Scopes **außer** `basic`. Eine Route mit
`needActiveSession=true` verlangt zusätzlich eine angemeldete Session.
Anonyme Benutzer erhalten bei der Scope-Prüfung nur für `public` eine
positive Antwort; für angemeldete Benutzer wird auch `public` über die
Gruppenscopes geprüft. Diese Regeln sind beim Registrieren geschützter Routen
zu berücksichtigen.

Das folgende bestehende SQL-Beispiel versucht, bisher keiner Gruppe erlaubte
Scopes der Gruppe `administration` zuzuordnen. Es sollte nur nach Prüfung
der benötigten Rechte ausgeführt werden; `INSERT IGNORE` ändert einen bereits
vorhandenen Eintrag nicht:

```sql
insert ignore into route_scopes_permissions (scope, `group`, allowed)
select scope, 'administration', 1
from route_scopes
where scope not in (select scope from route_scopes_permissions where allowed = 1);
```

## CLI und Laufzeitwerte

Der CLI-Client bietet unter anderem `configuration`, `setup`, `systemcheck`,
`precheck`, `postcheck` und Installationsbefehle. `configuration` setzt mit
`--key`, `--value` und optional `--section` einen Wert in der INI-Datei:

```bash
./tm configuration --section tualo-backend --key public_path --value /path/to/public
```

Beim Neuschreiben wird `client.mysql.connect_timeout` ausgelassen. Geheimnisse
nicht über Shell-Historie oder Kommandozeilenargumente offenlegen.

Zusätzlich setzt der Starter Laufzeitwerte über `TualoApplication::set()`,
insbesondere `basePath`, `cachePath`, `configurationFile` und `session`.
`maintanceMode=on` wählt das Wartungs-Template; `htmltitle` und `message`
beeinflussen die Startseite und fallen jeweils auf `tualo office` zurück.
Das Pug-Cache-Verzeichnis unter `cachePath` muss beschreibbar sein.
