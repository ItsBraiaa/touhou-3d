# <Module name>

Copy this file to `docs/engineering/<module>.md` when a module reaches CODE_READY. Keep it short; it is the contract Astra wires against.

## Purpose

One paragraph: what the module owns and what it deliberately does not own.

## Files

- `scripts/<area>/<core>.gd` (Rules Core)
- `scripts/<area>/<adapter>.gd` (Adapter, attached to `<node>` in `<scene>`)
- `tests/unit/<area>/test_<core>.gd`

## Public contract

### Exports (Adapter)

| Export | Type | Default | Required | Meaning |
| --- | --- | --- | --- | --- |

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |

## Dependencies

What this module receives through `setup()` or exports, and from whom.

## Invariants and tests

| Invariant (from ENGINEERING_BRIEF Section 8 or the ticket) | Test |
| --- | --- |

## Setup for Astra

Exact steps to attach and configure in the scene, including which nodes and which values. What error appears if a reference is missing.

## Open issues

Known gaps, deferred decisions, and anything not yet verified in a running scene.
