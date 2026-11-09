# FinderExtras 0.1.0

Kleine native Swift/AppKit-App für macOS ab 12, Intel und Apple Silicon.
Lokale Testversion: Quellcode erstellt und statisch geprüft, noch nicht auf
macOS kompiliert oder im Finder ausgeführt. Kein fertiges signiertes Binary.

## Installation

1. ZIP entpacken.
2. `Installieren.command` doppelklicken. Alternativ im Terminal `bash ` eingeben,
   die Datei ins Terminal ziehen und Enter drücken.
3. Fehlen Apples Command Line Tools, `xcode-select --install` ausführen,
   Installation abschließen und Schritt 2 wiederholen. Vollständiges Xcode
   ist nicht nötig. Der Installer lädt keine fremden Abhängigkeiten herunter.
4. App wird lokal gebaut, ad-hoc signiert und nach `~/Applications` installiert.
   Ein bestehendes FinderExtras wird nicht überschrieben.
5. Unter Datenschutz & Sicherheit → Bedienungshilfen die installierte App
   hinzufügen und erlauben. Bei der ersten Aktion Automation für Finder und
   System Events erlauben. Kein Vollzugriff auf die Festplatte erforderlich.
6. Dienste bei Bedarf unter Tastatur → Tastaturkurzbefehle → Dienste aktivieren.
   Erscheinen sie noch nicht, einmal ab- und wieder anmelden.

Die lokal erstellte App ist nicht von Apple notarisiert. Gatekeeper und andere
macOS-Schutzfunktionen sollen nicht deaktiviert werden.

## Bedienung

Menüleistensymbol → Ausschneiden (vormerken), Zielordner im Finder öffnen,
Menüleistensymbol → Hierher verschieben. Die native Finder-Zwischenablage wird
verwendet. Ausschneiden löscht nichts: Es entspricht zunächst Kopieren.
Erst „Hierher verschieben“ ruft die native Bewegungsfunktion auf. Weitere
Kopieraktionen ersetzen die vorgemerkte Auswahl. Dateien werden nicht verblasst
angezeigt. „Einfügen (Kopie)“ kopiert stattdessen.

Im Kontextmenü ausgewählter Dateien unter **Dienste**:
- FinderExtras – Ausschneiden (vormerken)
- FinderExtras – In diesen Ordner verschieben (genau einen Zielordner auswählen)
- FinderExtras – Pfade kopieren

Dies ist eine native macOS-Diensteintegration, kein Finder-Sync-Plug-in.
Keine garantierten Einträge direkt auf oberster Kontextmenüebene und keine
Dienste beim Rechtsklick auf einen leeren Fensterbereich. Dafür dient das
Menüleistensymbol. Finder Sync ist laut Apple für Synchronisationsintegration
vorgesehen; diese App nutzt die allgemeine Services-Schnittstelle.

Weitere Menüleistenaktionen: versteckte Dateien, Pfadleiste und Vorschau
umschalten, Auswahl in neuen Ordner packen, Unterordner auf-/zuklappen in der
Listenansicht, Vorschau/Diashow, Pfade kopieren, Gehe zum Ordner, Server verbinden,
übergeordneten Ordner öffnen.

Aktionen beziehen sich auf das vorderste Finder-Fenster bzw. dessen Auswahl.
Während eines Befehls nicht zwischen Fenstern wechseln. Keine Texteingabe,
Umbenennung oder modalen Dialoge im Finder offen lassen. Normale Finder-
Kurzbefehle müssen unverändert sein. Die App sendet Kurzbefehle auf ausdrücklichen
Klick; sie liest keine globalen Tastatureingaben. Finder bearbeitet Dateiübertragung,
Fortschritt und Namenskonflikte. Die App stellt keine eigene Transferwarteschlange
bereit und behauptet nicht, dass ein gesendeter Kurzbefehl bereits erfolgreich
abgeschlossen ist. Keine manuelle Quelllöschung oder automatische Ersetzung.

Für Drag-and-drop-Varianten gibt es keine gleichwertige Menüaktion ohne Zielwahl;
gezieltes Verschieben/Kopieren erfolgt hier über die Zwischenablage.

## Prüfung auf dem Mac (zuerst mit Testdateien)

- Installer muss ohne Compilerfehler enden; Symbol erscheint oben rechts.
- Erlaubnis verweigern: verständliche Meldung; danach erlauben und erneut testen.
- Zwei Testdateien vormerken, in zweiten Ordner bewegen: nur dort vorhanden.
- Dasselbe mit „Einfügen (Kopie)“: Quellen bleiben vorhanden.
- Namenskonflikt erzeugen: Finder-Dialog prüfen, abbrechen, Quellen kontrollieren.
- Externe SSD / NAS: erst kleine Testdateien, dann größere Datei testen.
- Kontextdienste mit Leerzeichen, Umlauten und Anführungszeichen im Namen testen.
- Leere Auswahl / Text-Zwischenablage / mehrere Zielordner: Fehlermeldung prüfen.
- Alle Ansichtsaktionen im normalen Finder-Fenster testen.

## Entwicklung und Grenzen

`Sources/main.swift`: App, Services-Provider und AppleScript-Brücke.
`Info.plist`: Services-Deklarationen und Automation-Begründung.
`Installieren.command`: reproduzierbarer Build für die Architektur des Macs.

Kein Hintergrundscan, kein Netzwerkzugriff durch die App, kein Autostart ohne
Benutzereinrichtung. AppleScript und AppKit sind hier nicht verfügbar; deshalb
noch keine Aussage zu erfolgreichem macOS-Build oder getesteter Laufzeit.
Bei Problemen bitte Compiler-Ausgabe bzw. genaue Aktion und macOS-Version teilen.

Deinstallation: App beenden und `~/Applications/FinderExtras.app` löschen;
optional aus Anmeldeobjekten entfernen. Dienste werden nach Ab-/Anmelden entfernt.

Quellen:
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html
- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html
- https://support.apple.com/de-ch/102650
