# Upstream PR series — cajeta-llvm SPIR-V fork

This fork (`cajeta-spirv` branch) carries SPIR-V backend changes that cajeta's
Vulkan backend depends on. They are intended for upstream submission to
`llvm/llvm-project` as a **series of small, logically-scoped PRs** — not one
large change. This file tracks each commit, the PR it belongs to, and its
upstream-readiness. **We file the PRs once the XPU work is settled.**

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

---

## Pending (not yet a PR — under investigation)

- **Cooperative-matrix load/store from Workgroup storage at a constant element
  offset.** After PR 4, Workgroup-array *staging* lowers correctly, but an
  `OpCooperativeMatrixLoadKHR` whose pointer is `&sharedTile[0]` (constant offset)
  still fails validation: the constant-offset element access chain is collapsed
  back to the bare `[N x T]` array variable during selection, and the op requires
  a scalar/vector pointer. (A *dynamic* offset access chain is preserved and is
  expected to work.) cajeta currently gates the `Shared<T>` cooperative-matrix
  source off on Vulkan (`XPU-N04`) until this is fixed. Likely a small fix in the
  GEP/access-chain selection or the coop-matrix pointer handling; will become
  **PR 5** once root-caused and tested.

## Filing checklist (when XPU settles)

1. Rebase the branch on current `llvm/main`.
2. For each PR: split into its own branch off `main`, add SPIR-V lit tests,
   ensure `check-llvm-codegen-spirv` passes.
3. Order: PR 3 and PR 4 (independent bugfixes) first, then PR 1 / PR 2
   (extension features), then PR 5 (pending) once ready.
4. Open PRs with the reproducers above; link related upstream coop-matrix work.
