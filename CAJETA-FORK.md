# cajeta-llvm — fork notes

This is a downstream fork of [llvm/llvm-project](https://github.com/llvm/llvm-project)
carrying SPIR-V backend patches for the **Cajeta** language's GPU compute path
(`cajeta-gpu`). It exists so Cajeta (CI + local) can build against a *prebuilt*
LLVM/clang/lld toolchain that already includes these patches — CI never builds LLVM,
and the Cajeta repo never vendors LLVM source.

The patch branch is **`cajeta-spirv`**. `main` tracks upstream and carries no patches.

## Pinned base

| | |
|---|---|
| Base commit | `203c0668d4b098714d1748de766e890fe6296891` (LLVM 23-git) |
| Branch | `cajeta-spirv` |
| Patches above base | 6 (2 CI + 4 SPIR-V ray-query) |

## Build contract

A toolchain release MUST be configured exactly as:

- `CMAKE_BUILD_TYPE=Release` · `LLVM_ENABLE_RTTI=ON` · `LLVM_ENABLE_ASSERTIONS=OFF`
- `LLVM_TARGETS_TO_BUILD=X86;NVPTX;AMDGPU;SPIRV` · static libs (no shared/dylib)
- `LLVM_ENABLE_PROJECTS=clang;lld` — the artifact bundles a version-matched
  `clang-23` (Cajeta compiles its runtime to bitcode via
  `find_program(clang-${LLVM_VERSION_MAJOR})`).

Built + released by `.github/workflows/build-cajeta-llvm.yml`; consumed per
`cajeta/plans/c0/cajeta-ci-consume.yml`.

## Applied-patch inventory (`203c0668d` → `cajeta-spirv` HEAD)

In apply order (oldest first):

| Commit | Kind | Summary |
|---|---|---|
| `d8b49886a4d4` | CI | build + release cajeta LLVM/clang/lld toolchain |
| `b1425f80c299` | CI | host matrix + self-hosted dep guard + fix asset name |
| `b1d040919838` | SPIRV | Add `OpTypeRayQueryKHR` opaque type (`SPV_KHR_ray_query`) |
| `0743ee9afa06` | SPIRV | Add `OpTypeAccelerationStructureKHR` opaque type (`SPV_KHR_ray_query`) |
| `436a7fd647c5` | SPIRV | Lower `SPV_KHR_ray_query` operations via `llvm.spv` intrinsics |
| `ad584d2d8a00` | SPIRV | Add spirv-val-clean ray-query kernel test (descriptor-bound AS) |

The 4 SPIRV commits are the **ray-query lowering** (`cajeta-gpu` Part C, increment
C3.3). `436a7fd6` is the load-bearing codegen commit — any release that does not
include it cannot lower ray query.

## Release status

| Tag | Built from | Contains ray-query? | Host artifacts |
|---|---|---|---|
| `cajeta-llvm-23-r1` | (pre-ray-query) | ❌ no | linux-x64 |
| `cajeta-llvm-23-r2` | `b1425f80` (CI commit) | ❌ no — predates `b1d04`/`436a7` | — |
| `cajeta-llvm-23-r3` | **TODO: cut from `ad584d2d` (or ≥ `436a7fd6`)** | ✅ (once cut) | linux-x64 first; aarch64-linux next |

> **Open action:** r1/r2 both predate the ray-query commits. Cut **r3** from
> `cajeta-spirv` HEAD so a published toolchain actually carries the lowering, then
> point Cajeta's `release.yml` at r3 (parked in `cajeta/plans/c0/cajeta-ci-consume.yml`).

## Maintenance

- **Rebase cadence:** periodically re-pin `cajeta-spirv` onto a newer upstream commit
  and drop any patch that landed upstream; update the base commit + inventory above.
- **Upstream stance:** the ray-query lowering is **deliberately held downstream** for
  now — the intent is to accumulate a credible body of SPIR-V compute work on the fork
  before proposing an upstream PR. Do not open an upstream PR until that bar is met.
  (CI commits `d884`/`b142` are fork-only and never upstream.)
