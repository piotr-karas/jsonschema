# Copyright (c) 2025 ANT Solutions https://antsolutions.eu/

# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

proc ::jsonschema::_validateString {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set instanceType [_getTypeFromHuddle $instance]
    set instanceValue [lindex $instance 1]

    dict for {schemaKey schemaValue} $schema {
        set schemaValue [_getValueFromHuddle $schemaValue]
        set errorInfo [dict create instanceValue $instanceValue schemaPath $schemaKey schemaValue $schemaValue]

        switch -- $schemaKey {
            "type" {
                if {$instanceType ne "string"} {
                    _throwError "Invalid data type" ErrInvalidDataType [dict merge $errorInfo [dict create found $instanceType]]
                    return
                }
            }
            "minLength" {
                if {[string length $instanceValue] < $schemaValue} {
                    _throwError "String length is less than required" "ErrMinLength" [dict merge $errorInfo [dict create found [string length $instanceValue]]]
                }
            }
            "maxLength" {
                if {[string length $instanceValue] > $schemaValue} {
                    _throwError "String length is greater than required" "ErrMaxLength" [dict merge $errorInfo [dict create found [string length $instanceValue]]]
                }
            }
            "pattern" {
                if {![regexp $schemaValue $instanceValue]} {
                    _throwError "String does not match pattern" "ErrPattern" $errorInfo
                }
            }
            default {
                _throwError "Unknown schema key" "ErrInvalidSchema" $errorInfo
            }
        }
    }
}

proc ::jsonschema::_validateNumber {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set instanceType [_getTypeFromHuddle $instance]
    set instanceValue [_getValueFromHuddle $instance]

    dict for {schemaKey schemaValue} $schema {
        set schemaValue [_getValueFromHuddle $schemaValue]
        set errorInfo [dict create instanceValue $instanceValue schemaPath $schemaKey schemaValue $schemaValue]

        switch -- $schemaKey {
            "type" {
                if {$schemaValue eq "integer"} {
                    if {$instanceType ne "number"} {
                        _throwError "Invalid data type" ErrInvalidDataType [dict merge $errorInfo [dict create found $instanceType]]
                        return
                    } elseif {[string is integer -strict $instanceValue] == 0} {
                        _throwError "Number is not an integer" ErrInvalidDataType $errorInfo
                        return
                    }
                }
                if {$schemaValue eq "number" && $instanceType ne "number"} {
                    _throwError "Invalid data type" ErrInvalidDataType [dict merge $errorInfo [dict create found $instanceType]]
                    return
                }
            }
            "multipleOf" {
                if {$instanceValue % $schemaValue != 0} {
                    _throwError "Number is not multiple" "ErrMultipleOf" $errorInfo
                }
            }
            "minimum" {
                if {$instanceValue < $schemaValue} {
                    _throwError "Number is less than required" "ErrMinimum" $errorInfo
                }
            }
            "exclusiveMinimum" {
                if {$instanceValue <= $schemaValue} {
                    _throwError "Number is less or equal than required" "ErrExclusiveMinimum" $errorInfo
                }
            }
            "maximum" {
                if {$instanceValue > $schemaValue} {
                    _throwError "Number is greater than required" "ErrMaximum" $errorInfo
                }
            }
            "exclusiveMaximum" {
                if {$instanceValue >= $schemaValue} {
                    _throwError "Number is greater or equal than required" "ErrExclusiveMaximum" $errorInfo
                }
            }
            default {
                _throwError "Unknown schema key" "ErrInvalidSchema" $errorInfo
            }
        }
    }
}

proc ::jsonschema::_validateBoolean {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set instanceType [_getTypeFromHuddle $instance]
    set instanceValue [_getValueFromHuddle $instance]
    set schemaValue [_getValueFromHuddle [dict get $schema type]]

    if {$instanceType ne "boolean"} {
        set errorInfo [dict create instanceValue $instanceValue schemaPath "type" schemaValue $schemaValue found $instanceType]
        _throwError "Invalid data type" ErrInvalidDataType $errorInfo
    }
    return;
}

proc ::jsonschema::_validateNull {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set instanceType [_getTypeFromHuddle $instance]
    set instanceValue [_getValueFromHuddle $instance]
    set schemaValue [_getValueFromHuddle [dict get $schema type]]

    if {$instanceType ne "null"} {
        set errorInfo [dict create instanceValue $instanceValue schemaPath "type" schemaValue $schemaValue found $instanceType]
        _throwError "Invalid data type" ErrInvalidDataType $errorInfo
    }
    return;
}

proc ::jsonschema::_validateEnum {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set instanceType [_getTypeFromHuddle $instance]
    set instanceValue [_getValueFromHuddle $instance]

    set enumValues [_getValueFromHuddle [dict get $schema enum]]

    foreach enumValue $enumValues {
        set enumType [_getTypeFromHuddle $enumValue]
        set enumValue [_getValueFromHuddle $enumValue]

        if {$instanceType eq $enumType && $instanceValue eq $enumValue} {
            return
        }
    }

    set errorInfo [dict create instanceValue $instanceValue schemaPath "enum" schemaValue [_getValueFromHuddleRecursive [dict get $schema enum]]]
    _throwError "Value not in enum" ErrEnum $errorInfo
}

proc ::jsonschema::_validateConst {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set instanceType [_getTypeFromHuddle $instance]
    set instanceValue [_getValueFromHuddle $instance]

    set constType [_getTypeFromHuddle [dict get $schema const]]
    set constValue [_getValueFromHuddle [dict get $schema const]]

    if {$instanceType eq $constType && $instanceValue eq $constValue} {
        return
    }

    set errorInfo [dict create instanceValue $instanceValue schemaPath "const" schemaValue $constValue]
    _throwError "Item not equal to const" ErrConst $errorInfo
}