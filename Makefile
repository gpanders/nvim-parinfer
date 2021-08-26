all: lua/parinfer/setup.lua

lua/%.lua: fnl/%.fnl
	fennel --globals vim --compile $< > $@

clean:
	rm lua/parinfer/setup.lua

.PHONY: all clean
