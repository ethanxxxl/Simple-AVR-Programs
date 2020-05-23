#include <avr/io.h>

.data
data:
	.set data_len, 12
	.space data_len, 0

.text
.global main
main:
	; set the stack pointer
	ldi r16, lo8(RAMEND)
	sts SPL, r16
	ldi r16, hi8(RAMEND)
	sts SPH, r16

	; enable interrupts
	sei

	;
	; setup variable
	;
	ldi r26, lo8(data)
	ldi r27, hi8(data)

	ldi r17, 0xA0
	ldi r18, 0xA1
	ldi r19, 0xA2
	ldi r20, 0xA3
	ldi r21, 0xA4
	ldi r22, 0xA5

	st X+, r17
	st X+, r18
	st X+, r19
	st X+, r20
	st X+, r21
	st X+, r22
	st X+, r17
	st X+, r18
	st X+, r19
	st X+, r20
	st X+, r21
	st X+, r22

	;
	; set inputs/outputs
	;
	ldi r16, 0<<PB0 ; set input data direction for PB0
	sts DDRB, r16   ; ^

	ldi r16, 1<<PB0 ; set pullup for PB0
	sts PORTB, r16

	ldi r16, 0<<PE5 ; set input PE5
	sts DDRE, r16
	ldi r16, 1<<PE5 ; set pullup PE5
	sts PORTE, r16

	ldi r16, 0xFF ; set output data direction for PA0
	sts DDRA, r16   ; ^
	sts DDRD, r16 ; set output data direction for PORTD

	ldi r16, 0b0000001
	sts PORTA, R16

	; external interrupt stuff
	ldi r16, (1<<ISC41)|(1<<ISC40)
	sts EICRB, r16
	ldi r16, (1<<INT4)
	sts EIMSK, r16


	ldi r20, 0 ; this is the counter register

LOOP:
	sts PORTD, r20
	jmp LOOP

.globl INT4_vect
INT4_vect:
	inc r20
	cpi r20, data_len
	brge reset
	rjmp write_mem
reset:
	clr r20

write_mem:
	ldi r28, lo8(data)
	ldi r29, hi8(data)

	add r28, r20
	clr r2
	adc r29, r2

	ld r18, Y
	
	sts PORTA, r18
	reti
