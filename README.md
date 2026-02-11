# SYMBOL

An APL-inspired tacit expression language written in Crystal.

SYMBOL uses reverse-reading postfix notation (RRPN) -- expressions are written
left-to-right but evaluated right-to-left, with operators consuming arguments
from the stack. It supports integer-preserving arithmetic, vectorized operations
over arrays, structural operators, and multi-statement programs with assignment.

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  symbols:
    github: axiomatic/symbol
```

Then run `shards install`.

## Usage

### Single Expression

```crystal
require "symbols"

result = SYMBOL.eval("2 + 3")
# => Resolved(5)

result = SYMBOL.eval("Σ [1, 2, 3, 4]")
# => Resolved(10)

result = SYMBOL.eval("2 * (3 + 4)")
# => Resolved(14)
```

### Multi-Statement Programs

Use `program: true` to enable `.` statement separators and `=` assignment:

```crystal
result = SYMBOL.eval("x = 4. x + 2.", program: true)
# => Resolved(6)

bindings = {} of String => SYMBOL::Tacit::TacitValue
SYMBOL.eval("x = 3. y = x * 2. y + 1.", bindings, program: true)
# => Resolved(7)
# bindings == {"x" => 3, "y" => 6}
```

### Variable Bindings

```crystal
bindings = {"k" => 5_i64.as(SYMBOL::Tacit::TacitValue)}
SYMBOL.eval("k + 1", bindings)
# => Resolved(6)
```

### Inline Templates

Evaluate `{{ expr }}` expressions embedded in text:

```crystal
SYMBOL.inline("The answer is {{ 2 + 3 }}.")
# => "The answer is 5."

bindings = {"name" => "world".as(SYMBOL::Tacit::TacitValue)}
SYMBOL.inline("Hello {{ name }}!", bindings)
# => "Hello world!"
```

Inline mode uses program semantics by default, so assignment works inside
templates. Code spans and fences are respected as literal text.

### REPL

```
$ symbols repl
SYMBOL v0.2.0
> 2 + 3
5
> Σ [1, 2, 3, 4]
10
> let x = 5
> x * x
25
```

### CLI

```
symbols eval "2 + 3"        # Evaluate an expression
symbols repl                 # Start interactive REPL
symbols parse "2 + 3"       # Show AST
symbols tokenize "2 + 3"    # Show tokens
```

## Operators

### Arithmetic

| Operator | Description | Arity |
|----------|-------------|-------|
| `+` | Add | 2 |
| `-` | Subtract | 2 |
| `*` | Multiply | 2 |
| `/` | Divide | 2 |
| `%` | Modulo | 2 |
| `^` | Power | 2 |
| `~` | Negate | 1 |

Integer types are preserved when possible. Division of integers that doesn't
divide evenly produces a float.

### Comparison

| Operator | Description | Arity |
|----------|-------------|-------|
| `==` | Equal | 2 |
| `!=` `≠` | Not equal | 2 |
| `<` | Less than | 2 |
| `>` | Greater than | 2 |
| `<=` `≤` | Less or equal | 2 |
| `>=` `≥` | Greater or equal | 2 |

### Logic / Bitwise

| Operator | Description | Arity |
|----------|-------------|-------|
| `!` | Boolean NOT | 1 |
| `[+]` | OR (boolean or bitwise) | 2 |
| `[*]` | AND (boolean or bitwise) | 2 |
| `[-]` | XOR (boolean or bitwise) | 2 |
| `[~]` | NOT (boolean or bitwise) | 1 |

Wrapped operators dispatch by type: booleans get logical operations, integers
get bitwise.

### Aggregation

| Operator | Description | Arity |
|----------|-------------|-------|
| `Σ` | Sum | 1 |
| `Π` | Product | 1 |
| `#` | Count | 1 |
| `⌈` | Ceiling (scalar) / Max (array) | 1 |
| `⌊` | Floor (scalar) / Min (array) | 1 |

### Structural

| Operator | Description | Arity |
|----------|-------------|-------|
| `..` | Range (inclusive) | 2 |
| `><` | Concat | 2 |
| `<>` | Wrap (pair) | 2 |
| `+>` | Cons (prepend) | 2 |
| `<+` | Snoc (append) | 2 |
| `~>` | Zip (interleave) | 2 |
| `<~` | Piz (reverse interleave) | 2 |
| `->` | Remove from back | 2 |
| `<-` | Remove from front | 2 |
| `<->` | Remove from both ends | 2 |
| `↑` | Take | 2 |
| `↓` | Drop | 2 |
| `@` | Index (1-based) | 2 |
| `⌽` | Reverse | 1 |

### Vectorization

Binary arithmetic and comparison operators automatically vectorize over arrays:

```
[1, 2, 3] + 10             => [11, 12, 13]
[2, 3, 4] * [10, 20, 30]   => [20, 60, 120]
```

## Multi-Statement Programs

When `program: true` is passed to `eval`:

- `.` separates statements
- `=` assigns to variables (left-hand side must be an identifier)
- `==` is equality comparison
- The result of the last statement is returned
- Bindings are mutated in place

```
x = 3. y = x * 2. y + 1.
```

Trailing `.` is optional. Spaces between tokens are optional, except when a
digit appears on both sides of a `.` separator (`4.0` is always a float literal
-- use `4 .0 + 1` to disambiguate).

## License

MIT
