# remove-appledouble.ps1 — run from the repo root.
# Deletes the committed macOS AppleDouble junk (._*) from index AND disk.
# These are metadata droppings from copying files on a Mac; Godot tries to
# parse the ._* .tres ones as resources, which is the parse-error spam at load.
$junk = git ls-files | Where-Object { $_ -match '(^|/)\._' }
Write-Host "$($junk.Count) AppleDouble files found"
$junk | ForEach-Object { git rm -q "$_" }
Write-Host "Removed. Commit with: git commit -m ""Remove macOS AppleDouble junk"""
