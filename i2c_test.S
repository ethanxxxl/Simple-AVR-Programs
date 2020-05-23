#include <avr/io.h>
#include <util/twi.h>

; this is the displays address.
; if you want to read from the device, you must or this with 1
.equ DISPLAY_ADDR, 0b011110

.global main
main:
	;
	; Set stack polditer
	;
	ldi r16, lo8(RAMEND)
	ldi r17, hi8(RAMEND)
	sts SPL, r16
	sts SPH, r17

	
	ldi r16, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN) ; send start condition
	sts TWCR, r16                            ; ^

wait1:           ; wait for the TWINT flag to be set.
	ldi r16, TWCR     ;  this means that the start condition
	sbrs r16, TWINT  ;  has been transmitted
	rjmp wait1       ;

	ldi r16, TWSR     ; check value of TWI Status Register.
	andi r16, 0xF8   ; Mask prescalar bits
	cpi r16, TW_START   ; if status is different from start, go
	brne ERROR0      ;  to ERROR

	ldi r16, DISPLAY_ADDR          ; Load SLA_W ldito TWDR. Clear
	sts TWDR, r16                  ;  TWINT bit ldi TWCR to start
	ldi r16, (1<<TWINT)|(1<<TWEN)  ;  transmission of the address
	sts TWCR, r16                  ;

wait2:
	ldi r16, TWCR     ; Wait for TWINT Flag to be set. This ldidicates
	sbrs r16, TWINT  ;  that SLA+W has been transmitted, and ACK/NACK
	rjmp wait2       ;  has been recieved.

	ldi r16, TWSR         ; Check value of TWI Status register.
	andi r16, 0xF8       ; Mask prescaler bits.
	cpi r16, TW_MT_SLA_ACK  ; If status differes from MT_SLA_ACK,
	brne ERROR1           ; go to ERROR

	ldi r16, 0b10100101                 ; Load DATA ldito TWDR. Clear
	sts TWDR, r16                  ;  TWINT bit ldi TWCR to start
	ldi r16, (1<<TWINT)|(1<<TWEN)  ;  transmission of data
	sts TWCR, r16                  ;

wait3:
	ldi r16, TWCR     ; Wait for TWINT Flag to be set.
	sbrs r16, TWINT  ; This ldidicates that DATA has been transmitted,
	rjmp wait3       ; and ACK/NACK has been recieved.

	ldi r16, TWSR          ; check value of TWSR.
	andi r16, 0xF8        ; Mask prescaler bits
	cpi r16, TW_MT_DATA_ACK  ; if status is different from MT_DATA_ACK
	brne ERROR2            ; go to ERROR
	
	ldi r16, (1<<TWINT)|(1<<TWEN)|(1<<TWSTO)
	sts TWCR, r16 ; transmit STOP condition


ERROR0:
	ldi r18, 0xff
	ldi r19, 0b100
	sts DDRA, r18
	sts PORTA, R19

ERROR1:
	ldi r18, 0xff
	ldi r19, 0b1000
	sts DDRA, r18
	sts PORTA, R19

ERROR2:
	ldi r18, 0xff
	ldi r19, 0b1100
	sts DDRA, r18
	sts PORTA, R16
