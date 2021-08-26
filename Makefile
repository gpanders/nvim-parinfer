all: lua/parinfer/setup.lua

lua/%.lua: fnl/%.fnl
	fennel --compile $< > $@
