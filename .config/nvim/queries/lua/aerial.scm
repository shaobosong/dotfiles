((variable_declaration
  (variable_list
    name: (identifier) @name)
  (#set! "kind" "Variable")) @symbol
  (#has-parent? @symbol chunk))

((variable_declaration
  (assignment_statement
    (variable_list
      name: (identifier) @name))
  (#set! "kind" "Variable")) @symbol
  (#has-parent? @symbol chunk))

((function_declaration
  name: [
    (identifier)
    (dot_index_expression)
    (method_index_expression)
  ] @name
  (#set! "kind" "Function")) @symbol
  (#has-parent? @symbol chunk))

((assignment_statement
  (variable_list
    name: [
      (identifier)
      (dot_index_expression)
      (bracket_index_expression)
    ] @name)
  (expression_list
    value: (function_definition) @symbol)
  (#set! "kind" "Function")) @start
  (#has-parent? @start chunk))

((assignment_statement
  (variable_list
    name: [
      (identifier)
      (dot_index_expression)
      (bracket_index_expression)
    ] @name)
  (expression_list
    value: (table_constructor) @symbol)
  (#set! "kind" "Object")) @start
  (#has-parent? @start chunk))
