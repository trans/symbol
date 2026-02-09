# SYMBOL - Set-Yielding Model of Bound Operations and Logic

# Build native binary
build:
    crystal build src/symbol.cr -o symbol

# Build WASM (release, lib-only - no CLI/REPL)
wasm:
    crystal build --release --target wasm32-wasi --link-flags="-L/usr/share/wasi-sysroot/lib/wasm32-wasi" src/symbol_wasm.cr -o symbol.wasm

# Build WASM debug
wasm-debug:
    crystal build --target wasm32-wasi --link-flags="-L/usr/share/wasi-sysroot/lib/wasm32-wasi" src/symbol_wasm.cr -o symbol.wasm

# Run REPL
repl:
    crystal run src/symbol.cr -- repl

# Eval expression
eval EXPR:
    crystal run src/symbol.cr -- eval "{{EXPR}}"

# Run tests
test:
    crystal spec

# Check syntax without building
check:
    crystal build --no-codegen src/symbol.cr

# Clean build artifacts
clean:
    rm -f symbol symbol.wasm symbol.dwarf
