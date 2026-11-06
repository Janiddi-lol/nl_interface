# Natural-language interface using Lambek calculus

This program checks sentences using product-free Lambek calculus, constructs
their lambda-expression interpretations, and evaluates those interpretations
against a Python fact database.

## Build and run

```bash
ghc ChatLLaMbda.hs -o ChatLLaMbda
./ChatLLaMbda
```

At the prompts, enter `animals.elx` as the lexicon and `aniworld.py` as the
fact database.

Example:

```text
Lexicon file: animals.elx
Facts about the world: aniworld.py
Starting chat...
> Seamus sleeps
Sense [Sleeps_2 Seamus_1]: True
> Conor sleeps
Sense [Sleeps_2 Conor_1]: False
```

Sentences with multiple derivations are reported as ambiguous, and each
reading is evaluated separately.

## Design

**Grammaticality (`dec_rinv`/`dec_lfoc`).** The decision procedure follows
Lambek's sequent calculus, split into two mutually recursive phases to keep
the search terminating and avoid redundant branches:

- `dec_rinv` repeatedly applies the right rules (`\R`, `/R`), which are
  invertible — always safe to apply eagerly without losing completeness —
  until the goal is atomic.
- `dec_lfoc` then *focuses* on a single formula from the context and
  decomposes it with the left rules, splitting the surrounding context
  (via `splits`) between the rule's two premises. Only a context formula
  can be focused on (via `focuses`), never the goal itself once atomic, which
  is what keeps the search from looping on the goal side.

An atomic goal succeeds only when focusing lands on a bare atom equal to the
goal with nothing left over in the context (the identity axiom); this is why
`focuses`/`splits` must allow empty prefixes/suffixes — left rules can
consume a context entry at either edge.

**Derivations (`der_rinv`/`der_lfoc`).** These mirror the two functions
above exactly rule-for-rule, but build an `LExp` proof term instead of a
`Bool`. Context entries carry a `Var` naming which lexical occurrence (or
hypothetical, for `\R`/`/R`) they came from, so the resulting term records
which words were combined and how. Each hypothetical introduced by a right
rule gets a name from `fresh`, and because that name is threaded into the
context before any further recursion, it can never clash with a later
hypothetical on the same derivation path — so no extra alpha-renaming is
needed when printing the term as `\a. ...`. Multiple results from `der_rinv`
correspond to genuinely distinct parses (e.g. quantifier scope), which is
how `Every cat fears a dog` is reported as ambiguous with two different
truth values.

**Semantics (`toPython`/`showSense`).** The extended lexicon (`.elx`)
attaches a Python expression to each word sense. `derivations` pairs each
proof term with the meanings chosen for that reading; `toPython` then walks
the term, substituting each lexical variable for its Python code and
translating `LExp` application/abstraction into Python
application/`lambda`. The result is shipped to a persistent `python3 -i`
subprocess (`PySupport.hs`) preloaded with the fact database, so it can be
evaluated directly in that environment without re-parsing the facts per
query.

**Scope.** The grammar is the product-free fragment of Lambek calculus (no
multiplicative conjunction type), matching what the template's `LTp`
supports.

## Test

```bash
runghc Tests.hs
ghc -Wall -fno-code ChatLLaMbda.hs
```

## Acknowledgements

OpenAI Codex was used to explain the assignment, and
generate tests. The resulting changes were compiled and tested against the
supplied examples.
