# Core WebAssembly

Orb targets Core WebAssembly, also known as WebAssembly 1.0.

WebAssembly is a low level language. Variables are integers or floats, 32 or 64-bit.

You can import values as globals or import functions from the outside world, known as the host.

You can define functions. You can define globals variables. You can define a single global array of memory. Your function can read and write to these globals and memory. You then export the things you want the host to see.

You can initialize memory with string constants. You can define a dynamic list of functions within a table.

And that’s mostly it. Orb aims to give you access to it all. And it adds conveniences to make common patterns easier.

Orb lets you use the full power of WebAssembly. WebAssembly lets you get close to the computational metal of whatever platform it runs on, while keeping it safe with secure sandboxing.
