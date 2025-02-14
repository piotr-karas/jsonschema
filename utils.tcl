# Copyright (c) 2025 ANT Solutions https://antsolutions.eu/

# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

proc ::jsonschema::_throwError {message {type "ErrValidation"} {additionalArgs {}}} {
    upvar validationGlobalInfo validationGlobalInfo
    upvar validationLocalInfo validationLocalInfo

    if {[dict exists $additionalArgs instancePath]} {
        dict set additionalArgs instancePath [list {*}[dict get $validationLocalInfo instancePath] {*}[dict get $additionalArgs instancePath]]
    }
    if {[dict exists $additionalArgs schemaPath]} {
        dict set additionalArgs schemaPath [list {*}[dict get $validationLocalInfo schemaPath] {*}[dict get $additionalArgs schemaPath]]
    }
    set localInfo [dict merge $validationLocalInfo $additionalArgs]

    if {[dict exists $localInfo throwError]} {
        # internal use - no need to return all information
        return -code error $message
    }
    
    set errorObject [dict create \
        message $message \
        instancePath [dict get $localInfo instancePath] \
    ]

    if {[dict exists $localInfo instanceValue]} {
        dict set errorObject instanceValue [dict get $localInfo instanceValue]
    }

    dict set errorObject schemaPath [dict get $localInfo schemaPath]

    if {[dict exists $localInfo schemaValue]} {
        dict set errorObject schemaValue [dict get $localInfo schemaValue]
    }
    
    if {[dict exists $localInfo found]} {
        dict set errorObject found [dict get $localInfo found]
    }

    if {[dict get $validationGlobalInfo throwFirst]} {
        throw [list JSONSCHEMA $type] $errorObject
    }

    dict set errorObject type $type
    dict lappend validationGlobalInfo errors $errorObject
}

proc ::jsonschema::_appendPaths {validationLocalInfo instanceItem {schemaItem ""}} {
    if {$instanceItem ne ""} {
        dict set validationLocalInfo instancePath [list {*}[dict get $validationLocalInfo instancePath] {*}$instanceItem]
    }
    if {$schemaItem ne ""} {
        dict set validationLocalInfo schemaPath [list {*}[dict get $validationLocalInfo schemaPath] {*}$schemaItem]
    }
    return $validationLocalInfo
}

# yaml2huddle and json2huddle returns different type names for the same data type - unify them
proc ::jsonschema::_getTypeFromHuddle {huddle} {
    set huddleType [lindex $huddle 0]
    switch $huddleType {
        "!!str" -
        "s" {
            return "string"
        }
        "!!int" -
        "!!float" -
        "num" {
            return "number"
        }
        "!!true" -
        "!!false" -
        "b" {
            return "boolean"
        }
        "!!null" -
        "null" {
            return "null"
        }
        "!!map" -
        "D" {
            return "object"
        }
        "!!seq" -
        "L" {
            return "array"
        }
        default {
            throw {JSONSCHEMA ErrInvalidDataType} "Unknown data type in huddle: $huddleType"
        }
    }
}

proc ::jsonschema::_getValueFromHuddle {huddle} {
    return [lindex $huddle 1]
}

proc ::jsonschema::_getValueFromHuddleRecursive {huddle} {
    set huddleType [_getTypeFromHuddle $huddle]
    set huddleValue [_getValueFromHuddle $huddle]

    switch $huddleType {
        "object" {
            return [dict map {key value} $huddleValue {$key [_getValueFromHuddleRecursive $value]}]
        }
        "array" {
            return [lmap item $huddleValue {_getValueFromHuddleRecursive $item}]
        }
        default {
            return $huddleValue
        }
    }
}