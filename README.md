# FinderExtras 0.2.0

Native macOS-App für Intel und Apple Silicon, ab macOS 12. Menüleiste,
Finder-Kontextmenü und geführte Einrichtung. Quellcode und lokale Installation
sind unabhängig von kostenpflichtigen Abhängigkeiten.

## Neu in 0.2.0

- Ausschneiden erhält einen eigenen Zwischenablage-Status. **Einfügen** verschiebt
  danach; nach **Kopieren** kopiert es. **Als Kopie einfügen** behält die Quellen.
- Dateibewegungen verwenden FileManager.moveItem, auch über Volume-Grenzen.
  Nach Erfolg prüft die App Zielvorhandensein und Quellabwesenheit. Es gibt keine
  zusätzliche manuelle Quelllöschung und keine Erfolgsmeldung bei verbleibender Quelle.
- Finder-Sync-Erweiterung mit Einträgen ohne „Dienste“-Untermenü. Apple bestimmt
  Position und Sichtbarkeit. In Cloud-/File-Provider-Bereichen können Einträge
  fehlen; Dienste und Menüleiste bleiben als Alternative.
- Dezentes blau-graues Ordner-Icon mit zwei Pfeilen, monochromes Menüleistensymbol.
- Einrichtungsfenster mit Status und Freigabe-Schaltflächen für Finder-Erweiterung,
  Automation und Bedienungshilfen. Automatisches Öffnen beim ersten 0.2-Start.

## Installation / Update

1. ZIP entpacken; laufendes FinderExtras über sein Menü beenden.
2. `Installieren.command` starten (alternativ `bash ` im Terminal eingeben und
   die Datei hineinziehen). Falls nötig zuerst `xcode-select --install` ausführen.
3. Der Installer baut App, Icon und Erweiterung, signiert lokal und installiert
   nach `~/Applications/FinderExtras.app`. Vorhandene eigene Versionen werden als
   ZIP in `~/Library/Application Support/FinderExtras/Backups` gesichert.
4. Im automatisch geöffneten Einrichtungsfenster **Finder-Erweiterung aktivieren**
   wählen und FinderExtras in macOS einschalten. Je nach macOS-Version liegt
   dies bei Erweiterungen oder Allgemein → Anmeldeobjekte & Erweiterungen → Finder.
5. Automation für Finder/System Events und Bedienungshilfen nach Bedarf erlauben.
   Die App stellt die Anfragen und zeigt den Status; macOS verlangt deine Bestätigung.

Die direkte Kontext-Dateiauswahl kommt aus der Erweiterung und benötigt keine
Bedienungshilfen. Menüleisten-Dateiauswahl benötigt Finder-Automation.
Ansichts-Kurzbefehle benötigen zusätzlich System Events und Bedienungshilfen.
Geschützte Ordner können separate macOS-Dateizugriffsfragen auslösen. Kein pauschaler
Festplattenvollzugriff wird angefordert. Ein NAS muss verbunden sein und Schreib-
sowie Löschrechte erlauben.

Lokale Ad-hoc-Signierung ist kein Developer-ID-Zertifikat und keine Notarisierung.
Nach Neubauten können Rechte erneut nötig sein. Ein vorhandenes eigenes Zertifikat
kann über `FINDEREXTRAS_SIGNING_IDENTITY` beim Build gewählt werden. SIP/Gatekeeper
und die Berechtigungsdatenbank werden nicht verändert. Bereits erteilte Rechte
werden nicht automatisch zurückgesetzt.

## Bedienung

Dateien markieren → **Ausschneiden** → Zielordner → **Hier einfügen · FinderExtras**.
Vor der Ausführung zeigt ein Dialog explizit „Verschieben“ und den Zielpfad.
Im Menüleistensymbol heißt der entsprechende Eintrag **Einfügen**.
**Hierher verschieben** erzwingt Verschieben; **Als Kopie einfügen** erzwingt Kopieren.
Die normalen Apple-Finder-Einträge sind davon unabhängig: Apples normales „Einsetzen“
kennt unseren Ausschneiden-Status nicht. Verwende den FinderExtras-Eintrag.
Das Kopieren anderer Inhalte ersetzt die vorgemerkten Dateien.

Vorhandene Ziele, doppelte Namen und eine Auswahl von Elternordner plus Kind werden
vorab abgelehnt. Keine Zusammenführung oder Überschreibung. Der Zielpfad wird vor
jeder Übertragung bestätigt, auch zum Schutz des App-URL-Einstiegspunkts.
Bei Fehlern kann eine Teilübertragung stattgefunden haben; Details und Zahl der
abgeschlossenen Objekte werden angezeigt. Quelle/Ziel prüfen, verbleibende Quellen
neu auswählen. Keine automatische Wiederholung. Nach Move wird die unveränderte
Zwischenablage geleert. Übertragung im Hintergrund, Fortschritt pro Objekt;
kein bytegenauer Fortschritt, kein Abbrechen mitten in einer Datei, kein Undo.

Die Erweiterung registriert den Dateibaum für Kontextmenüs; sie scannt keine
Dateien und setzt keine Badges. Sie übergibt Auswahl und Ziel an die Haupt-App.
Die Haupt-App erledigt die Dateioperationen. Dienste bleiben registriert.

## Build und Tests

```bash
bash Build.command
TEST_CROSS_VOLUME=1 bash Tests/run.sh
```

GitHub Actions baut auf einem macOS-Runner App und Finder-Erweiterung und testet
Moves auf demselben Volume und auf einem temporären Disk-Image, Copy, Konflikte,
verschachtelte Auswahl, symbolische Links und eine nachträglich belegte Zieldatei.
Das Workflow-Artefakt enthält eine lokal signierte App für die Runner-Architektur.
Ein grüner Build ersetzt keinen interaktiven Test der Finder-Erweiterung, der
Berechtigungsdialoge oder deiner konkreten NAS-Freigabe.

Manueller Test: kleine Testdateien zunächst lokal, danach NAS/externe SSD verschieben;
Quelle muss verschwunden, Zielinhalt korrekt sein. Danach Kopieren prüfen (Quelle
bleibt). Erweiterung aktivieren und Kontextmenü auf Datei, Ordner und freier Fläche
prüfen. Setup bei abgelehnten und erteilten Rechten testen.

Deinstallation: App beenden, Finder-Erweiterung deaktivieren, App löschen.
Sicherungen im oben genannten Verzeichnis können separat entfernt werden.

## Quellen

- https://developer.apple.com/documentation/foundation/filemanager/moveitem(at:to:)
- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html
