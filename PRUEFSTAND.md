# FinderExtras 0.2.0 – Prüfstand

Geprüfter Quellcode: 723a7303e30df4310fa54ab63aa39881367c4ca8.
macOS 15 auf Apple Silicon; GitHub Actions erfolgreich:
https://github.com/boogietown1981/macOS-Finder-Kontext-/actions/runs/42720587814

Bestanden:
- Native App und Finder-Sync-Erweiterung kompiliert.
- Lokale Codesign-Prüfung von App und Erweiterung.
- App gestartet und laufender Prozess bestätigt (Starttest, keine vollständige UI-Prüfung).
- Verschieben und Kopieren auf demselben Volume.
- Verschieben von Datei und verschachteltem Ordner auf separates Disk-Image:
  Quelle entfernt, Zielinhalt stimmt überein.
- Konflikte, verschachtelte Auswahl, symbolischer Link und nachträglich
  belegter Zielname geprüft; kein Überschreiben.

Noch manuell zu prüfen:
- Finder-Kontextmenü nach Aktivierung der Erweiterung.
- Interaktive Berechtigungsdialoge und Darstellung des Einrichtungsfensters.
- Konkrete NAS-Freigaben, Cloud-Ordner, macOS 12–14 und Intel-Macs.

Das ZIP enthält Quellcode und lokalen Build-Installer. Der Installer erzeugt
auf deinem Mac die passende Architektur. Keine Apple-Notarisierung.
