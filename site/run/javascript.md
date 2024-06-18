# Running WebAssembly in JavaScript

Here’s an example Orb module that exports a function, and imports a `log.i32` function from the outside world:

```elixir
defmodule Log do
  use Orb.Import

  defw(debug_tally(n: I32))
end

defmodule Example do
  use Orb

  Orb.importw(Log, :log)

  global do
    @count 0
    @tally 0
  end

  defw insert(element: I32) do
    @count = @count + 1
    @tally = @tally + element

    Log.debug_tally(@tally)
  end

  defw calculate_mean(), I32 do
    @tally / @count
  end
end
```

```javascript
async function run() {
  const wasmURL = "/your-module.wasm"; // URL to where your .wasm file is hosted.

  const importObject = {
    log: {
      debug_tally: (n) => console.log("The tally so far:", n)
    }
  };

  const wasmModule = await WebAssembly.compileStreaming(fetch(wasmURL))
  
  const instance = WebAssembly.instantiate(wasmModule, importObject);
  const exports = instance.exports;

  exports.insert(11);
  exports.insert(22);
  exports.insert(99);
  const mean = exports.calculate_mean(); // 44
}
```
