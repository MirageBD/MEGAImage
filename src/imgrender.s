screencolumn	.byte 0
screenrow		.byte 0

img_fcblock
		.repeat 8
			.byte 0, 1, 2, 3, 4, 5, 6, 7
		.endrepeat

img_misccounter
		.byte 0

img_rowchars
		.byte 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,    1,2,3,4,5,6,7,8,9,10

img_rendinit

		;lda #$00
		;sta $d015

		lda #$32										; pal screen start
		sta palntscscreenstart
		bit $d06f
		bpl :+
		lda #$1a										; ntsc screen start
		sta palntscscreenstart
:

		; WHY THE HELL DO I NEED TO FILL 2 PALETTES HERE???

		lda $d070										; BANK IN BITMAP PALETTE - select mapped bank with the upper 2 bits of $d070
		and #%00111111
		sta $d070

		lda #$00
		ldx #$00										; set bitmap palette
:		sta $d100,x
		sta $d200,x
		sta $d300,x
		inx
		bne :-

		lda $d070										; select mapped bank with the upper 2 bits of $d070
		and #%00111111
		ora #%10000000									; select palette 02
		sta $d070

		lda #$00
		ldx #$00										; set bitmap palette
:		sta $d100,x
		sta $d200,x
		sta $d300,x
		inx
		bne :-

		lda $d070										; select mapped bank with the upper 2 bits of $d070
		and #%00111111
		ora #%11000000									; select palette 03
		sta $d070

		lda #$00
		ldx #$00										; set bitmap palette
:		sta $d100,x
		sta $d200,x
		sta $d300,x
		inx
		bne :-

		lda $d070
		and #%11111100									; set alt palette to 2
		ora #%00000010
		sta $d070



		; DMA_RUN_JOB imgrender_clearbitmapjob
		DMA_RUN_JOB imgrender_clearcolorramjob

		lda #<.loword(SAFE_COLOR_RAM_PLUS_ONE)
		sta uidraw_colptr+0
		lda #>.loword(SAFE_COLOR_RAM_PLUS_ONE)
		sta uidraw_colptr+1
		lda #<.hiword(SAFE_COLOR_RAM_PLUS_ONE)
		sta uidraw_colptr+2
		lda #>.hiword(SAFE_COLOR_RAM_PLUS_ONE)
		sta uidraw_colptr+3

		lda #0
		sta img_misccounter

img_fillsetaltpalbits

		ldz #30*2										; set columns 30-40 to use alt palette
		lda #%01101111
:		sta [uidraw_colptr],z
		inz
		inz
		cpz #40*2
		bne :-

		clc
		lda uidraw_colptr+0
		adc #80
		sta uidraw_colptr+0
		lda uidraw_colptr+1
		adc #0
		sta uidraw_colptr+1
		lda uidraw_colptr+2
		adc #0
		sta uidraw_colptr+2
		lda uidraw_colptr+3
		adc #0
		sta uidraw_colptr+3

		inc img_misccounter
		lda img_misccounter
		cmp #25
		bne img_fillsetaltpalbits


		; fill full colour char pattern ($f000)

		lda #<imgchars
		sta imgri1+1
		lda #>imgchars
		sta imgri1+2

		lda #$00
		sta img_misccounter

		ldx #$00
		ldy #$00
:		tya
		adc img_fcblock,x
imgri1	sta imgchars,x
		inx
		cpx #64
		bne :-

		clc
		lda imgri1+1
		adc #64
		sta imgri1+1
		lda imgri1+2
		adc #0
		sta imgri1+2
		clc
		tya
		adc #$08
		tay
		inc img_misccounter
		lda img_misccounter
		cmp #42
		bne :-

		; fill screen ($e000)

		lda #$00
		sta screencolumn
		sta screenrow

		lda #<(imgscreen+0)
		sta put0+1
		lda #>(imgscreen+0)
		sta put0+2
		lda #<(imgscreen+1)
		sta put1+1
		lda #>(imgscreen+1)
		sta put1+2

		; imgchars = $f000
		; imgchars/64 = $0800

putstart
		ldx screencolumn
		clc
		lda img_rowchars,x								; char to plot
		adc #<(imgchars/64)
put0	sta imgscreen+0									; plot left of 2 chars

		lda #>(imgchars/64)
put1	sta imgscreen+1									; plot right of 2 chars

		clc												; add 2 to screenpos low
		lda put0+1
		adc #02
		sta put0+1
		lda put0+2
		adc #0
		sta put0+2

		clc												; add 2 to screenpos high
		lda put1+1
		adc #02
		sta put1+1
		lda put1+2
		adc #0
		sta put1+2

		inc screencolumn								; increase screen column until 40
		lda screencolumn
		cmp #40
		bne putstart

		lda #0											; reset screencolumn to 0, increase row until 25
		sta screencolumn
		inc screenrow
		lda screenrow
		cmp #25
		beq endscreenplot

		jmp putstart

endscreenplot

		lda #40*2										; logical chars per row
		sta $d058
		lda #$00
		sta $d059

		lda #%00100000									; set H320, V200, ATTR
		sta $d031

		lda #$00
		sta $d016

		lda #$50										; set TEXTXPOS to same as SDBDRWDLSB
		lda $d04c
		lda #$42
		sta $d05c

		lda #$01
		sta $d05b										; Set display to V200
		lda #25
		sta $d07b										; Display 25 rows of text

		lda #<imgscreen									; set pointer to screen ram
		sta $d060
		lda #>imgscreen
		sta $d061
		lda #(imgscreen & $ff0000) >> 16
		sta $d062
		lda #$00
		sta $d063

        rts

; ----------------------------------------------------------------------------------------------------------------------------------------

.define imgoffset $0000

img_render_irq

		php
		pha
		phx
		phy
		phz

		ldx #$00

		lda redleftlo,x
		sta imgrucr+0
		lda redleftmid,x
		sta imgrucr+1
		lda redlefthi,x
		sta imgrucr+2

		lda greenleftlo,x
		sta imgrucg+0
		lda greenleftmid,x
		sta imgrucg+1
		lda greenlefthi,x
		sta imgrucg+2

		lda blueleftlo,x
		sta imgrucb+0
		lda blueleftmid,x
		sta imgrucb+1
		lda bluelefthi,x
		sta imgrucb+2

		lda redrightlo,x
		sta imgrucrr+0
		lda redrightmid,x
		sta imgrucrr+1
		lda redrighthi,x
		sta imgrucrr+2

		lda greenrightlo,x
		sta imgrucgr+0
		lda greenrightmid,x
		sta imgrucgr+1
		lda greenrighthi,x
		sta imgrucgr+2

		lda bluerightlo,x
		sta imgrucbr+0
		lda bluerightmid,x
		sta imgrucbr+1
		lda bluerighthi,x
		sta imgrucbr+2

		clc
		lda palntscscreenstart
		adc #$01
:		cmp $d012
		bne :-

		lda #$00
		sta $d020

		lda #$07
		sta $d020

img_render_irq_loop

		;lda #$8c
		;sta $d020

		lda $d070										; BANK IN BITMAP PALETTE - select mapped bank with the upper 2 bits of $d070
		and #%00111111
		sta $d070

			sta $d707										; inline DMA copy
			.byte $00										; end of job options
			.byte $00										; copy
			.word 240										; count
imgrucr		.word $0000										; src
			.byte $00										; src bank and flags
			.word $d108										; dst
			.byte (($d108 >> 16) & $0f) | %10000000			; dst bank and flags
			.byte $00										; cmd hi
			.word $0000										; modulo, ignored

			sta $d707										; inline DMA copy
			.byte $00										; end of job options
			.byte $00										; copy
			.word 240										; count
imgrucg		.word $0000										; src
			.byte $00										; src bank and flags
			.word $d208										; dst
			.byte (($d208 >> 16) & $0f) | %10000000			; dst bank and flags
			.byte $00										; cmd hi
			.word $0000										; modulo, ignored

			sta $d707										; inline DMA copy
			.byte $00										; end of job options
			.byte $00										; copy
			.word 240										; count
imgrucb		.word $0000										; src
			.byte $00										; src bank and flags
			.word $d308										; dst
			.byte (($d308 >> 16) & $0f) | %10000000			; dst bank and flags
			.byte $00										; cmd hi
			.word $0000										; modulo, ignored

		lda $d070										; BANK IN BITMAP PALETTE - select mapped bank with the upper 2 bits of $d070
		and #%00111111
		ora #%10000000
		sta $d070

			sta $d707										; inline DMA copy
			.byte $00										; end of job options
			.byte $00										; copy
			.word 80										; count
imgrucrr	.word $0000										; src
			.byte $00										; src bank and flags
			.word $d108										; dst
			.byte (($d108 >> 16) & $0f) | %10000000			; dst bank and flags
			.byte $00										; cmd hi
			.word $0000										; modulo, ignored

			sta $d707										; inline DMA copy
			.byte $00										; end of job options
			.byte $00										; copy
			.word 80										; count
imgrucgr	.word $0000										; src
			.byte $00										; src bank and flags
			.word $d208										; dst
			.byte (($d208 >> 16) & $0f) | %10000000			; dst bank and flags
			.byte $00										; cmd hi
			.word $0000										; modulo, ignored

			sta $d707										; inline DMA copy
			.byte $00										; end of job options
			.byte $00										; copy
			.word 80										; count
imgrucbr	.word $0000										; src
			.byte $00										; src bank and flags
			.word $d308										; dst
			.byte (($d308 >> 16) & $0f) | %10000000			; dst bank and flags
			.byte $00										; cmd hi
			.word $0000										; modulo, ignored

		;lda #$00
		;sta $d020

		ldy $d012
		iny

		inx

		lda redleftlo,x
		sta imgrucr+0
		lda redleftmid,x
		sta imgrucr+1
		lda redlefthi,x
		sta imgrucr+2

		lda greenleftlo,x
		sta imgrucg+0
		lda greenleftmid,x
		sta imgrucg+1
		lda greenlefthi,x
		sta imgrucg+2

		lda blueleftlo,x
		sta imgrucb+0
		lda blueleftmid,x
		sta imgrucb+1
		lda bluelefthi,x
		sta imgrucb+2

		lda redrightlo,x
		sta imgrucrr+0
		lda redrightmid,x
		sta imgrucrr+1
		lda redrighthi,x
		sta imgrucrr+2

		lda greenrightlo,x
		sta imgrucgr+0
		lda greenrightmid,x
		sta imgrucgr+1
		lda greenrighthi,x
		sta imgrucgr+2

		lda bluerightlo,x
		sta imgrucbr+0
		lda bluerightmid,x
		sta imgrucbr+1
		lda bluerighthi,x
		sta imgrucbr+2

:		cpy $d012
		bne :-

		cpx #200
		beq :+
		jmp img_render_irq_loop

:		lda #$00
		sta $d020

		;jsr ui_update
		jsr mouse_update
		jsr uimouse_update
		jsr keyboard_update

		lda mouse_released
		beq :+

		lda #$03										; trigger main restart event
		sta main_event
		bra :++

:
		lda keyboard_shouldsendreleaseevent
		beq :+

		lda #$03
		sta main_event

:		

		lda palntscscreenstart
		sta $d012

		plz
		ply
		plx
		pla
		plp
		asl $d019
		rti

palntscscreenstart
		.byte $32

; ----------------------------------------------------------------------------------------------------------------------------------------

imgrender_clearcolorramjob
				.byte $0a										; Request format (f018a = 11 bytes (Command MSB is $00), f018b is 12 bytes (Extra Command MSB))
				.byte $80, $00									; source megabyte   ($0000000 >> 20) ($00 is  chip ram)
				.byte $81, (SAFE_COLOR_RAM) >> 20				; dest megabyte   ($0000000 >> 20) ($00 is  chip ram)
				.byte $84, $00									; Destination skip rate (256ths of bytes)
				.byte $85, $02									; Destination skip rate (whole bytes)

				.byte $00										; No more options

																; 12 byte DMA List structure starts here
				.byte %00000111									; Command LSB
																;     0–1 DMA Operation Type (Only Copy and Fill implemented at the time of writing)
																;             %00 = Copy
																;             %01 = Mix (via MINTERMs)
																;             %10 = Swap
																;             %11 = Fill
																;       2 Chain (i.e., another DMA list follows)
																;       3 Yield to interrupts
																;       4 MINTERM -SA,-DA bit
																;       5 MINTERM -SA, DA bit
																;       6 MINTERM  SA,-DA bit
																;       7 MINTERM  SA, DA bit

				.word 80*50										; Count LSB + Count MSB

				.byte %00000000										; this is normally the source addres, but contains the fill value now
				.byte 0
				.byte $00										; source bank (ignored)

				.word (SAFE_COLOR_RAM) & $ffff					; Destination Address LSB + Destination Address MSB
				.byte (((SAFE_COLOR_RAM) >> 16) & $0f)			; Destination Address BANK and FLAGS (copy to rbBaseMem)
																;     0–3 Memory BANK within the selected MB (0-15)
																;       4 HOLD,      i.e., do not change the address
																;       5 MODULO,    i.e., apply the MODULO field to wraparound within a limited memory space
																;       6 DIRECTION. If set, then the address is decremented instead of incremented.
																;       7 I/O.       If set, then I/O registers are visible during the DMA controller at $D000 – $DFFF.
				;.byte %00000000									; Command MSB

				.word $0000

				.byte $00										; No more options
				.byte %00000011									; Command LSB
																;     0–1 DMA Operation Type (Only Copy and Fill implemented at the time of writing)
																;             %00 = Copy
																;             %01 = Mix (via MINTERMs)
																;             %10 = Swap
																;             %11 = Fill
																;       2 Chain (i.e., another DMA list follows)
																;       3 Yield to interrupts
																;       4 MINTERM -SA,-DA bit
																;       5 MINTERM -SA, DA bit
																;       6 MINTERM  SA,-DA bit
																;       7 MINTERM  SA, DA bit

				.word 80*50										; Count LSB + Count MSB

				.word $000f										; ff = red = transparency. this is normally the source addres, but contains the fill value now
				.byte $00										; source bank (ignored)

				.word (SAFE_COLOR_RAM+1) & $ffff				; Destination Address LSB + Destination Address MSB
				.byte (((SAFE_COLOR_RAM+1) >> 16) & $0f)		; Destination Address BANK and FLAGS (copy to rbBaseMem)
																;     0–3 Memory BANK within the selected MB (0-15)
																;       4 HOLD,      i.e., do not change the address
																;       5 MODULO,    i.e., apply the MODULO field to wraparound within a limited memory space
																;       6 DIRECTION. If set, then the address is decremented instead of incremented.
																;       7 I/O.       If set, then I/O registers are visible during the DMA controller at $D000 – $DFFF.
				;.byte %00000000								; Command MSB

				.word $0000

; ----------------------------------------------------------------------------------------------------------------------------------------

/*
imgrender_clearbitmapjob
				.byte $0a										; Request format (f018a = 11 bytes (Command MSB is $00), f018b is 12 bytes (Extra Command MSB))
				.byte $80, $00									; source megabyte   ($0000000 >> 20) ($00 is  chip ram)
				.byte $81, (imgdata) >> 20						; dest megabyte   ($0000000 >> 20) ($00 is  chip ram)
				.byte $84, $00									; Destination skip rate (256ths of bytes)
				.byte $85, $01									; Destination skip rate (whole bytes)

				.byte $00										; No more options

																; 12 byte DMA List structure starts here
				.byte %00000111									; Command LSB
																;     0–1 DMA Operation Type (Only Copy and Fill implemented at the time of writing)
																;             %00 = Copy
																;             %01 = Mix (via MINTERMs)
																;             %10 = Swap
																;             %11 = Fill
																;       2 Chain (i.e., another DMA list follows)
																;       3 Yield to interrupts
																;       4 MINTERM -SA,-DA bit
																;       5 MINTERM -SA, DA bit
																;       6 MINTERM  SA,-DA bit
																;       7 MINTERM  SA, DA bit

				.word 320*200									; Count LSB + Count MSB

				.word $0000										; this is normally the source addres, but contains the fill value now
				.byte $00										; source bank (ignored)

				.word (imgdata) & $ffff							; Destination Address LSB + Destination Address MSB
				.byte (((imgdata) >> 16) & $0f)					; Destination Address BANK and FLAGS (copy to rbBaseMem)
																;     0–3 Memory BANK within the selected MB (0-15)
																;       4 HOLD,      i.e., do not change the address
																;       5 MODULO,    i.e., apply the MODULO field to wraparound within a limited memory space
																;       6 DIRECTION. If set, then the address is decremented instead of incremented.
																;       7 I/O.       If set, then I/O registers are visible during the DMA controller at $D000 – $DFFF.
				;.byte %00000000									; Command MSB

				.word $0000
*/

; ----------------------------------------------------------------------------------------------------------------------------------------

.align 256
redleftlo
		.repeat 200, I
			.byte <.loword((imgdata) + I*3*320 + 0*320)
		.endrepeat

.align 256
redleftmid
		.repeat 200, I
			.byte >.loword((imgdata) + I*3*320 + 0*320)
		.endrepeat

.align 256
redlefthi
		.repeat 200, I
			.byte <.hiword((imgdata) + I*3*320 + 0*320)
		.endrepeat

.align 256
greenleftlo
		.repeat 200, I
			.byte <.loword((imgdata) + I*3*320 + 1*320)
		.endrepeat

.align 256
greenleftmid
		.repeat 200, I
			.byte >.loword((imgdata) + I*3*320 + 1*320)
		.endrepeat

.align 256
greenlefthi
		.repeat 200, I
			.byte <.hiword((imgdata) + I*3*320 + 1*320)
		.endrepeat

.align 256
blueleftlo
		.repeat 200, I
			.byte <.loword((imgdata) + I*3*320 + 2*320)
		.endrepeat

.align 256
blueleftmid
		.repeat 200, I
			.byte >.loword((imgdata) + I*3*320 + 2*320)
		.endrepeat

.align 256
bluelefthi
		.repeat 200, I
			.byte <.hiword((imgdata) + I*3*320 + 2*320)
		.endrepeat





.align 256
redrightlo
		.repeat 200, I
			.byte <.loword((imgdata) + I*3*320 + 0*320 + 240)
		.endrepeat

.align 256
redrightmid
		.repeat 200, I
			.byte >.loword((imgdata) + I*3*320 + 0*320 + 240)
		.endrepeat

.align 256
redrighthi
		.repeat 200, I
			.byte <.hiword((imgdata) + I*3*320 + 0*320 + 240)
		.endrepeat

.align 256
greenrightlo
		.repeat 200, I
			.byte <.loword((imgdata) + I*3*320 + 1*320 + 240)
		.endrepeat

.align 256
greenrightmid
		.repeat 200, I
			.byte >.loword((imgdata) + I*3*320 + 1*320 + 240)
		.endrepeat

.align 256
greenrighthi
		.repeat 200, I
			.byte <.hiword((imgdata) + I*3*320 + 1*320 + 240)
		.endrepeat

.align 256
bluerightlo
		.repeat 200, I
			.byte <.loword((imgdata) + I*3*320 + 2*320 + 240)
		.endrepeat

.align 256
bluerightmid
		.repeat 200, I
			.byte >.loword((imgdata) + I*3*320 + 2*320 + 240)
		.endrepeat

.align 256
bluerighthi
		.repeat 200, I
			.byte <.hiword((imgdata) + I*3*320 + 2*320 + 240)
		.endrepeat
