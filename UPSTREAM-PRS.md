# Upstream PR series — cajeta-llvm SPIR-V fork

SPIR-V backend changes this fork carries, packaged for upstream submission to
`llvm/llvm-project` as **one squash-merged commit per PR**. Five PRs: four
independent, one stacked.

Per `llvm/docs/GitHub.rst`: the monorepo uses **squash-merge only**, and stacked
PRs are the official mechanism for dependent changes. Without commit access we use
the *"two PRs with a `Depends on #X` note"* form — push branches to the fork
`jklappenbach/cajeta-llvm`, open PRs against `llvm/llvm-project`. LLVM prefers small
independent changes, so unrelated features stay independent.


## Filed (llvm/llvm-project)

| PR | number |
|----|--------|
| 1 ray-query | #202048 |
| 2 coopmatrix-vulkan | #202049 |
| 3 merge-placement | #202046 |
| 4 global-array | #202047 |
| 5 coopmatrix-aggregate-ptr (stacked, Depends on #202049 #202047) | #202050 |

## The five PRs

Each PR branch is built off `upstream/main` and verified: applies clean, compiles,
and its lit tests pass against current `llvm/main`.

| # | branch | one-line | structure |
|---|--------|----------|-----------|
| 1 | `pr/spirv-ray-query` | `SPV_KHR_ray_query` lowering (opaque types, ops, intrinsics, selection, caps) | independent |
| 2 | `pr/spirv-coopmatrix-vulkan-flavor` | cooperative matrix under the Vulkan/Shader flavor (intrinsics + selection + Vulkan memory model derived from the `CooperativeMatrixKHR` requirement) | independent |
| 3 | `pr/spirv-fixup-merge-placement` | re-seat an `OpLoopMerge`/`OpSelectionMerge` displaced after its branch by MachineCSE | independent |
| 4 | `pr/spirv-global-array-undef-type` | deduce a global variable's pointee type for *all* globals (undef non-constant aggregates kept array-typed) | independent |
| 5 | `pr/spirv-coopmatrix-aggregate-ptr` | access-chain an aggregate pointer to element 0 for cooperative-matrix load/store | **stacked on PR 2 + PR 4** |

- **PR 5 dependencies**: it modifies the cooperative-matrix selection that **PR 2**
  adds, and its lit test relies on **PR 4**'s array typing. File with
  `Depends on #202049 #202047`. Its branch carries 3 commits (PR 2, PR 4, then PR 5's
  own); GitHub shows the combined diff — note "the first two commits are the
  dependencies; this PR adds the third." Once PR 2 + PR 4 merge it rebases to a
  single commit on `main`.
- **PR 1, 2, 3, 4** are independent and land in any order. **PR 5** lands after
  PR 2 + PR 4.

## Reproducers / lit tests (per PR)

- PR 1 — `extensions/SPV_KHR_ray_query/{ray_query_type,ray_query_ops,ray_query_kernel}.ll`, `acceleration_structure_type.ll`
- PR 2 — `extensions/SPV_KHR_cooperative_matrix/cooperative_matrix_{type,ops,kernel}_vulkan.ll`
- PR 3 — `structurizer/fixup-merge-placement.mir`
- PR 4 — `pointers/type-deduce-global-array-undef.ll`
- PR 5 — `extensions/SPV_KHR_cooperative_matrix/cooperative_matrix_workgroup_source.ll`

## How these were validated against the leading edge

Fork base was `203c0668` (llvm/main, ~5 days behind); the 9 intervening upstream
SPIRV commits touch none of our files. All five cherry-pick clean onto current
`upstream/main`, the full SPIR-V target lib compiles there, and every lit test
passes with the current-`main`-built `llc`. (The fork's local build has no lit
site config, so tests are run as `llc ... | FileCheck` / `spirv-val` directly.)

## Notes

- PR 1 was squashed from 5 fork commits into one (tree byte-identical).
- PR 2's memory-model selection is capability-derived (not a name scan): after
  `collectReqs`, a Shader module that requires `CooperativeMatrixKHR` is upgraded
  GLSL450 → VulkanKHR (`RequirementHandler::isCapabilityRequired`), unless
  `!spirv.MemoryModel` set one explicitly.

## To regenerate the branch list

```sh
for b in pr/spirv-ray-query pr/spirv-coopmatrix-vulkan-flavor \
         pr/spirv-fixup-merge-placement pr/spirv-global-array-undef-type \
         pr/spirv-coopmatrix-aggregate-ptr; do
  echo "== $b =="; git log --oneline upstream/main..$b
done
```

## Filing

1. `git push origin <each pr/ branch>`.
2. Open PRs 1–4 (independent) against `llvm/llvm-project:main` from
   `jklappenbach:<branch>`.
3. Open PR 5 last with `Depends on #202049 #202047` and the base-commit note.
4. Each PR's title/body = its commit message; add the reproducer + a note that it
   was verified against current `llvm/main`.
