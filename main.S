; keypad on ports A and F
; LCD on ports K and B

#include <avr/io.h>

BF = 7
RS = 0 ; on PORTB
RW = 1 ; on PORTB
EN = 2 ; on PORTB

BOUNCE_TIME = 50 ; in milliseconds	

.data
; this value will be updated every millisecond.
MILLIS: .space 8, 0x00

last_time:   .space 12, 0   ; milliseconds since last bounce (each button gets one byte)
last_state:  .space 2, 0xFF ; toggle bits which tell the state of the keypad buttons
; note that this is using extra memory to move 0xFF to initialize all of the data in last state.
;     you could probably optimize this.

.global main
main:
	; set stack pointer
	ldi r16, lo8(RAMEND)
	ldi r17, hi8(RAMEND)
	sts SPL, r16
	sts SPH, r17
	
	sei

	;
	; set up millisecond clock
	;
	clr r16                       ;
	sts TCNT0, r16                ; Set the counter to 0

	ldi r16, 250                  ; Set the output compare. this value will give
	sts OCR0A, r16                ;  an interrupt every millisecond at 16 MHz

	ldi r16, (1<<OCIE0A)          ; Enable the output compare A interrupt
	sts TIMSK0, r16               ;

	ldi r16, (1<<WGM01)           ; Set the mode to CTC, and
	ldi r17, (1<<CS01)|(1<<CS00)  ;  the prescaler to 1/64
	sts TCCR0A, r16               ;  Turn on the counter
	sts TCCR0B, r17               ;

	;
	; set input and output ports
	;

	clr r16        ; ports A and F will be inputs,
	ldi r17, 0xF0
	sts DDRA, r16  ; I am only using the first 4 bits of PORTF, but it is easier
	sts DDRF, r17  ; to just make the whole thing an input

	ldi r16, 0xFF  ; turn on the pullup resistors
	ldi r17, 0x0F
	sts PORTA, r16 ;
	sts PORTF, R17 ;

	ldi r16, 0xFF  ; The LCD is on ports K and B. only the first 3
	sts DDRK, r16  ; bits of PORTB are being used, but again, it is easier
	sts DDRB, r16  ; this way.

	;
	; setup LCD
	;

	ldi r16, lo8(514)
	ldi r17, hi8(514)
	call delay

	; function set (8 bits, number of lines = 2, font size = 5x8)
	ldi r16, 0b00111000
	ldi r17, 3
	clr r18
	call send_instruction

	; display on
	ldi r16, 0b00001100
	ldi r17, 3
	clr r18
	call send_instruction

	; Entry Mode Set
	ldi r16, 0b00000110
	ldi r17, 3
	clr r18
	call send_instruction

	; Return home
	ldi r16, 0b00000010
	ldi r17, 35
	clr r18
	call send_instruction

	; clear display
	ldi r16, 0b00000001
	ldi r17, 35
	clr r18
	call send_instruction

	
	;
	; actual program
	;

loop:
	;load button inputs
	;if any are different from their last_state flag, then
	;    checkcheck the corresponding last_time value

	;    if the time is greater than BOUNCE_TIME, then
	;        update the corresponding last status flag.
	;        update the last_time for the button, this is the initial press/bounce
	;    if the time is less than BOUNCE_TIME
	;        do nothing, this is a bounce

	; load in the current button states
	lds r17, PINA
	lds r18, PINF
	mov r22, r17 ; these will be used to set
	mov r23, r18

	; load in the last state flags
	ldi ZL, lo8(last_state)
	ldi ZH, hi8(last_state)
	ld r19, Z+
	ld r20, Z

	eor r17, r19
	eor r18, r20 ; this will cause the value in r17 and r18 to be zero if the current state is the same as last state

	;to loop through all of the buttons,
	; I am essentially doing a for loop
	clr r21 ; there are 12 buttons.
compare_next_button:

	; todo consider just using a branch if carry is cleared, and using the
	;  carry flag as the test register
	sbrs r17, 0 ; if the bit cleared, then nothing needs to be done
	jmp buttons_were_the_same

	; current state and last state are different.
	; load the corresponding last_time to check that
	ldi YL, lo8(last_time)
	ldi YH, hi8(last_time)
	
	add YL, r21 ; add the current index in the loop
	adc YH, 0   ; and increments the high value if the carry is set

	ld r19, Y ; this is now last_time

	cpi r19, BOUNCE_TIME
	brlo debounce_do_nothing ; last_time is lower than last time, so this button is still bouncing

	; if it didn't branch up there, then that means that this is the initial press
	clr r19
	st Y, r19 ; reset the timer
	



debounce_do_nothing:
buttons_were_the_same:
	ror r18
	ror r17
	rjmp compare_next_button

	inc r21
	cpi r21, 12
	brlo compare_next_button

	rjmp loop

detect_presses:
	; todo do something with bit shifting.
	; see if you can use one of the double registers and
	; shift into each other.
	; just shiftadd, and if the value is not a 1, then clear the buttons
	; flag and update its time.
	;
	; you also need to go through buttons that are alreayd pressed
	; and see when they are held, and when they are let go.
	; that is where the time will come in.
	rjmp loop



;	ldi ZL, lo8(mystring)
;	ldi ZH, hi8(mystring)
;
;next:
;	lpm r16, Z+
;	tst r16
;	breq loop
;	call send_character
;	jmp next
;
;loop:
;	jmp loop

; r16 will have the instruction to be written to PORTK
; r17 and r18 will have the required amount of delay for the instruction
.global send_instruction
send_instruction:
	push r16         ; save r16 state
	push r17
	push r19         ; save r19 state


	clr  r19
	sts  PORTK, r16  ; write the instruction
	sts  PORTB, r19  ;

	nop              ; address set-up time

	ori  r19, 1<<EN  ; write enable to port B
	sts  PORTB, r19

	nop              ; enable toggle time
	nop
	
	clr  r19         ; easily turn off the enable flag
	sts  PORTB, r19

	mov  r16, r17     ; set up parameters for delay subroutine.
	mov  r17, r18     ; the instruction in r16 is no longer needed,
	call delay       ; so we can overwrite it.

	pop  r19
	pop  r17
	pop  r16

	ret

; r16 will have the character to be written to PORTK
.global send_character
send_character:
	push r16         ; save r16 state
	push r17         ; save r17 state

	ldi  r17, 1<<RS
	sts  PORTK, r16  ; write the instruction
	sts  PORTB, r17  ;

	nop              ; address set-up time

	ori  r17, 1<<EN  ; write enable to port B
	sts  PORTB, r17

	nop              ; enable toggle time
	nop
	
	andi r17, !(1<<EN) ; turns off the enable flag
	sts  PORTB, r17

	ldi  r16, 2      ; it takes 43 us for the display to write the data.
	clr  r17
	call delay        ; once to provide this delay

	pop  r17
	pop  r16

	ret

; r16 is the low byte for the output compare
; r17 is the high byte for the output compare
; the timer has a 1/1024 prescaler.
.global delay
delay:
	push r16  ; save registers that are being used
	push r17
	
	sts  OCR1AH, r17  ; set up output compare
	sts  OCR1AL, r16  ;

	ldi  r16, (1<<WGM12)|(1<<CS12)|(1<<CS10) ; start timer1
	sts  TCCR1B, r16                         ;

wait_for_timer:
	lds  r16, TIFR1       ; just loop until the timer is done
	sbrs r16, OCF1A      ;
	rjmp wait_for_timer  ;

	ldi  r17, 0xFF   ; clears OCF1A. also clears all other flags
	sts  TIFR1, r17  ;  that shouldn't be set.

	ldi  r16, (1<<WGM12) ; turn off the timer, but keep it in CTC mode
	sts  TCCR1B, r16     ;

	clr  r17          ; reset the timer to 0 in case it ran over a little
	sts  TCNT1H, r17  ;
	sts  TCNT1L, r17  ;

	pop  r17  ; restore the registers that were used
	pop  r16  ;

	ret


; this routine will be called every time a button is pressed, in order to do a software debounce
.global debounce
debounce:
	ret





.global TIMER0_COMPA_vect
TIMER0_COMPA_vect:
	push ZL
	push ZH
	push r24
	push r25
	push r16
	; TODO consider using load and clear here
	lds r16, SREG
	push r16

	clr r16
	sts SREG, r16

	;
	; set the millis register
	;
	ldi ZL, lo8(MILLIS-2)
	ldi ZH, hi8(MILLIS-2) ; these are subtracted by one, becaues it needs to add next.

carry_to_next_word:
	adiw Z, 2
	ld   r24, Z
	ldd  r25, Z+1
	adiw r24, 1
	st   Z, r24
	std  Z+1, r25
	brcs carry_to_next_word

	;
	; update times for buttons
	;
	ldi ZL, lo8(last_time)
	ldi ZH, hi8(last_time)
	
	clr r16
increment_next_button:
	ld r24, Z
	cpi r24, BOUNCE_TIME
	brsh increment_next_button ; if the counter is already past BOUNCE_TIME, then there is no sense in updating it (and doing so could actually cause problems)
	inc r24
	st Z+, r24

	inc r16
	cpi r16, 12
	breq millis_return
	rjmp increment_next_button


millis_return:
	pop r16
	sts SREG, r16
	pop r16
	pop r25
	pop r24
	pop ZH
	pop ZL
	reti

