# Copyright (c) 2025 ANT Solutions https://antsolutions.eu/

# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

proc ::jsonschema::_validateAllOf {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set schemas [_getValueFromHuddle [dict get $schema "allOf"]]

    for {set index 0} {$index < [llength $schemas]} {incr index} {
        set schemaToValidate [lindex $schemas $index]
        _validateRecursive $instance $schemaToValidate [_appendPaths $validationLocalInfo [list] [list "allOf" $index]]
    }
}

proc ::jsonschema::_validateAnyOf {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set schemas [_getValueFromHuddle [dict get $schema "anyOf"]]

    foreach schemaToValidate $schemas {
        if {[catch {
            _validateRecursive $instance $schemaToValidate [dict merge $validationLocalInfo [dict create throwError true]]
        } err]} {
            #ignore
        } else {
            return
        }
    }

    set errorInfo [dict create schemaPath "anyOf"]
    _throwError "Instance dose not match any of provided schemas" ErrAnyOf $errorInfo
}


proc ::jsonschema::_validateOneOf {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set schemas [_getValueFromHuddle [dict get $schema "oneOf"]]

    set matchingSchemas [list]
    for {set index 0} {$index < [llength $schemas]} {incr index} {
        set schemaToValidate [lindex $schemas $index]
        if {[catch {
            _validateRecursive $instance $schemaToValidate [dict merge $validationLocalInfo [dict create throwError true]]
        } err]} {
            #ignore
        } else {
            lappend matchingSchemas $index
        }
    }

    if {[llength $matchingSchemas] != 1} {
        set errorInfo [dict create schemaPath "oneOf" found $matchingSchemas]
        _throwError "Instance dose not match exactly one of provided schemas" ErrOneOf $errorInfo
    }
}

proc ::jsonschema::_validateNot {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set schemaToValidate [dict get $schema "not"]

    if {[catch {
        _validateRecursive $instance $schemaToValidate [dict merge $validationLocalInfo [dict create throwError true]]
    } err]} {
        #ignore
    } else {
        set errorInfo [dict create schemaPath "not"]
        _throwError "Instance is matching schema, while it should not" ErrNot $errorInfo
    }
}