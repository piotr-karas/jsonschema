# Tcl package index file, version 1.0

package ifneeded jsonschema 1.0.0 [list apply {{dir} {
    source -encoding "utf-8" [file join $dir jsonschema.tcl]
    source -encoding "utf-8" [file join $dir utils.tcl]
    source -encoding "utf-8" [file join $dir primitives.tcl]
    source -encoding "utf-8" [file join $dir formats.tcl]
    source -encoding "utf-8" [file join $dir objects.tcl]
    source -encoding "utf-8" [file join $dir schema_composition.tcl]
    package provide jsonschema 1.0.0
}} $dir]