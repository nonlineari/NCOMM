# CIM++ Deserializer — Findings Report

**Source:** *Automated Deserializer Generation from CIM Ontologies*
**Authors:** Razik, Mirz, Knibbe, Lankes, Monti — RWTH Aachen University, 2017
**Project:** [http://fein-aachen.org/projects/cimpp](http://fein-aachen.org/projects/cimpp)

---

## Overview

CIM++ is an open-source C++ library that automatically deserializes CIM (Common Information Model) RDF/XML energy topology documents into native C++ objects. The pipeline is model-driven — regenerating automatically when the underlying UML ontology changes — and targets smart grid simulation use cases requiring high-throughput loading of large multi-domain topologies.

---

## Architectural Patterns

### 1. Model-Driven Architecture (MDA) Pipeline
A fully automated chain: UML ontology → code generator → Clang-based toolchain → compilable C++ codebase → deserializer. Re-runnable on any CIM version update without manual intervention.

### 2. CIMFactory (Factory Pattern)
Maps RDF class name strings to object instantiation functions. Stores `rdf:ID` → object pointer in a hash table for association resolution.

### 3. Hash-Table Dispatch
3,000+ assignment functions keyed by XML attribute names. Provides O(1) average-case routing, replacing O(n) if-branch chains.

### 4. SAX Event-Driven Parsing
Single linear pass over the RDF/XML document. Parsed values are written directly into C++ objects — no intermediate DOM tree or RDF triple store.

### 5. Deferred Task Queue
RDF forward-references are enqueued during parsing and resolved in a single post-pass sweep using the `rdf:ID` hash table.

### 6. AST Visitor + Template Engine
Clang's `RecursiveASTVisitor` traverses the C++ AST to feed a CTemplate engine, generating all unmarshalling code at build time. Decouples structural boilerplate from model-specific content.

### 7. BaseClass Injection
A common `BaseClass` is injected into all top-level CIM classes by the toolchain, enabling polymorphic container storage without `void*` or `boost::any`.

---

## Performance Optimizations

| Bottleneck | Mitigation | Complexity Gain |
|---|---|---|
| Assignment function lookup | Hash-table dispatch | O(n) → O(1) |
| Intermediate memory use | SAX direct-write | Eliminates DOM allocation |
| RDF forward-reference resolution | Deferred task queue + hash lookup | Single post-pass |
| Repeated AST header traversal | Source position deduplication table | Prevents redundant visits |
| Runtime type resolution | Compile-time code generation | Zero runtime reflection overhead |

**Core principle:** Shift avoidable cost from runtime to code-generation time. Where runtime decisions are unavoidable, use hash dispatch.

---

## Limitations

- **No serialization** — marshalling (C++ → CIM RDF/XML) not implemented; noted as future work
- **Circular dependencies** — resolved via manual code patches, not automated
- **Edge-case mappings** — ~12 aggregation tag mismatches require runtime configuration files
- **Enum scoping** — unscoped enumerations in generated code required toolchain correction to strongly-typed `enum class`
- **Comparable tooling** — PyCIM was the only known alternative at time of writing, supporting CIM ≤ 2011 only

---

## Evaluation Result

Successfully deserialized an IEEE European Low Voltage Test Feeder network extended with a custom `BatteryStorage` class (not in the original CIM standard), validated via CIM2Mod — a CIM-to-Modelica translator built on the CIM++ library.

---

*Report generated from PDF scan — April 2026*
