# jsonschema

`jsonschema` library is an implementation of JSON Schema validation for TCL. Notice that this is a partial implementation of the JSON Schema specification, and it is not intended to be a complete implementation. The main goal of this package is to provide a simple way to validate JSON or YAML data against a schema. `jsonschema` aims to support `draft-2020-12` version of the JSON Schema specification based on [https://json-schema.org/](https://json-schema.org/), but it can differ in some minor behavior. The package is written in pure TCL and does not require any external dependencies (despite basic TCL libraries).

## Usage

In order to validate a JSON or YAML data against a schema, you need to call the `validate` method. The `validate` method returns by default a dict with `valid` key indicating whether the data is valid or not. If `valid` is `false` than there exists also `errors` key which is an array containing all errors found in data. The following example demonstrates how to use the `jsonschema` package with yaml instance:

```tcl

# optionally set path to library (if not already somewhere in ::auto_path and pwd = this directory)
lappend ::auto_path .

package require jsonschema

::jsonschema::validate -instanceFormat yaml \
{
    name: "Gandalf"
    age: 777
    isWizard: false} \
{{
    "type": "object",
    "properties": {
        "name": {
            "type": "string"
        },
        "age": {
            "type": "number"
        },
        "isWizard": {
            "type": "boolean"
        },
        "someNonExistingProperty": {
            "type": "boolean"
        }
    },
    "required": ["name"],
    "additionalProperties": false
}}
```

## Options

The `validate` method accepts the following arguments `::jsonschema::validate ?options? instance schema`, where options are:
- `-instanceFormat` - specifies the format of the instance data. The possible values are `json`, `jsonFile`, `yaml`, `yamlFile` and `huddle`. The default value is `json`, while those ended with `File` are used to specify the file path to the instance data,
- `-schemaFormat` - specifies the format of the schema data. The possible values are `json`, `jsonFile` and `huddle`. The default value is `json`,
- `-throwFirst` - if set to `true`, the `validate` method will throw an error on the first validation error. The default value is `false`,
- `-throwAll` - if set to `true`, the `validate` method will throw an error with list of all encountered errors. 
The default value is `false`, which will cause returning dict with `valid` and `errors` keys.
- `-includeSchemas` - specifies a list of schemas to include. Elements of that list are in form of dict containing exactly one of `json` or `jsonFile` key (similar to `-schemaFormat`) and optionally `id` key to override schemas `$id` attribute (note that overriding `id` can cause problems with referencing itself by absolute url). The default value is an empty list.

## Tests
The tests are written using the `tcltest` package. There are a lot of them, so they can also act as a documentation. To run the tests, execute the following command:

```sh
tclsh tests/all.tcl
```
`tcltest` allows you to run individual tests, groups of tests, or all tests. For more information, please refer to the `tcltest` documentation. To run a single test, execute the following command:

```sh
tclsh tests/all.tcl -file string.test
```

## License

This project was originally created by Piotr Karaś https://github.com/piotr-karas while working at ANT Solutions https://antsolutions.eu/.  
It is released under the Apache License 2.0 with the permission of ANT Solutions https://antsolutions.eu/. 
See the [LICENSE](LICENSE) file for details.