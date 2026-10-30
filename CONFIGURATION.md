# BSC-Konfigurationsoptionen

Diese Übersicht dokumentiert Konfigurationswerte, die im Quellcode des Pakets
`bsc` gelesen werden. Sie ist keine vollständige Liste aller Optionen anderer
Tualo-Pakete oder der Anwendung.

## Konfigurationsdatei und Zugriff

Die Kommandozeileninitialisierung des Pakets verwendet
`<basePath>/configuration/.htconfig` und lädt die INI-Datei über
`Tualo\Office\Server\Server::loadIniFile()`. Fehlt die Datei, legt der
Kommandozeilen-Entry-Point eine Grunddatei mit dem Abschnitt `[ext-compiler]`
an. Die eigentliche Interpretation der INI-Datei erfolgt im Paket
`tualo/server` mit `INI_SCANNER_RAW`: Werte werden als Strings gelesen.
Insbesondere sind bei boolesch ausgewerteten Optionen `0` und `1` geeigneter
als die nichtleeren Strings `false` oder `off`.

`TualoApplication::configuration($section, $key, $defaultReturn = false)`
liest einen Wert aus der geladenen Konfiguration:

- Bei einem nicht leeren Abschnitt wird `[$section][$key]` gelesen.
- Bei einem leeren Abschnitt wird ein flacher Schlüssel `$key` gelesen.
- Fehlt der Schlüssel oder ist sein Wert `null`, wird `$defaultReturn`
  zurückgegeben.
- Der Standardwert ist `false`; einige Optionen haben im aufrufenden Code
  einen anderen expliziten Fallback.

Die Kommandozeile `configuration` kann Werte in `.htconfig` setzen. Ohne
`section` wird ein flacher Eintrag geschrieben, mit `section` ein Eintrag in
einem INI-Abschnitt. Die Optionen heißen `--key`, `--value` und optional
`--section`.

## Optionen

### Datenbank (`[database]` und flacher Schlüssel)

| Schlüssel | Verwendung und Verhalten |
|---|---|
| `db_name` | Name der Sitzungsdatenbank; wird unter anderem bei Setup- und Benutzerbefehlen gelesen. |
| `db_user` | Datenbankbenutzer; Setup verwendet `localhost` als Fallback. |
| `db_pass` | Datenbankpasswort; für die Sitzungsdatenbank muss dieser Schlüssel gesetzt sein. |
| `db_host` | Datenbankhost; für die Sitzungsdatenbank muss dieser Schlüssel gesetzt sein. |
| `db_port` | Datenbankport; Setup verwendet `3306` als Fallback. |
| `force_db_host` | Überschreibt beim Aufbau einer Datenbankverbindung den Host aus dem Verbindungsdatensatz. |
| `force_db_port` | Überschreibt beim Aufbau einer Datenbankverbindung den Port aus dem Verbindungsdatensatz. |
| `key_file`, `cert_file`, `ca_file` | Optionale TLS-Dateipfade, die beim Aufbau einer Verbindung aus dem Datenbankdatensatz übernommen werden. |
| `force_client` | Erzwingt eine Client-ID statt der beim Login übermittelten ID; wird auch von Installationsbefehlen ausgewertet. |
| `lc_time_names` | Wenn gesetzt und nicht leer, wird `SET SESSION lc_time_names=...` ausgeführt. |
| `set_names` | Wenn gesetzt und nicht leer, wird der enthaltene SQL-Befehl für die Verbindung ausgeführt (zum Beispiel `SET NAMES ...`). |
| `client.mysql.connect_timeout` (flach) | MySQL-Verbindungs-Timeout; Fallback im Datenbanktreiber: `10`. Die CLI weist `0` nur einer lokalen Kopie der Konfiguration zu; der `configuration`-Befehl lässt den Schlüssel beim Neuschreiben der Datei aus. |

Die Sitzungsdatenbank wird beim Session-Aufbau nur initialisiert, wenn
`db_name`, `db_user`, `db_pass` und `db_host` vorhanden sind.

Der Server-Loader ergänzt fehlende `[database]`-Werte aus
`TUALO_DB_SESSION`, `TUALO_DB_USER`, `TUALO_DB_PASSWORD`, `TUALO_DB_HOST`,
`TUALO_DB_PORT`, `TUALO_DB_KEY_FILE`, `TUALO_DB_CERT_FILE` und
`TUALO_DB_CA_FILE`. `TUALO_DB_CA_PATH` und `TUALO_DB_CIPHER_ALGOS` werden
ebenfalls eingelesen, aber von `Session::newDBByRow()` nicht an den BSC-Treiber
weitergegeben. Sind die fünf flachen `__SESSION_*__`-Werte gemeinsam
vorhanden, überschreiben sie die entsprechenden Datenbankwerte.
`FORCE_DB_HOST` und `FORCE_DB_PORT` sowie die drei gemeinsam gesetzten
flachen `__DB_SSL_*__`-Werte überschreiben die jeweiligen Optionen.

Der BSC-MySQL-Treiber deaktiviert die Serverzertifikatsprüfung; TLS-Dateien
allein gewährleisten daher keine verifizierte Serveridentität.

### Anwendung und Darstellung (`[tualo-backend]`)

| Schlüssel | Verwendung und Fallback |
|---|---|
| `csp` | Content-Security-Policy, die auf der Startseite als `Content-Security-Policy`-Header ausgegeben wird. Der Fallback enthält Regeln für `self`, Skripte, Styles, Bilder, Worker und Frames. |
| `pmp` | Permissions-Policy der Startseite als Array von Direktiven. Ohne Konfiguration sendet der Code `geolocation=(),microphone=(),sync-xhr=(self),camera=(),usb=(),unload=self`. Eine konfigurierte Liste ersetzt die Vorgabe. |
| `pugfile` | Pfad zur Pug-Datei für die Startseite; Fallback: `src/tpl/pages/basic/index.pug`. |
| `maintenance` | Pug-Datei für den Wartungsmodus; Fallback: `src/tpl/pages/basic/maintance.pug`. |
| `shortcut_iconurl` | Pfad/URL des Favicons; Fallback für das normale Icon: `./bscimg/favicon-32x32.png`. Derselbe Konfigurationsschlüssel wird im Code auch für das 128er-Icon verwendet; dort ist der Fallback `./bscimg/favicon-128x128.png`. |
| `public_path` | Verzeichnis, aus dem die Route `/public/...` Dateien ausliefert. Ohne Wert ist die Route inaktiv. |

Für `csp` erwartet der Code einen Array-artigen Wert und verbindet dessen
Elemente mit `;`. In einer INI-Datei kann das als wiederholter Schlüssel
geschrieben werden:

```ini
[tualo-backend]
csp[]="default-src 'self'"
csp[]="img-src 'self' data:"
pmp[]="camera=()"
pmp[]="unload=(self)"
```

Auch `pmp` erwartet ein Array; dessen Einträge werden mit `,` verbunden.
Der Standardwert `unload=self` wird unverändert ausgegeben, entspricht aber
nicht der üblichen Allowlist-Syntax mit Klammern und kann vom Browser
ignoriert werden. Weitere Beispiele und die vollständige CSP-Vorgabe stehen
in der [README](README.md#http-sicherheitsheader-der-startseite).

### Client, Login und OAuth

| Abschnitt / Schlüssel | Verwendung und Fallback |
|---|---|
| flach `FORCE_CLIENT` | Überschreibt beim Login den Client/Mandanten. Hat Vorrang vor `[database] force_client`. |
| `[oauth] key` | Optionaler Pfad zu einem Schlüssel für die PGP-Verschlüsselung von OAuth-Token. Ohne Schlüssel wird nicht verschlüsselt; bei gesetztem Schlüssel wird das optionale Paket `TualoPGP` benötigt. |
| `[oauth] accessControlAllowOrigin` | `Access-Control-Allow-Origin`-Wert für die OAuth-Authentifizierung; Fallback: `*`. |
| `[options_request] accessControlAllowOrigin` | CORS-Origin-Header für `OPTIONS`-Anfragen und Login. Bei normalen Requests wird der Header nur gesetzt, wenn der Wert konfiguriert ist; Fallback dort: `false`. |
| `[cookie] cookie_post_field_name` | Name eines POST-Feldes, dessen nicht leeren Inhalt der Session-Initialisierung als Session-ID übergeben wird; Fallback: leerer String (deaktiviert). |
| `[cookie] backend_name`, `authorization_name`, `cms_name` | Session-Cookie-Namen des Server-Starters; Fallbacks: `tualo`, `tualoauth`, `tualocms`. |
| `[cookie] cms_samesite` | Wird vom Server für den OAuth-Pfad gelesen. Die aktuelle Zuweisung übergibt das Ergebnis eines Vergleichs statt des konfigurierten Strings; Verhalten vor Verwendung prüfen. |
| `[basic] forward_headers` | JSON-Array mit Server-Variablennamen für die Ermittlung der Client-IP; Fallback: `HTTP_X_DDOSPROXY`, `HTTP_X_FORWARDED_FOR`, `HTTP_CLIENT_IP`, `REMOTE_ADDR`. |
| flach `__CMS_ALLOWED_IP_FIELD__` | Name einer `$_SERVER`-Variablen, die die Client-IP-Middleware statt `REMOTE_ADDR` verwendet, sofern diese Variable vorhanden ist. |
| `[basic] log_scope_access` | Bei exakt dem String `1` wird `logScopes` in der Session aktiviert. |

`forward_headers` wird als JSON-Text dekodiert. Ein passender INI-Wert ist
beispielsweise:

```ini
[basic]
forward_headers=["HTTP_X_FORWARDED_FOR", "REMOTE_ADDR"]
```

### Zugriffsschutz-Helfer

`TualoApplication::needsActiveLogin($section = 'compiler')` liest Optionen aus
dem angegebenen Abschnitt. Sie sind besonders für Aufrufer außerhalb dieses
Pakets relevant:

| Schlüssel | Verwendung und Fallback |
|---|---|
| `[compiler] allowedExtern` | Bei einem bool-wahren Wert ist für den Helfer kein Login erforderlich. Standardmäßig ist der Wert `false`, Login ist also erforderlich. |
| `[compiler] allowed_clientip_headers` | JSON-Array mit Header-/Servervariablennamen für die IP-Prüfung; Fallback wie `[basic] forward_headers`. |
| `[compiler] allowed_cidrs` | Leerzeichengetrennte CIDR-Liste erlaubter IP-Netze; Fallback: `127.0.0.1`. Eine IP innerhalb der Liste benötigt laut Helfer keinen Login. |

Bei Aufruf mit einem anderen `$section` gelten dieselben drei Schlüsselnamen
in diesem Abschnitt. Der Helfer wird im BSC-Paket definiert, aber innerhalb
dieses Pakets nicht aufgerufen.

### Logging und Diagnose

| Abschnitt / Schlüssel | Verwendung und Fallback |
|---|---|
| `[logger-file] filename` | Logdatei für den Monolog-Stream-Handler. Der Handler wird nur verwendet, wenn Pfad und `level` gesetzt sind und die Datei beschreibbar ist. |
| `[logger-file] level` | Monolog-Level für den Datei-Handler, z. B. `DEBUG`, `INFO`, `NOTICE`, `WARNING`, `ERROR` oder `CRITICAL`. |
| `[logger-slack] token`, `channel` | Erforderlich, damit der Slack-Handler eingerichtet wird. |
| `[logger-slack] botname`, `useAttachment`, `iconEmoji`, `level` | Slack-Handler-Einstellungen; `useAttachment` wird boolesch interpretiert. `level` sollte explizit gesetzt werden, da der Code direkt darauf zugreift. |
| `[logger-slackwebhook] url`, `channel` | Erforderlich, damit der zusätzliche Handler eingerichtet wird. Der Code erstellt dafür einen `SlackHandler`, keinen `SlackWebhookHandler`. |
| `[logger-slackwebhook] botname`, `useAttachment`, `iconEmoji`, `level` | Weitere im Handler-Code berücksichtigte Einstellungen. Der Code greift für `botname`, `useAttachment` und `iconEmoji` allerdings auf `[logger-slack]` statt auf `[logger-slackwebhook]` zu; `level` sollte explizit gesetzt werden. |
| `[logger-options] ROUTERUN` | Bei exakt `1` aktiviert der Router zusätzliche Meldungen zum Session-Pfad. |
| `[logger-options] TualoApplicationTiming` | Im Timing-Code als Schalter für Timing-Logs vorgesehen. Der zugehörige Code ist derzeit auskommentiert; die Option bewirkt damit aktuell nichts. |

Die Logger werden pro Kanal zwischengespeichert. Änderungen an den
Loggereinstellungen greifen daher üblicherweise erst in einem neuen
Anwendungsprozess.

### Routing, Datenbank-Session und Ausführung

| Abschnitt / Schlüssel | Verwendung und Fallback |
|---|---|
| `[sanitizer] disabled` | Wenn bool-wahr, werden unerwartete Felder nicht als Fehler behandelt und für ungültige Eingaben wird kein HTTP-400-Status gesetzt. Die Prüfung läuft weiter und ungültige Eingaben können dennoch eine Fehlerantwort auslösen. |
| `[deferred] enabled` | Aktiviert das Ausführen aufgeschobener SQL-Aufgaben; Fallback: `false`. |
| `[deferred] use_by_user` | Bei exakt `1` wird `proc_deferred_sql_tasks_by_current_user()` aufgerufen, andernfalls `proc_deferred_sql_tasks()`. |
| flach `use_base_url` | Überschreibt die aus dem aktuellen HTTP-Request ermittelte Basis-URL für zeitversetzte/deferred Aufrufe. |
| `[php-settings] <PHP-INI-Direktive>` | Jede Direktive im Abschnitt wird zur Laufzeit über `ini_set()` gesetzt. |
| `[php-client] <PHP-INI-Direktive>` | Jede Direktive in diesem Abschnitt wird beim CLI-Start über `ini_set()` gesetzt. |
| `[php-server] <PHP-INI-Direktive>` | Jede Direktive in diesem Abschnitt wird beim Webstart über `tualo/server` gesetzt. Der aktuelle Loader verwirft den Abschnitt, wenn `[database]` fehlt. |
| flach `TIMEZONE` | Zeitzone für `date_default_timezone_set()`. Ohne Wert bleibt die PHP-Standardzeitzone aktiv. |

## INI-Beispiel

Das folgende Beispiel zeigt die Abschnittsstruktur. Werte wie Zugangsdaten,
Schlüsseldateipfade und erlaubte Origins müssen zur jeweiligen Installation
passen:

```ini
TIMEZONE=Europe/Berlin
client.mysql.connect_timeout=10

[database]
db_name=session
db_user=sessionuser
# db_pass z. B. über TUALO_DB_PASSWORD bereitstellen
db_host=127.0.0.1
db_port=3306
set_names="SET NAMES 'utf8mb4'"

[options_request]
accessControlAllowOrigin=https://example.invalid

[tualo-backend]
pugfile=/path/to/index.pug
public_path=/path/to/public
csp[]="default-src 'self'"
csp[]="img-src 'self' data:"
pmp[]="camera=()"
pmp[]="unload=(self)"

[deferred]
enabled=0
use_by_user=0

[php-settings]
display_errors=0
```

Das Beispiel ist eine Vorlage, keine vollständige oder sichere
Produktionskonfiguration. Insbesondere sollten Origins, CSP, Dateipfade und
Zugangsdaten passend zur Umgebung gewählt und Zugangsdaten nicht in
Versionskontrolle eingecheckt werden.

## Quellcode-Referenzen

- [`TualoApplication::configuration()`](src/TualoApplication.php) – generischer Zugriff sowie IP-, Login-, Logger- und Deferred-Optionen.
- [`Routes/Index`](src/Routes/Index.php) und [`Routes/PublicRoute`](src/Routes/PublicRoute.php) – Darstellung, CSP und öffentliche Dateien.
- [`Session`](src/Session.php) und [`MYSQL/Database_mysql`](src/MYSQL/Database_mysql.php) – Sitzungs- und Datenbankverbindungen.
- [`Route`](src/Route.php), [`Middleware/session/login`](src/Middleware/session/login.php) und [`Middleware/session/auth`](src/Middleware/session/auth.php) – Routing, CORS und Authentifizierung.
- [`Middleware/ClientIP`](src/Middleware/ClientIP.php), [`Middleware/Timezone`](src/Middleware/Timezone.php) und [`Middleware/PHPSettings`](src/Middleware/PHPSettings.php) – direkt gelesene flache Werte und INI-Einstellungen.
- [`commandline/Cli`](src/commandline/Cli.php) und [`SetConfigurationVariable`](src/SetConfigurationVariable.php) – Laden und Ändern der Konfigurationsdatei.
