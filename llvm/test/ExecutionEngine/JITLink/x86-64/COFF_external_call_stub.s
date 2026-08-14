# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc %s -o %t
# RUN: llvm-jitlink -slab-allocate 100Kb -slab-address 0xfff00000 -slab-page-size 4096 \
# RUN: -abs callee=0x7fff00000000 -noexec %t
#
# Check that a call to an external symbol beyond PCRel32 range links, by being
# routed through a jump stub.
#
# COFF has one REL32 relocation for both control transfer and RIP-relative
# data access, so the stub is only applied at CALL/JMP/Jcc sites -- an
# out-of-range data access must still be an error, which COFF_external_var.s
# pins. Without stubs this fails with "relocation target 0x7fff00000000
# (callee) is out of range of PCRel32 fixup", which is what every JIT'd module
# calling into the host CRT hit.

	.text

	.def	main;
	.scl	2;
	.type	32;
	.endef
	.globl	main
	.p2align	4, 0x90
main:
	callq callee
	retq
