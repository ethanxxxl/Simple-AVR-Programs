; this program had an LCD (controlled by an ST7066 controller)
; attached with its data pins on PORTk, and its other control pins
; on PORTB

#include <avr/io.h>

BF = 7 ; this is on port K
RS = 0 ; on port b
RW = 1 ; on port b
EN = 2 ; on port b

.text

my_string:
	.string "Hello, LCD!!!"

.global main
main:
	; set the stack pointer
	ldi r16, lo8(RAMEND)
	ldi r17, hi8(RAMEND)
	sts SPL, r16
	sts SPH, r17

	;
	; set inputs and outputs
	;

	; data lines for display
	ldi r16, 0xFF
	sts DDRK, r16

	; register select, R/W, and enable
	ldi r16, (1<<PB0)|(1<<PB1)|(1<<PB2)
	sts DDRB, r16

	;ldi r16, lo8(78125)
	;ldi r16, hi8(78125)
	ldi r16, lo8(314)
	ldi r16, hi8(314)
	call delay

	ldi r16, 0xff
	sts PORTA, r16

	call wait

	; function set (8 bits, number of lines = 2, font size = 5x8)
	ldi r16, 0b00111000
	clr r17 ; 0 for write mode
	call send_data

	; Delay
	ldi r16, 1
	clr r17
	call delay

	; display on
	ldi r16, 0b00001100
	clr r17
	call send_data

	; Delay
	ldi r16, 1
	clr r17
	call delay

	; Entry Mode Set
	ldi r16, 0b00000110
	clr r17
	call send_data

	; Delay
	ldi r16, 1
	clr r17
	call delay

	; Return home
	ldi r16, 0b00000010
	clr r17
	call send_data

	; around 25 cycles for 1.52 ms
	ldi r16, 25
	clr r17
	call delay

	; clear display
	ldi r16, 0b00000001
	clr r17
	call send_data

	; around 25 cycles for 1.52 ms
	ldi r16, 25
	clr r17
	call delay


	; put in the string address into the Y pointer register
	ldi ZH, hi8(my_string)
	ldi ZL, lo8(my_string)

write_string:
	lpm r16, Z+
	cpi r16, 0
	breq loop

	ldi r17, 1<<RS
	call send_data

	; Delay
	ldi r16, 1
	clr r17
	call delay

	rjmp write_string



loop:
	jmp loop


.global wait
wait:
	; set RS and RW
	ldi r16, (0<<RS)|(1<<RW)|(1<<EN)

	; load the input
	lds r16, PORTK
	sbrc r16, BF ; exits loop if busy flag is cleared
	rjmp wait
	ret

; r16 will have the data to be written to PORTK
; r17 will have the data to be written to PORTB, EN should be 0!
.global send_data
send_data:
	push r17         ; save r17 state

	sts  PORTK, r16  ; write the instruction
	sts  PORTB, r17  ;

	nop              ; address set-up time

	ori  r17, 1<<EN  ; write enable to port B
	sts  PORTB, r17

	nop              ; enable toggle time
	nop
	
	pop  r17         ; turn enable off ; reset r17
	sts  PORTB, r17

	call wait        ; wait for the LCD to finish up

	ret

; r16 is the low byte for the output compare
; r17 is the high byte for the output compare
; the timer has a 1/1024 prescaler.
.global delay
delay:
	push r16  ; save registers that are being used
	push r17
	
	sts OCR1AH, r17  ; set up output compare
	sts OCR1AL, r16  ;

	ldi r16, (1<<WGM12)|(1<<CS12)|(1<<CS10) ; start timer1
	sts TCCR1B, r16                         ;

wait_for_timer:
	lds r16, TIFR1       ; just loop until the timer is done
	sbrs r16, OCF1A      ;
	rjmp wait_for_timer  ;

	ldi r17, 0xFF   ; clears OCF1A. also clears all other flags
	sts TIFR1, r17  ;  that shouldn't be set.

	ldi r16, (1<<WGM12) ; turn off the timer, but keep it in CTC mode
	sts TCCR1B, r16     ;

	clr r17          ; reset the timer to 0 in case it ran over a little
	sts TCNT1H, r17  ;
	sts TCNT1L, r17  ;

	pop r17  ; restore the registers that were used
	pop r16  ;

	ret
