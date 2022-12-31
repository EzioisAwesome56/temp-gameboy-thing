SECTION "Work RAM", WRAM0
	; variables to help us keep track of shit
wLCDDisabled: db
wCanDoVblank: db
wTileLoop: db
wTileSlot: db

SECTION "Stack", WRAM0
StackBottom: ds 49
StackTop: ds 1

DEF LCDC EQU $FF40
DEF VRAM_TILE EQU $8000
DEF INTERUPT_ENABLE EQU $FFFF

SECTION "VBlank interupt", ROM0[$0040]
	jp Do_VBlank

SECTION "Header", ROM0[$100]

	; This is your ROM's entry point
	; You have 4 bytes of code to do... something
	di
	jp EntryPoint

	; Make sure to allocate some space for the header, so no important
	; code gets put there and later overwritten by RGBFIX.
	; RGBFIX is designed to operate over a zero-filled header, so make
	; sure to put zeros regardless of the padding value. (This feature
	; was introduced in RGBDS 0.4.0, but the -MG etc flags were also
	; introduced in that version.)
	ds $150 - @, 0

SECTION "Entry point", ROM0

EntryPoint:
	; Here is where the fun begins, happy coding :)
	jp Dank


SECTION "Init code", ROMX
Dank:
	; reset the lcd disabled flag to 0
	; set a to 0
	xor a
	ld [wLCDDisabled], a
	; setup the stack pointer
	ld sp, StackTop
	; set the tile data area to $8000
	ld hl, LCDC
	set 4, [hl]
	; set tilemap area for background to 9800-9BFF
	res 3, [hl]
	; load the interupt thing into hl
	ld hl, INTERUPT_ENABLE
	set 0, [hl]
	; set a to one now
	inc a
	; tell vblank it can do the do
	ld [wCanDoVblank], a
	; enable interupts
	ei
	; wait for the LCD to be disabled
.waitloop
	; load our value into a
	ld a, [wLCDDisabled]
	cp 1
	; not set, keep waiting
	jr nz, .waitloop
	; if we are here, the LCD is DISABLED and we can now load some graphics into vram
	xor a
	ld [wTileSlot], a
	ld hl, e_graphic
	call loadtile
	; load the a tile into slot 2 of vram
	inc a
	ld [wTileSlot], a
	ld hl, a_graphic
	call loadtile
	; set the first tile in the tilemap to 0
	ld hl, $9800
	xor a
	ld [hl], a
	; enable the LCD
	ld hl, LCDC
	set 7, [hl]
	; commit stop
.dank
	jr .dank


SECTION "VBlank hanlder", ROMX 
Do_VBlank:
	push af
	push hl
	; check to see if we can disable the LCD
	ld a, [wCanDoVblank]
	cp 1
	; if no, exit
	jr nz, .end
	; else, disable the LCD and PPU
	ld hl, LCDC
	res 7, [hl]
	; clear tilemap
	call clear_tilemap
	; inform code that the LCD is turned off
	; set a to 1
	ld a, 1
	; load it to our value
	ld [wLCDDisabled], a
	; reset the flag that we can do vblank
	xor a
	ld [wCanDoVblank], a
.end
	; return from the interupt call
	pop hl
	pop af
	reti

SECTION "Helpful routines", ROMX
; clear tilemap
clear_tilemap:
	; backup values
	push af
	push bc
	push hl
	; load 9800 into hl
	ld hl, $9800
.loop
	; test if l is FF
	ld a, l
	cp $FF
	jr z, .check
.resume
	; if its not, write a zero into memory at hl
	xor a
	ld [hl], a
	; inc hl
	inc hl
	; loop
	jr .loop
.check
	; is h 9b?
	ld a, h
	cp $9B
	; if yes, return
	jr z, .exit
	; else, go back to the loop
	jr .resume
.exit
	pop hl
	pop bc
	pop af
	ret

gettileaddress:
	; set bc to 16
	xor a
	ld b, a
	ld a, 16
	ld c, a
	; reset the loop
	xor a
	ld [wTileLoop], a
.loop
	; backup hl
	push hl
	; load the tile slot into hl
	ld hl, wTileSlot
	; load the total loop count into a
	ld a, [wTileLoop]
	; are they equal?
	cp [hl]
	jr z, .exit
	; if not, retore hl to what it was before
	pop hl
	; add bc to hl
	add hl, bc
	; load current loop count
	ld a, [wTileLoop]
	; increment
	inc a
	ld [wTileLoop], a
	jr .loop
.exit
	; pop hl off the stack
	pop hl
	; return
	ret


; load a single tile at HL into VRAM
loadtile:
	; backup various things
	push de
	push bc
	push af
	; move HL to DE
	push hl
	pop de
	; load vram start to hl
	ld hl, VRAM_TILE
	; load the current slot index
	ld a, [wTileSlot]
	; is it not 0?
	cp 0
	call nz, gettileaddress
	; set bc to 1
	xor b
	ld a, $1
	ld c, a
	; set our counter to 0
	xor a
	ld [wTileLoop], a
.loop
	; have we loaded all 16 bytes?
	ld a, [wTileLoop]
	cp 16
	; if yes, end
	jr z, .end
	; otherwise, load tile into vram
	ld a, [de]
	ld [hl], a
	; add one to hl
	add hl, bc
	; backup hl
	push hl
	; move de to hl
	push de
	pop hl
	; add one to the DE value in hl
	add hl, bc
	; move everything back
	push hl
	pop de
	pop hl
	; inc our flag
	ld a, [wTileLoop]
	inc a
	ld [wTileLoop], a
	; jump to loop
	jr .loop
.end
	; pop everything off the stack
	pop af
	pop bc
	pop de
	ret


SECTION "Graphics", ROMX
e_graphic: INCBIN "res/e.2bpp"
a_graphic: INCBIN "res/a.2bpp"