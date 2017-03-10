# MetalToy
A live editing environment for Apple's Metal MSL shader libraries

Currently at alpha stage: Usable, generally stable, but some features are missing.

General plan for further features:

- Texture / buffer data loading and assignment to function inputs.
- Function chaining. I.e. render function A to buffer X, render function B using X as an input.
