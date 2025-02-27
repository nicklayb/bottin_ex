
name := `tr -dc A-Za-z0-9 </dev/urandom | head -c 4; echo`

deps:
  mix deps.get

start: deps
  iex --sname {{name}} -S mix
