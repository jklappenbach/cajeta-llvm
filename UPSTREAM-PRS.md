# Upstream PR series — cajeta-llvm SPIR-V fork

This fork (`cajeta-spirv` branch) carries SPIR-V backend changes that cajeta's
Vulkan backend depends on. They are intended for upstream submission to
`llvm/llvm-project` as a **series of small, logically-scoped PRs** — not one
large change. This file tracks each commit, the PR it belongs to, and its
upstream-readiness. **We file the PRs once the XPU work is settled.**

**Test status (all 5 ready):** every PR has a passing SPIR-V lit test
(`llc | FileCheck`, + `spirv-val` where applicable), verified locally with the
fork's `llc`/`FileCheck`/`spirv-val`:

| PR | code commit(s) | lit test(s) | test-fix commit (squash in) |
|----|----------------|-------------|-----------------------------|
| 1 | `b1d0409`,`0743ee9`,`436a7fd`,`4dfa49b` | `extensions/SPV_KHR_ray_query/{ray_query_ops,ray_query_type,ray_query_kernel,acceleration_structure_type}.ll` | — |
| 2 | `66b561c` | `extensions/SPV_KHR_cooperative_matrix/cooperative_matrix_{ops,type}_vulkan.ll` | `927a0a8` (add missing `+SPV_KHR_vulkan_memory_model`) |
| 3 | `40fccdd` | `structurizer/fixup-merge-placement.mir` | — |
| 4 | `2849c53` | `pointers/type-deduce-global-array-undef.ll` | `014276d` |
| 5 | `6114125` | `extensions/SPV_KHR_cooperative_matrix/cooperative_matrix_workgroup_source.ll` | `f1b183e` (test + a store access-chain ordering fix) |

To list our own (non-upstream) commits on the SPIR-V target:

```sh
git log --format='%H %s' -- llvm/lib/Target/SPIRV/ | grep -vE '#[0-9]+\)$'
```

(Upstream commits keep their `(#NNNNNN)` PR suffix; ours do not.)

---

## PR 1 — `SPV_KHR_ray_query` lowering

Adds the ray-query opaque types and lowers `SPV_KHR_ray_query` operations via
`llvm.spv.*` intrinsics. Self-contained extension support; no behavior change for
existing flavors.

| commit | summary |
|--------|---------|
| `b1d0409198381c21c03366be1a8e2f0e6fcc20e4` | [SPIRV] Add OpTypeRayQueryKHR opaque type (SPV_KHR_ray_query) |
| `0743ee9afa06da42239f5555f29aefb81c31f0fd` | [SPIRV] Add OpTypeAccelerationStructureKHR opaque type (SPV_KHR_ray_query) |
| `436a7fd647c5f4585d39d18e371f08c8662facec` | [SPIRV] Lower SPV_KHR_ray_query operations via llvm.spv intrinsics |
| `4dfa49bdc223e7173e6f3badd8ea88643da858a4` | [SPIRV] Add ray-query GetIntersectionPrimitiveIndexKHR lowering |

- **Status:** in fork, exercised by cajeta ray-query device tests.
- **Upstream prep:** add SPIR-V backend lit tests (`.ll` → `OpRayQuery*`),
  rebase on top-of-tree, confirm the extension gating matches upstream style.

## PR 2 — Cooperative matrix under the Vulkan/Shader flavor

Enables `SPV_KHR_cooperative_matrix` ops under the Vulkan/Shader environment
(previously OpenCL/Kernel-flavor only paths).

| commit | summary |
|--------|---------|
| `66b561c9413703ea3b4c330e01825f82c042e5ca` | [SPIRV] Cooperative matrix under the Vulkan/Shader flavor |

- **Status:** in fork, exercised by cajeta cooperative-matrix Vulkan device tests
  (mixed-precision, K-accumulation, tiled GEMM) on RADV / gfx1151.
- **Upstream prep:** lit tests for the Vulkan-flavor cooperative-matrix path;
  check overlap with any in-flight upstream coop-matrix work.

## PR 3 — Fix merge instruction displaced by MachineCSE

Bugfix: a merge/phi-region instruction was displaced by MachineCSE, producing
incorrect structured control flow.

| commit | summary |
|--------|---------|
| `40fccdd5126b9aa34a8e30d5f0c140a2b8cac04a` | [SPIRV] Fix merge instruction displaced by MachineCSE |

- **Status:** in fork.
- **Upstream prep:** minimal `.ll` reproducer demonstrating the displaced merge;
  this is an independent bugfix and can land first.

## PR 4 — Deduce pointee type for all global variables, not only initialized ones

Bugfix: `processGlobalValue` only recorded a global's element type when
`hasInitializer()` was true, which excludes undef-initialized **non-constant**
aggregates (e.g. a Workgroup `[N x T]` shared tile). Such a global's pointee type
was then inferred from a flat element-typed GEP use as the scalar element, the
array-to-pointer-decay GEP rewrite was skipped, and under Logical SPIR-V the
dynamic index was dropped — every invocation accessed element 0 (silently wrong
workgroup-shared reductions / GEMM staging; the module still passes spirv-val).
The fix records the concrete declared value type for every global.

| commit | summary |
|--------|---------|
| `2849c532820328544bee3ea3d8acd25289d3f457` | [SPIR-V] Deduce pointee type for all global variables, not only initialized ones |

- **Status:** in fork; verified with `llc` + `spirv-val` on a minimal repro
  (Workgroup `[256 x i32]` round-trip with a loop-variant index) and a 26-test
  cajeta Vulkan/AMD/Shared regression sweep (no regressions).
- **Repro (self-contained, for the PR):** a compute shader with
  `@g = internal addrspace(3) global [256 x i32] undef`, written/read with
  `getelementptr i32, ptr @g, %i` inside a loop — before: `%g` typed
  `OpTypePointer Workgroup uint` (scalar), index dropped; after: array-typed with
  an indexed `OpAccessChain`.
- **Upstream prep:** convert the repro to a SPIR-V backend lit test asserting the
  `OpTypeArray` / indexed `OpAccessChain`; this is an independent bugfix and can
  land early.

## PR 5 — Access-chain aggregate pointers to element 0 for cooperative matrix load/store

Bugfix (depends conceptually on PR 4): `OpCooperativeMatrixLoad/StoreKHR` require
the Pointer to point to a scalar/vector (the tile element). A workgroup-shared
array tile reaches the selector as a pointer to the whole `[N x T]` array — in
opaque-pointer IR `&arr[0]` is the same SSA value as `&arr`, and a zero-index
element GEP is simplified back to the array base in SPIRVEmitIntrinsics — so the
op was emitted with an array pointer (spirv-val: "Pointer's Type must be a scalar
or vector type"). The selection now access-chains an aggregate pointer to element
0; already-element-typed pointers (StorageBuffer / dynamic-offset access chains)
pass through untouched.

| commit | summary |
|--------|---------|
| `6114125dc940cf...` (cajeta-spirv) | [SPIR-V] Access-chain aggregate pointers to element 0 for cooperative matrix load/store |

- **Status:** in fork; verified with `llc` + `spirv-val` on a Workgroup-tile
  cooperative-matrix load, and a full LDS-staged GEMM (CoopStage copy → barrier →
  load(Shared) → mma) computing **bit-exact on RADV / gfx1151**. 27-test cajeta
  regression sweep, no regressions. Together with PR 4 this makes LDS-staged
  cooperative-matrix GEMM work on Vulkan (the `XPU-N04` gate is removed).
- **Upstream prep:** SPIR-V backend lit test asserting an `OpAccessChain` to
  element 0 precedes `OpCooperativeMatrixLoadKHR` for a Workgroup-array pointer.

---

## Upstream policy + final PR structure (verified against current llvm/main)

Per `llvm/docs/GitHub.rst`: the monorepo uses **squash-merge only** (one commit per
PR), and **stacked PRs are the official mechanism** for landing dependent changes.
Without commit access we use the *"two PRs with a `Depends on #X` note"* form (push
branches to our fork `jklappenbach/cajeta-llvm`, open against `llvm/llvm-project`).
LLVM prefers small **independent** changes, so unrelated features stay independent;
only genuine dependencies are stacked.

Review branches built off `upstream/main`, each verified (applies clean + compiles +
lit tests pass against current `llvm/main`):

| PR | branch | structure |
|----|--------|-----------|
| 3 | `pr/spirv-fixup-merge-placement` | independent |
| 4 | `pr/spirv-global-array-undef-type` | independent |
| 1 | `pr/spirv-ray-query` | independent (5 commits) |
| 2 | `pr/spirv-coopmatrix-vulkan-flavor` | independent — PR-1 textual coupling (`IntrinsicsSPIRV.td` + `selectIntrinsic` switch) resolved out; verified 0 ray-query leakage |
| 5 | `pr/spirv-coopmatrix-aggregate-ptr` | **stacked**: depends on PR 2 (modifies its coop selection) + PR 4 (test needs the array typing). File with `Depends on #PR2, #PR4`; first 2 commits are the deps |

PR 1, 2, 3, 4 land in any order; PR 5 lands after PR 2 + PR 4.

## Filing checklist

Tests are done (table above), so the remaining work is mechanical packaging onto
current `llvm/main`. This needs a GitHub fork of `llvm/llvm-project` and `gh`
auth; it is an outward-facing step, so confirm before pushing.

1. `git remote add upstream https://github.com/llvm/llvm-project` and fetch; the
   fork branch is on an older LLVM base, so each PR is recreated on top of `main`.
2. For each PR, create a branch off `upstream/main` and cherry-pick its code
   commit(s) **plus** the squash-in test commit from the table (combine into one
   commit per PR, code + lit test together). Resolve any rebase conflicts (the
   SPIR-V backend may have moved upstream).
3. `ninja check-llvm-codegen-spirv` on each branch (needs a configured build with
   the LLVM test suite enabled — this fork build has no lit site config).
4. Order: PR 3, PR 4, PR 5 (independent bugfixes; PR 5 after PR 4) first, then
   PR 1 / PR 2 (extension features). Push each branch to your fork and open the PR
   with the reproducer / rationale above; link any related in-flight upstream
   coop-matrix work.
