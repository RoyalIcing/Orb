default: build

%.wat: %.exs
	elixir $< > $@

%.wasm: %.wat
	wat2wasm $<

.SECONDARY: %.wat

.PHONY: build
build: $(patsubst %.exs, %.wasm, $(wildcard *.exs))

.PHONY: clean
clean:
	rm -f $(wildcard *.wat)
	rm -f $(wildcard *.wasm)
