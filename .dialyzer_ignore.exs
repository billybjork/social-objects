# Dialyzer warnings to ignore
# Only add third-party dependency warnings here - never ignore our own code
[
  # websockex handle_cast/2 no_return warning - upstream issue
  {"deps/websockex/lib/websockex.ex", :no_return}
]
