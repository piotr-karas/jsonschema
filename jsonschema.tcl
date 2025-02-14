# Copyright (c) 2025 ANT Solutions https://antsolutions.eu/

# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

package provide jsonschema 1.0.0

package require json
package require yaml
package require huddle
package require huddle::json
package require fileutil
package require uri

namespace eval ::jsonschema {}

proc ::jsonschema::validate {args} {
    if {[llength $args] < 2} {
        throw {JSONSCHEMA ErrInvalidArg} "Missing arguments. Usage: ::jsonschema::validate ?options? instance schema"
    }

    set instance [lindex $args end-1]
    set schema [lindex $args end]
    set args [lrange $args 0 end-2]

    if {[llength $args] % 2} {
        throw {JSONSCHEMA ErrInvalidArg} "Missing value for option [lindex $args end]"
    }

    # defaults
    set instanceFormat "json"
    set schemaFormat "json"
    set throwAll false
    set throwFirst false
    set includedSchemas [dict create]

    foreach key [dict keys $args] {
        switch $key {
            -instanceFormat {
                if {[dict get $args $key] ni [list "yaml" "yamlFile" "json" "jsonFile" "huddle"]} {
                    throw {JSONSCHEMA ErrInvalidArg} "Invalid value for option -instanceFormat. Available are: yaml, yamlFile, json, jsonFile, huddle"
                }
                set instanceFormat [dict get $args $key]
            }
            -schemaFormat {
                if {[dict get $args $key] ni [list "json" "jsonFile" "huddle"]} {
                    throw {JSONSCHEMA ErrInvalidArg} "Invalid value for option -schemaFormat. Available are: json, jsonFile, huddle"
                }
                set schemaFormat [dict get $args $key]
            }
            -throwAll {
                if {[dict get $args $key] ni [list "true" "false" "0" "1"]} {
                    throw {JSONSCHEMA ErrInvalidArg} "Invalid value for option -throwAll. Available are: true, false, 0 ,1"
                }
                set throwAll [dict get $args $key]
            }
            -throwFirst {
                if {[dict get $args $key] ni [list "true" "false" "0" "1"]} {
                    throw {JSONSCHEMA ErrInvalidArg} "Invalid value for option -throwFirst. Available are: true, false, 0 ,1"
                }
                set throwFirst [dict get $args $key]
            }
            -includeSchemas {
                # list containing schemas in form of dict containing optional id and either schema or file

                for {set index 0} {$index < [llength [dict get $args $key]]} {incr index} {
                    set includedSchema [lindex [dict get $args $key] $index]
                    if {[dict exists $includedSchema jsonFile] && [dict exists $includedSchema json]} {
                        throw {JSONSCHEMA ErrInvalidArg} "Schema can be defined either as jsonFile or as json, not both. Index: $index"
                    }
                    if {![dict exists $includedSchema jsonFile] && ![dict exists $includedSchema json]} {
                        throw {JSONSCHEMA ErrInvalidArg} "Schema must be defined either as jsonFile or as json. Index: $index"
                    }

                    if {[dict exists $includedSchema jsonFile]} {
                        if {[catch {
                            set schemaDef [::fileutil::cat [dict get $includedSchema jsonFile]]
                        } err]} {
                            throw {JSONSCHEMA ErrInvalidArg} "Error reading additional schema file '[dict get $includedSchema jsonFile]': $err"
                        }
                    }

                    if {[dict exists $includedSchema json]} {
                        set schemaDef [dict get $includedSchema json]
                    }

                    if {[catch {
                        set schemaDef [huddle::json2huddle $schemaDef]
                        set schemaDef [dict get $schemaDef HUDDLE]
                    } err]} {
                        throw {JSONSCHEMA ErrInvalidArg} "Error parsing additional schema (index: $index): $err"
                    }

                    # get id from schema
                    if {![dict exists [_getValueFromHuddle $schemaDef] \$id] && ![dict exists $includedSchema id]} {
                        throw {JSONSCHEMA ErrInvalidArg} "Included schema must contain \$id in its definition or id as argument (index: $index)."
                    }
                    if {[dict exists [_getValueFromHuddle $schemaDef] \$id]} {
                        set id [_getValueFromHuddle [dict get [_getValueFromHuddle $schemaDef] \$id]]
                    }
                    if {[dict exists $includedSchema id]} {
                        set id [dict get $includedSchema id]
                    }

                    if {[dict exists $includedSchemas $id]} {
                        throw {JSONSCHEMA ErrInvalidArg} "Included schema with id '$id' already exists."
                    }
                    dict set includedSchemas $id $schemaDef
                }
            }
            default {
                throw {JSONSCHEMA ErrInvalidArg} "Unknown option $key. Available are: -instanceFormat, -schemaFormat, -throwAll, -throwFirst, -includeSchemas"
            }
        }
    }

    # prepare instance
    if {$instanceFormat eq "yamlFile"} {
        if {[catch {
            set instance [::fileutil::cat $instance]
            set instanceFormat "yaml" 
        } err]} {
            throw {JSONSCHEMA ErrInvalidArg} "Error reading instance file: $err"
        } 
    }
    if {$instanceFormat eq "yaml"} {
        if {[catch {
            set instance [yaml::yaml2huddle $instance]
            set instance [dict get $instance HUDDLE]
            set instanceFormat "huddle" 
        } err]} {
            throw {JSONSCHEMA ErrInvalidArg} "Error converting instance file from yaml to huddle: $err"
        } 
    }
    if {$instanceFormat eq "jsonFile"} {
        if {[catch {
            set instance [::fileutil::cat $instance]
            set instanceFormat "json" 
        } err]} {
            throw {JSONSCHEMA ErrInvalidArg} "Error reading instance file: $err"
        } 
    }
    if {$instanceFormat eq "json"} {
        if {[catch {
            set instance [huddle::json2huddle $instance]
            set instance [dict get $instance HUDDLE]
            set instanceFormat "huddle"
        } err]} {
            throw {JSONSCHEMA ErrInvalidArg} "Error converting instance file from json to huddle: $err"
        } 
    }

    # prepare schema
    if {$schemaFormat eq "jsonFile"} {
        if {[catch {
            set schema [::fileutil::cat $schema]
            set schemaFormat "json" 
        } err]} {
            throw {JSONSCHEMA ErrInvalidArg} "Error reading schema file: $err"
        } 
    }
    if {$schemaFormat eq "json"} {
        if {[catch {
            set schema [huddle::json2huddle $schema]
            set schema [dict get $schema HUDDLE]
            set schemaFormat "huddle"
        } err]} {
            throw {JSONSCHEMA ErrInvalidArg} "Error converting schema file: $::errorInfo"
        } 
    }

    # add main schema to included schemas in order to have one place for all schemas to search for in case of \$ref
    if {[dict exists [_getValueFromHuddle $schema] \$id]} {
        set mainSchemaId [_getValueFromHuddle [dict get [_getValueFromHuddle $schema] \$id]]
    } else {
        set mainSchemaId ""
    }
    dict set includedSchemas $mainSchemaId $schema

    set validationLocalInfo [dict create \
        instancePath [list] \
        schemaPath [list] \
        currentSchemaId $mainSchemaId \
    ]

    set validationGlobalInfo [dict create \
        errors [list] \
        throwAll $throwAll \
        throwFirst $throwFirst \
        includedSchemas $includedSchemas \
        schema $schema \
        instance $instance \
    ]

    _validateRecursive $instance $schema $validationLocalInfo

    if {[llength [dict get $validationGlobalInfo errors]]} {
        if {$throwAll} {
            throw {JSONSCHEMA ErrValidation} [dict create \
                message "Validation failed" \
                errors [dict get $validationGlobalInfo errors] \
            ]
        }

        return [dict create valid false errors [dict get $validationGlobalInfo errors]]
    }

    return [dict create valid true]
}

proc ::jsonschema::_validateRecursive {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo
    
    set schemaValue [_getValueFromHuddle $schema]
    if {$schemaValue eq "false"} {
        _throwError "Item not allowed" ErrItemNotAllowed
        return
    }
    if {$schemaValue eq "true" || [dict size $schemaValue] == 0} {
        # always valid
        return
    }

    if {[dict exists $schemaValue {$schema}]} {
        # check schema version
        set schemaVersion [_getValueFromHuddle [dict get $schemaValue {$schema}]]
        if {$schemaVersion ne "https://json-schema.org/draft/2020-12/schema"} {
            throw {JSONSCHEMA ErrInvalidSchema} "Unknown schema version: $schemaVersion. https://json-schema.org/draft/2020-12/schema is the only supported."
        }
        dict unset schemaValue {$schema}
    }

    # ignore \$id, \$comment, title, description, default, examples, readOnly, writeOnly, deprecated
    dict unset schemaValue {$id}
    dict unset schemaValue {$comment}
    dict unset schemaValue title
    dict unset schemaValue description
    dict unset schemaValue default
    dict unset schemaValue examples
    dict unset schemaValue readOnly
    dict unset schemaValue writeOnly
    dict unset schemaValue deprecated
    
    if {[dict exists $schemaValue \$ref]} {
        return [_validateRef $instance $schemaValue $validationLocalInfo]
    }
    if {[dict exists $schemaValue enum]} {
        return [_validateEnum $instance $schemaValue $validationLocalInfo]
    }
    if {[dict exists $schemaValue const]} {
        return [_validateConst $instance $schemaValue $validationLocalInfo]
    }
    if {[dict exists $schemaValue format]} {
        return [_validateFormat $instance $schemaValue $validationLocalInfo]
    }
    if {[dict exists $schemaValue allOf]} {
        return [_validateAllOf $instance $schemaValue $validationLocalInfo]
    }
    if {[dict exists $schemaValue anyOf]} {
        return [_validateAnyOf $instance $schemaValue $validationLocalInfo]
    }
    if {[dict exists $schemaValue oneOf]} {
        return [_validateOneOf $instance $schemaValue $validationLocalInfo]
    }
    if {[dict exists $schemaValue not]} {
        return [_validateNot $instance $schemaValue $validationLocalInfo]
    }

    if {![dict exists $schemaValue type]} {
        _throwError "Schema type not defined" ErrInvalidSchema
        return
    }

    set schemaType [_getValueFromHuddle [dict get $schemaValue type]]
    switch -- $schemaType {
        "object" {
            return [_validateObject $instance $schemaValue $validationLocalInfo]
        }
        "array" {
            return [_validateArray $instance $schemaValue $validationLocalInfo]
        }
        "string" {
            return [_validateString $instance $schemaValue $validationLocalInfo]
        }
        "integer" -
        "number" {
            return [_validateNumber $instance $schemaValue $validationLocalInfo]
        }
        "boolean" {
            return [_validateBoolean $instance $schemaValue $validationLocalInfo]
        }
        "null" {
            return [_validateNull $instance $schemaValue $validationLocalInfo]
        }
        default {
            _throwError "Unknown schema type" ErrInvalidSchema [dict create schemaPath "type" schemaValue $schemaValue]
        }
    }
}

proc ::jsonschema::_validateRef {instance schema validationLocalInfo} {
    upvar validationGlobalInfo validationGlobalInfo

    set ref [_getValueFromHuddle [dict get $schema \$ref]]
    lassign [split $ref "#"] schemaRef subschemaRef;# split ref into schema and subschema (JSON pointer)

    if {$schemaRef eq ""} {
        # refers to current schema (get from context)
        set foundSchemaId [dict get $validationLocalInfo currentSchemaId]
        set foundSchema [dict get $validationGlobalInfo includedSchemas $foundSchemaId] 
    } elseif {[dict exists $validationGlobalInfo includedSchemas $schemaRef]} {
        # check exact match
        set foundSchemaId $schemaRef
        set foundSchema [dict get $validationGlobalInfo includedSchemas $schemaRef]
    } else {
        # check absolute URI
        if {![uri::isrelative $schemaRef]} {
            throw {JSONSCHEMA ErrInvalidSchema} "Schema \$ref ($ref) is an absolute URI and it does not exists in included schemas."
        }

        set currentSchemaId [dict get $validationLocalInfo currentSchemaId]
        if {$currentSchemaId eq ""} {
            throw {JSONSCHEMA ErrInvalidSchema} "Schema does not contain \$id. It is not possible to resolve \$ref without base URI."
        }
        if {[uri::isrelative $currentSchemaId]} {
            throw {JSONSCHEMA ErrInvalidSchema} "Schema \$id ($currentSchemaId) is not an absolute URI. It is not possible to resolve \$ref ($ref) without base URI."
        }

        set mainSchemaInfo [uri::split $currentSchemaId]
        dict set mainSchemaInfo path $schemaRef
        set foundSchemaId [uri::join {*}$mainSchemaInfo]

        if {![dict exists $validationGlobalInfo includedSchemas $foundSchemaId]} {
            throw {JSONSCHEMA ErrInvalidSchema} "Schema \$ref ($ref) does not exists in included schemas (searching for $foundSchemaId)."
            return
        }

        set foundSchema [dict get $validationGlobalInfo includedSchemas $foundSchemaId]
    }

    # follow defined subschema
    if {$subschemaRef ne ""} {
        set subschemaRef [split $subschemaRef "/"]
        foreach key $subschemaRef {
            if {$key eq ""} {
                continue
            }
            if {[dict exists [_getValueFromHuddle $foundSchema] $key]} {
                set foundSchema [dict get [_getValueFromHuddle $foundSchema] $key]
            } else {
                _throwError "Reference not found" ErrInvalidSchema [dict create schemaPath "ref" schemaValue $ref]
                return
            }
        }
    }

    _validateRecursive $instance $foundSchema [dict merge [_appendPaths $validationLocalInfo "" "\$ref:$ref"] [dict create currentSchemaId $foundSchemaId]]
}