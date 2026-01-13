;; Warning: Ignore identifers defined as macros.

;; 'struct_specifier' which not have a parent named 'type_definition'
((struct_specifier
  name: (type_identifier) @name
  body: (field_declaration_list)
  (#set! "kind" "Struct")) @symbol
 (#not-has-parent? @symbol type_definition))

(type_definition
  type: (struct_specifier
    body: (field_declaration_list)) @symbol
  declarator: (type_identifier) @name
  (#set! "kind" "Struct")) @start

;; 'enum_specifier' which not have a parent named 'type_definition'
((enum_specifier
  name: (type_identifier)? @name
  body: (enumerator_list)
  (#set! "kind" "Enum")) @symbol
 (#not-has-parent? @symbol type_definition))

(type_definition
  type: (enum_specifier
    body: (enumerator_list)) @symbol
  declarator: (type_identifier) @name
  (#set! "kind" "Enum")) @start

(preproc_def
  name: (identifier) @name
  value: (preproc_arg)
  (#set! "kind" "Method")) @symbol @start

(preproc_function_def
  name: (identifier) @name
  (#set! "kind" "Method")) @symbol @start

; (declaration
;   type: (_)
;   declarator: (function_declarator
;     declarator: (identifier) @name
;     (#set! "kind" "Function"))) @symbol

; (function_definition
;   type: (_)
;   declarator: (function_declarator
;     declarator: (identifier) @name
;     (#set! "kind" "Function"))) @symbol

(function_declarator
  declarator: (_) @name
  (#set! "kind" "Function")) @symbol

;; Global variables
((declaration
  type: (_)
  declarator: [
    (identifier) @name
    (init_declarator
      declarator: (identifier) @name)
    (init_declarator
      declarator: (array_declarator
        declarator: (identifier) @name))
  ]
  (#set! "kind" "Variable")) @symbol
  (#has-parent? @symbol translation_unit))

(class_specifier
  name: (type_identifier) @name
  (#set! "kind" "Class")) @symbol
