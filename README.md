## QuickerFort
[QuickFort](http://www.joelpt.net/quickfort/)-compatible (ish) fortress
blueprint placer.

### Installation
Requires [dfhack](https://dfhack.readthedocs.io/en/stable/). Place this script
under `<DF_ROOT>/hack/scripts`, and place blueprint CSV files under
`<DF_ROOT>/blueprints`.

### Usage
Run the dfhack command `quickerfort` (either from the dfhack console window, or
by pressing <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> to bring up the
in-game console), which will show an in-game UI for choosing and placing your
blueprints. Currently quickerfort can only handle `d`esignations, not
`b`uildings or `q`ueries (so it isn't useful for placing furniture or
stockpiles yet).

Example blueprint to build four bedrooms stacked on top of each other:
```csv
d,d,d,d,i,d,d,d,d
d,d,d,`,`,`,d,d,d
#>
d,d,d,d,i,d,d,d,d
d,d,d,`,`,`,d,d,d
```

While placing the blueprint, <kbd>h</kbd> will flip the blueprint horizontally,
<kbd>v</kbd> will flip it vertically, and <kbd>r</kbd> will rotate it by 90°.
If the blueprint extends over multiple Z-levels or is larger than the screen,
you can pres <kbd>l</kbd> to lock the blueprint in place and then move around
with the normal movement keys to see the full blueprint. <kbd>Enter</kbd> will
stamp out one copy of the blueprint and stay in placement mode, so you can
easily place multiple copies of a blueprint.
