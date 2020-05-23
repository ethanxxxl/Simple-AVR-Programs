#include <avr/io.h>

.global main

main:
	; set the stack pointer
	ldi r16, lo8(RAMEND)
	sts SPL, r16
	ldi r16, hi8(RAMEND)
	sts SPH, r16

	sei

	; set data direction
	ldi r16, 0xFF
	sts DDRA, r16
	sts DDRB, r16

	; timer stuff
	ldi r16, (1<<CS11) ; set clock prescaler
	ldi r17, 0x00
	sts TCCR1A, r17
	sts TCCR1B, r16
	sts TCCR1C, r17
	ldi r16, (1<<TOIE1); enable overflow interrupt
	sts TIMSK1, r16
	ldi r16, 0xFF
	sts TIFR1, r16 ; clear the interrupt flags

	ldi r20, 0x01
	sts PORTB, r20 ; r20 will be the designated
					; counter register

LOOP:
	sts PORTA, r20
jmp LOOP

.globl TIMER1_OVF_vect
TIMER1_OVF_vect:
	push r16
	lds r16, SREG
	inc r20
	sts SREG, r16
	pop r16
	reti
