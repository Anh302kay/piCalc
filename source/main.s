.arch armv6k
.fpu vfp
#include "pi.inc"
.section .text
	.global main
	.extern gfxInitDefault
	.extern printf
	.extern gfxExit
	.extern consoleInit
    .extern consoleGetDefault
	.extern hidKeysDown
	.extern hidScanInput
	.extern aptMainLoop
    .extern gspWaitForEvent
    .extern gfxFlushBuffers
    .extern gfxSwapBuffers
.balign 4
.align 2
.arm
main:
    push {ip, lr}	@ push return address + dummy register for alignment
    bl gfxInitDefault
    mov r1, #0
    mov r0, #0
    bl consoleInit
    mov r6, r0
    mov r7, #0 @ technically optimisation by using registers instead of storing into stack but i was lazy to test out the stack
    mov r3, #4
    str r3, [r0, #58]

    ldr r0, =str
    bl printf
    ldr r5, =#gspWaitForVBlank+1 @ load label with an offset of 1 for thumb mode

@setup bottom screen
    mov r0, #1
    mov r1, #0
    bl gfxSetDoubleBuffering
    mov r2, #0
    mov r3, #0
    bl gfxGetFramebuffer
    ldr r1, =#pi_sideways
    ldr r2, =#230400
    bl memcpy

@prep vfp registers
    mov r0, #1
    mov r1, #2
    mov r2, #3
    mov r3, #4

    vmov.f32 s0, r2 
    vmov.f32 s2, r1
    vmov.f32 s4, r0
    vcvt.f64.u32 d0, s0 
    vcvt.f64.u32 d1, s2
    vcvt.f64.u32 d2, s4

@constants
    vmov.f32 s6, r0 @ 1
    vmov.f32 s7, r1 @ 2
    vmov.f32 s8, r3 @ 4
    vcvt.f64.u32 d14, s6 @ 1
    vcvt.f64.u32 d15, s7 @ 2
    vcvt.f64.u32 d13, s8 @ 4

    mov r0, #0
    bl loop

loop:
    bl aptMainLoop
    cmp r0, #0
    beq exit

@rendering
    bl gfxFlushBuffers
    bl gfxSwapBuffers
    blx r5

@print and calculate
    bl piCalc
    ldr r0, =str
    vmov r2, r3, d0
    bl printf

@input
	bl hidScanInput
	bl hidKeysDown

@right key press
    ldr r1, =#268435472
    ands r1, r0
    addne r7, r7, #1
    cmp r7, #24
    moveq r7, #23
    strne r7, [r6, #58]

@left key press
    ldr r1, =#536870944
    ands r1, r0
    subnes r7, r7, #1
    movmi r7, #0
    strne r7, [r6, #58]

    mov r1, #8 @ start key
    cmp r1, r0
    bne loop
    
quit:
    bl gfxExit
    pop {ip,pc}

@ d0 PI, D1 N, D2 SIGN
@(sign * (4 / ((n) * (n + 1) * (n + 2) ) )   ) 
piCalc:
    push {lr}

    vadd.f64 d4, d1, d14 @ (n + 1)
    vadd.f64 d5, d1, d15 @ (n + 2)

    vmul.f64 d3, d1, d4 @ (n) * (n + 1)
    vmul.f64 d3, d3, d5 @ (n) * (n + 1) * (n + 2)

    vdiv.f64 d3, d13, d3 @ 4 / ( (n) * (n + 1) * (n + 2) )

    vmla.f64 d0, d3, d2  @ PI + sign * ( 4 / ( (n) * (n + 1) * (n + 2) ) )

    vneg.f64 d2, d2
    vadd.f64 d1, d1, d15 @ d1 + 2

    pop {pc}

.thumb
gspWaitForVBlank:
    nop
    mov r4, lr @ save return address as it will be rewritten later
    mov r0, #2 
    mov r1, #1
    bl gspWaitForEvent @ wait for vblank
    bx r4 @ return

.arm
.balign 4
.align 2
.section .data

str: .asciz "Hello Assembly! %.13f\n"