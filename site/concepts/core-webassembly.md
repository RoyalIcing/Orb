# Core WebAssembly

WebAssembly is a low level language. Variables are integers or floats, 32 or 64-bit.

You can import values as globals or import functions from the outside world (known as the host).

You can define functions. You can define globals. You can define an array of memory. You can make the function read and write to the globals and memory. You export the things you want the host to see.

You can initialize memory with string constants. You can define a dynamic list of functions within a table.

And that’s mostly it. Orb gives you access to it all. It adds conveniences to make common patterns easier.

But mostly Orb lets you use the full power of WebAssembly. WebAssembly lets you get close to the metal of whatever platform it runs on, while keeping it safe with strong sandboxing.
