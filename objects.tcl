# Copyright (c) 2025 ANT Solutions https://antsolutions.eu/

# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

proc ::jsonschema::_validateObject {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set instanceType [_getTypeFromHuddle $instance]
    set instanceValue [_getValueFromHuddle $instance]

    dict for {schemaKey schemaValueRaw} $schema {
        set schemaValue [_getValueFromHuddle $schemaValueRaw]

        switch -- $schemaKey {
            "type" {
                if {$instanceType ne "object"} {
                    set errorInfo [dict create schemaPath "type" schemaValue "object" found $instanceType]
                    _throwError "Invalid data type" ErrInvalidDataType $errorInfo
                    return
                }
            }
            "properties" {
                dict for {propKey propSchema} $schemaValue {
                    if {[dict exists $instanceValue $propKey]} {
                        set value [dict get $instanceValue $propKey]
                        _validateRecursive $value $propSchema [_appendPaths $validationLocalInfo $propKey [list properties $propKey]]
                    }
                }
            }
            "patternProperties" {
                dict for {pattern propSchema} $schemaValue {
                    dict for {propKey propValue} $instanceValue {
                        if {[regexp $pattern $propKey]} {
                            _validateRecursive $propValue $propSchema [_appendPaths $validationLocalInfo $propKey [list patternProperties $pattern]]
                        }
                    }
                }
            }
            "propertyNames" {
                set pattern [_getValueFromHuddle [dict get $schemaValue pattern]]
                dict for {propKey propValue} $instanceValue {
                    if {![regexp $pattern $propKey]} {
                        set errorInfo [dict create instancePath $propKey schemaPath [list "propertyNames" "pattern"] schemaValue $pattern]
                        _throwError "Property name does not match pattern" "ErrPattern" $errorInfo
                    }
                }
            }
            "unevaluatedProperties" {
                throw {JSONSCHEMA ErrNotImplemented} "unevaluatedProperties not implemented"
            }
            "required" {
                for {set index 0} {$index < [llength $schemaValue]} {incr index} {
                    set propKey [_getValueFromHuddle [lindex $schemaValue $index]]
                    if {![dict exists $instanceValue $propKey]} {
                        set errorInfo [dict create schemaPath [list "required" $index] schemaValue $propKey]
                        _throwError "Missing required property" ErrMissingProperty $errorInfo
                    }
                }
            }
            "additionalProperties" {
                dict for {propKey propValue} $instanceValue {
                    if {[dict exists $schema properties] && ![dict exists [_getValueFromHuddle [dict get $schema properties]] $propKey]} {
                        _validateRecursive $propValue $schemaValueRaw [_appendPaths $validationLocalInfo $propKey additionalProperties]
                    }
                }
            }
            "minProperties" {
                if {[dict size $instanceValue] < $schemaValue} {
                    set errorInfo [dict create schemaPath minProperties schemaValue $schemaValue]
                    _throwError "Object contains too little properties" "ErrMinProperties" $errorInfo
                }
            }
            "maxProperties" {
                if {[dict size $instanceValue] > $schemaValue} {
                    set errorInfo [dict create schemaPath maxProperties schemaValue $schemaValue]
                    _throwError "Object contains too many properties" "ErrMaxProperties" $errorInfo
                }
            }
            default {
                set errorInfo [dict create schemaPath $schemaKey]
                _throwError "Unknown schema key" "ErrInvalidSchema" $errorInfo
            }
        }
    }
}

proc ::jsonschema::_validateArray {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set instanceType [_getTypeFromHuddle $instance]
    set instanceValue [_getValueFromHuddle $instance]

    dict for {schemaKey schemaValueRaw} $schema {
        set schemaValue [_getValueFromHuddle $schemaValueRaw]

        switch -- $schemaKey {
            "type" {
                if {$instanceType ne "array"} {
                    set errorInfo [dict create schemaPath "type" schemaValue "array" found $instanceType]
                    _throwError "Invalid data type" ErrInvalidDataType $errorInfo
                    return
                }
            }
            "items" {
                # without 'prefixItems' defined index = 0
                set index 0
                if {[dict exists $schema prefixItems]} {
                    # if 'prefixItems' is defined, 'items' defines whether additional items are allowed and if so - their schema
                    set index [llength [_getValueFromHuddle [dict get $schema prefixItems]]]
                }

                for {} {$index < [llength $instanceValue]} {incr index} {
                    set item [lindex $instanceValue $index]
                    _validateRecursive $item $schemaValueRaw [_appendPaths $validationLocalInfo $index "items"]
                }
            }
            "prefixItems" {
                for {set index 0} {$index < [llength $schemaValue]} {incr index} {
                    # instanceValue is not required to have the same length as schemaValue, check only provided items
                    if {[llength $instanceValue] <= $index} {
                        break
                    }
                    set schemaItem [lindex $schemaValue $index]
                    set huddleItem [lindex $instanceValue $index]
                    _validateRecursive $huddleItem $schemaItem [_appendPaths $validationLocalInfo $index [list "prefixItems" $index]]
                }
            }
            "contains" {
                set minContains 1
                set maxContains ""
                if {[dict exists $schema minContains]} {
                    set minContains [_getValueFromHuddle [dict get $schema minContains]]
                }
                if {[dict exists $schema maxContains]} {
                    set maxContains [_getValueFromHuddle [dict get $schema maxContains]]
                }

                set containsCount 0
                for {set index 0} {$index < [llength $instanceValue]} {incr index} {
                    set item [lindex $instanceValue $index]
                    if {[catch {
                        _validateRecursive $item $schemaValueRaw [dict merge $validationLocalInfo [dict create throwError true]]
                    } err]} {
                        # ignore errors
                    } else {
                        incr containsCount
                    }
                }

                if {$maxContains ne "" && $maxContains < $containsCount} {
                    set errorInfo [dict create schemaPath maxContains schemaValue $maxContains]
                    _throwError "Array contains more than allowed matching items" "ErrMaxContains" $errorInfo
                }
                if {$minContains ne "" && $containsCount < $minContains} {
                    set errorInfo [dict create schemaPath minContains schemaValue $minContains]
                    _throwError "Array contains less than allowed matching items" "ErrMinContains" $errorInfo
                }
            }
            "uniqueItems" {
                if {$schemaValue ne "true"} {
                    continue
                }
                for {set xIndex 0} {$xIndex < [llength $instanceValue]} {incr xIndex} {
                    for {set yIndex [expr $xIndex + 1]} {$yIndex < [llength $instanceValue]} {incr yIndex} {
                        if {[lindex $instanceValue $xIndex] == [lindex $instanceValue $yIndex]} {
                            set errorInfo [dict create instanceValue [_getValueFromHuddleRecursive [lindex $instanceValue $xIndex]] instancePath $xIndex schemaPath "uniqueItems" schemaValue true found $yIndex]
                            _throwError "Array contains duplicate items" "ErrUniqueItems" $errorInfo
                        }
                    }
                }
            }
            "minItems" {
                if {[llength $instanceValue] < $schemaValue} {
                    set errorInfo [dict create schemaPath minItems schemaValue $schemaValue found [llength $instanceValue]]
                    _throwError "Array length is less than allowed" "ErrMinItems" $errorInfo
                }
            }
            "maxItems" {
                if {[llength $instanceValue] > $schemaValue} {
                    set errorInfo [dict create schemaPath maxItems schemaValue $schemaValue found [llength $instanceValue]]
                    _throwError "Array length is greater than allowed" "ErrMaxItems" $errorInfo
                }
            }
            "minContains" -
            "maxContains" {
                # ignore, handled in 'contains' validation
            }
            "unevaluatedItems" {
                throw {JSONSCHEMA ErrNotImplemented} "array property unevaluatedItems not implemented"
            }
            default {
                set errorInfo [dict create schemaPath $schemaKey]
                _throwError "Unknown schema key" "ErrInvalidSchema" $errorInfo
            }
        }
    }
}
