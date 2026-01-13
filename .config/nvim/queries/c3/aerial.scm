(func_declaration
  (func_header
    name: (ident) @name
    (#set! "kind" "Function"))) @symbol

(func_definition
  (func_header
    name: (ident) @name
    (#set! "kind" "Function"))) @symbol

(macro_declaration
  (macro_header
    name: (ident) @name
    (#set! "kind" "Method"))) @symbol

(struct_declaration
  name: (type_ident) @name
  body: (struct_body)
  (#set! "kind" "Struct")) @symbol

(global_declaration
  (declaration
    name: (ident) @name
    (#set! "kind" "Variable"))) @symbol

(global_declaration
  (const_declaration
    name: (const_ident) @name
    (#set! "kind" "Constant"))) @symbol
