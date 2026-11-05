[
  inputs: [
    "{lib,test,config}/**/*.{ex,exs}",
    "mix.exs"
  ],
  line_length: 120,
  locals_without_parens: [
    defdelegate: :*
  ]
]
