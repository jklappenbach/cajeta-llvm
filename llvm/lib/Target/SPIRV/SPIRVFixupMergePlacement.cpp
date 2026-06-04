//===-- SPIRVFixupMergePlacement.cpp - keep merges before branches -*- C++ -*-//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// SPIR-V structured control flow (SPIR-V spec 2.11) requires that an
// OpLoopMerge / OpSelectionMerge be the *second-to-last* instruction in its
// block: it must immediately precede the block's branch terminator. The
// SPIR-V structurizer (SPIRVStructurizer) inserts the merge intrinsic in
// exactly that position. The problem is what happens afterwards.
//
// The merge survives instruction selection as a real OpLoopMerge /
// OpSelectionMerge MachineInstr, and *then* the target-independent
// machine-SSA-optimization passes run over it. MachineCSE in particular will
// break the invariant: when a redundant computation appears in two successor
// blocks, MachineCSE commons it and sinks the single surviving copy into their
// common dominator -- which for a loop/selection header is exactly the block
// that already holds the merge. MachineCSE inserts the commoned instruction
// just before that block's terminator (its standard insertion point), i.e.
// *after* the OpLoopMerge. The header then reads:
//
//     OpLoopMerge %merge %continue None
//     %x = OpIMul ...        ; <-- commoned into the header by MachineCSE
//     OpBranchConditional %cond %body %merge
//
// which spirv-val rejects ("OpLoopMerge must immediately precede ... a branch")
// and which hangs drivers that consume it assuming valid structured CFG (this
// was first observed as a real GPU hang lowering a tiled cooperative-matrix
// GEMM, whose loop-invariant tile offsets are exactly such commoned values).
//
// This pass runs after the machine-SSA optimizations and restores the
// invariant by sinking each block's merge instruction back down to immediately
// before its branch terminator. That move is always safe: OpLoopMerge and
// OpSelectionMerge carry only basic-block-label and immediate operands -- they
// define no register and use no register -- so they have no data dependence on
// the instructions they move past, and reordering them changes no value.
//
//===----------------------------------------------------------------------===//

#include "SPIRV.h"
#include "SPIRVInstrInfo.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/Support/Debug.h"

using namespace llvm;

#define DEBUG_TYPE "spirv-fixup-merge-placement"

namespace {
class SPIRVFixupMergePlacement : public MachineFunctionPass {
public:
  static char ID;
  SPIRVFixupMergePlacement() : MachineFunctionPass(ID) {}

  bool runOnMachineFunction(MachineFunction &MF) override;

  StringRef getPassName() const override {
    return "SPIRV fixup merge placement";
  }

  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties().setIsSSA();
  }
};
} // namespace

static bool isStructuredMerge(const MachineInstr &MI) {
  unsigned Opc = MI.getOpcode();
  return Opc == SPIRV::OpLoopMerge || Opc == SPIRV::OpSelectionMerge;
}

bool SPIRVFixupMergePlacement::runOnMachineFunction(MachineFunction &MF) {
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    // A structured block carries at most one merge instruction (the
    // structurizer guarantees this). Find it, if present.
    MachineInstr *Merge = nullptr;
    for (MachineInstr &MI : MBB) {
      if (isStructuredMerge(MI)) {
        Merge = &MI;
        break;
      }
    }
    if (!Merge)
      continue;

    // The merge must sit immediately before the block's branch terminator.
    MachineBasicBlock::iterator Term = MBB.getFirstTerminator();
    if (Term == MBB.end())
      continue; // No explicit terminator (e.g. unreachable) -- nothing to fix.

    // Already second-to-last? Then the invariant holds.
    if (&*Term == Merge->getNextNode())
      continue;

    // Otherwise a later pass (MachineCSE) slipped instructions between the
    // merge and the terminator. Sink the merge down to just before the
    // terminator, restoring `... <commoned insts> <merge> <branch>`.
    LLVM_DEBUG(dbgs() << "SPIRVFixupMergePlacement: re-seating merge in "
                      << MBB.getName() << "\n");
    Merge->removeFromParent();
    MBB.insert(Term, Merge);
    Changed = true;
  }
  return Changed;
}

INITIALIZE_PASS(SPIRVFixupMergePlacement, DEBUG_TYPE,
                "SPIRV fixup merge placement", false, false)

char SPIRVFixupMergePlacement::ID = 0;

FunctionPass *llvm::createSPIRVFixupMergePlacementPass() {
  return new SPIRVFixupMergePlacement();
}
