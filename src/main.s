; ----------------------------------------------------------------------------------------------------

.define sprptrs					$0800
.define uipal					$0900	; size = $0300
.define spritepal				$0c00

.define sprites					$1000
.define kbsprites				$1100

.define imgchars				$c000	; 40 * 64 = $0a00

.define screen					$8000	; size = 80*50*2 = $1f40
.define imgscreen				$a000	; size = 80*50*2 = $1f40

.define uichars					$10000	; $10000 - $14000     size = $4000
.define glchars					$14000	; $14000 - $1d000     size = $9000

.define imgdata					$20000  ; 320*200*3 = $2ee00

; ----------------------------------------------------------------------------------------------------

.segment "FONT"
		.incbin "../bin/font_chars1.bin"

.segment "GLYPHS"
		.incbin "../bin/glyphs_chars1.bin"

.segment "GLYPHSPAL"
		.incbin "../bin/glyphs_pal1.bin"

.segment "CURSORSPRITES"
		.incbin "../bin/cursor_sprites1.bin"

.segment "KBSPRITES"
		.incbin "../bin/kbcursor_sprites1.bin"

.segment "SPRITEPAL"
		.incbin "../bin/cursor_pal1.bin"

.segment "MAIN"

entry_main
main_restart

		sei

		lda #$35
		sta $01

		lda #%10000000									; Clear bit 7 - HOTREG
		trb $d05d

		lda #$00										; unmap
		tax
		tay
		taz
		map
		eom

		lda #$41										; enable 40MHz
		sta $00

		lda #$47										; enable C65GS/VIC-IV IO registers
		sta $d02f
		lda #$53
		sta $d02f
		eom

														; don't force anything. should work in both NTSC and PALs
		;lda #%10000000									; force PAL mode, because I can't be bothered with fixing it for NTSC
		;trb $d06f										; clear bit 7 for PAL ; trb $d06f 
		;tsb $d06f										; set bit 7 for NTSC  ; tsb $d06f

		lda #%11111000									; unmap c65 roms $d030 by clearing bits 3-7
		trb $d030
		lda #%00000100									; PAL - Use PALETTE ROM (0) or RAM (1) entries for colours 0 - 15
		tsb $d030

		lda #$05										; enable Super-Extended Attribute Mode by asserting the FCLRHI and CHR16 signals - set bits 2 and 0 of $D054.
		sta $d054

		lda #%10100000									; CLEAR bit7=40 column, bit5=Enable extended attributes and 8 bit colour entries
		trb $d031

		lda #80											; set to 80 for etherload
		sta $d05e

		lda #$02
		sta $d020
		lda #$10
		sta $d021

		jsr mouse_init									; initialise drivers
		jsr ui_init										; initialise UI
		jsr ui_setup

		jsr keyboard_update
		jsr mouse_update

		lda #<fa1filebox
		sta uikeyboard_focuselement+0
		lda #>fa1filebox
		sta uikeyboard_focuselement+1

		lda filebox1_stored_startpos+0
		sta fa1scrollbar_data+2
		lda filebox1_stored_startpos+1
		sta fa1scrollbar_data+3

		lda filebox1_stored_selection+0
		sta fa1scrollbar_data+4
		lda filebox1_stored_selection+1
		sta fa1scrollbar_data+5

		UICORE_CALLELEMENTFUNCTION fa1filebox, uifilebox_draw

		lda #$7f										; disable CIA interrupts
		sta $dc0d
		sta $dd0d
		lda $dc0d
		lda $dd0d

		lda #$00										; disable IRQ raster interrupts because C65 uses raster interrupts in the ROM
		sta $d01a
		sta main_event
		
		lda #$ff										; setup IRQ interrupt
		sta $d012
		lda #<irq1
		sta $fffe
		lda #>irq1
		sta $ffff

		lda #$01										; ACK
		sta $d01a

		cli
		
loop

		lda main_event
		cmp #$01
		beq load_image
		cmp #$03
		bne loop
		jmp main_restart

load_image
		jsr sdc_openfile

		jsr sdc_loadfile

		jsr sdc_closefile

		jsr img_rendinit

		lda #2
		sta main_event
		jmp loop

main_event
		.byte 0

; ----------------------------------------------------------------------------------------------------

irq1
		php
		pha
		phx
		phy
		phz

		jsr ui_update
		jsr ui_user_update

.if megabuild = 1
		lda #$ff
.else
		lda #$00
.endif
		sta $d012

		lda main_event
		cmp #$02
		beq set_img_render_irq
		bra continueirq

set_img_render_irq
		lda #<img_render_irq
		sta $fffe
		lda #>img_render_irq
		sta $ffff
		plz
		ply
		plx
		pla
		plp
		asl $d019
		rti

;		lda main_event
;		cmp #$01
;		beq set_img_load_irq
;		bra continueirq

;set_img_load_irq
;		lda #<img_load_irq
;		sta $fffe
;		lda #>img_load_irq
;		sta $ffff
;		plz
;		ply
;		plx
;		pla
;		plp
;		asl $d019
;		rti

continueirq
		lda #<irq1
		sta $fffe
		lda #>irq1
		sta $ffff
		plz
		ply
		plx
		pla
		plp
		asl $d019
		rti

; ----------------------------------------------------------------------------------------------------