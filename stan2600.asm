    processor 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;a;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Include required files with VCS register memory mapping and macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare the variables starting from memory address $80
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg.u Variables
    org $80

StanXPos         byte         ; player0 x-position
StanYPos         byte         ; player0 y-position
GuyXPos          byte         ; player1 x-position
GuyYPos          byte         ; player1 y-position
StanSpritePtr    word         ; pointer to player0 sprite lookup table
StanColorPtr     word         ; pointer to player0 color lookup table
GuySpritePtr     word         ; pointer to player1 sprite lookup table
GuyColorPtr      word         ; pointer to player1 sprite lookup table
StanAnimOffset   byte         ; player0 sprite animation frame offset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Define constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
STAN_HEIGHT = 9               ; player0 sprite height (# rows in lookup table)
GUY_HEIGHT = 9                ; player1 sprite height (# rows in lookup table)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start our ROM code at memory address $F000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg Code
    org $F000

Reset:
    CLEAN_START              ; call macro to reset memory and registers

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize RAM variables and TIA registers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #10
    sta StanYPos              ; StanYPos = 10
    lda #60
    sta StanXPos              ; StanXPos = 60
    lda #83
    sta GuyYPos               ; GuyYPos = 83
    lda #54
    sta GuyXPos               ; GuyXPos = 54

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize the pointers to the correct lookup table adresses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #<StanSprite
    sta StanSpritePtr         ; lo-byte pointer for Stan sprite lookup table
    lda #>StanSprite
    sta StanSpritePtr+1       ; hi-byte pointer for Stan sprite lookup table

    lda #<StanColor
    sta StanColorPtr          ; lo-byte pointer for Stan color lookup table
    lda #>StanColor
    sta StanColorPtr+1        ; hi-byte pointer for Stan color lookup table

    lda #<GuySprite
    sta GuySpritePtr      ; lo-byte pointer for Guy sprite lookup table
    lda #>GuySprite
    sta GuySpritePtr+1    ; hi-byte pointer for Guy sprite lookup table

    lda #<GuyColor
    sta GuyColorPtr       ; lo-byte pointer for Guy color lookup table
    lda #>GuyColor
    sta GuyColorPtr+1     ; hi-byte pointer for Guy color lookup table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start the main display loop and frame rendering
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StartFrame:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Calculations and tasks performed pre-VBLANK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda StanXPos
    ldy #0
    jsr SetObjectXPos        ; set player0 horizontal position

    lda GuyXPos
    ldy #1
    jsr SetObjectXPos        ; set player1 horizontal position

    sta WSYNC
    sta HMOVE                ; apply horizontal offsets previously set

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display VSYNC and VBLANK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK               ; turn on VBLANK
    sta VSYNC                ; turn on VSYNC
    REPEAT 3
        sta WSYNC            ; display 3 recommended lines of VSYNC
    REPEND
    lda #0
    sta VSYNC                ; turn off VSYNC
    REPEAT 37
        sta WSYNC            ; display the 37 recommended lines of VBLANK
    REPEND
    sta VBLANK               ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display Overscan
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK               ; turn on VBLANK again
    REPEAT 30
        sta WSYNC            ; display 30 recommended lines of VBlank Overscan
    REPEND
    lda #0
    sta VBLANK               ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display the 96 visible scanlines of our main game (because 2-line kernel)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameVisibleLine:

    ldx #96                  ; X counts the number of remaining scanlines
.GameLineLoop:
.AreWeInsideStanSprite:
    txa                      ; transfer X to A
    sec                      ; make sure carry flag is set before subtraction
    sbc StanYPos              ; subtract sprite Y-coordinate
    cmp STAN_HEIGHT           ; are we inside the sprite height bounds?
    bcc .DrawSpriteP0        ; if result < SpriteHeight, call the draw routine
    lda #0                   ; else, set lookup index to zero
.DrawSpriteP0:
    clc                      ; clears carry flag before addition
    adc StanAnimOffset        ; jump to correct sprite frame address in memory

    tay                      ; load Y so we can work with the pointer
    lda (StanSpritePtr),Y     ; load player0 bitmap data from lookup table
    sta WSYNC                ; wait for scanline
    sta GRP0                 ; set graphics for player0
    lda (StanColorPtr),Y      ; load player color from lookup table
    sta COLUP0               ; set color of player 0

.AreWeInsideGuySprite:
    txa                      ; transfer X to A
    sec                      ; make sure carry flag is set before subtraction
    sbc GuyYPos           ; subtract sprite Y-coordinate
    cmp GUY_HEIGHT        ; are we inside the sprite height bounds?
    bcc .DrawSpriteP1        ; if result < SpriteHeight, call the draw routine
    lda #0                   ; else, set lookup index to zero
.DrawSpriteP1:
    tay                      ; load Y so we can work with the pointer

    lda #%00000101
    sta NUSIZ1               ; stretch player 1 sprite

    lda (GuySpritePtr),Y  ; load player1 bitmap data from lookup table
    sta WSYNC                ; wait for scanline
    sta GRP1                 ; set graphics for player1
    lda (GuyColorPtr),Y   ; load player color from lookup table
    sta COLUP1               ; set color of player 1

    dex                      ; X--
    bne .GameLineLoop        ; repeat next main game scanline until finished

    lda #0
    sta StanAnimOffset        ; reset Stan animation frame to zero each frame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Process joystick input for player0 up/down/left/right
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckP0Up:
    lda #%00010000           ; player 0 joystick up
    bit SWCHA
    bne CheckP0Down          ; if bit pattern doesnt match, bypass P0Up block
    inc StanYPos              ; else, increment Stan y-position
    lda #0
    sta StanAnimOffset        ; and set Stan animation frame to zero

CheckP0Down:
    lda #%00100000           ; player 0 joystick up
    bit SWCHA
    bne CheckP0Left          ; if bit pattern doesnt match, bypass P0Down block
    dec StanYPos              ; else, decrement Stan y-position
    lda #0
    sta StanAnimOffset        ; and set Stan animation frame to zero

CheckP0Left:
    lda #%01000000           ; player 0 joystick left
    bit SWCHA
    bne CheckP0Right         ; if bit pattern doesnt match, bypass P0Left block
    dec StanXPos              ; else, increment Stan x-position
    lda STAN_HEIGHT
    sta StanAnimOffset        ; and set new offset to display second frame (+9)

CheckP0Right:
    lda #%10000000           ; player 0 joystick right
    bit SWCHA
    bne EndInputCheck        ; if bit pattern doesnt match, bypass P0Right block
    inc StanXPos              ; else, increment Stan x-position
    lda STAN_HEIGHT
    sta StanAnimOffset        ; and set new offset to display second frame (+9)

EndInputCheck:               ; fallback when no input was performed

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loop back to start a brand new frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp StartFrame           ; continue to display the next frame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to handle object horizontal position with fine offset
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A is the target x-coordinate position in pixels of our object
;; Y is the object type (0:player0, 1:player1, 2:missile0, 3:missile1, 4:ball)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetObjectXPos subroutine
    sta WSYNC                ; start a fresh new scanline
    sec                      ; make sure carry-flag is set before subtracion
.Div15Loop
    sbc #15                  ; subtract 15 from accumulator
    bcs .Div15Loop           ; loop until carry-flag is clear
    eor #7                   ; handle offset range from -8 to 7
    asl
    asl
    asl
    asl                      ; four shift lefts to get only the top 4 bits
    sta HMP0,Y               ; store the fine offset to the correct HMxx
    sta RESP0,Y              ; fix object position in 15-step increment
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare ROM lookup tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

StanSprite
  .byte #$00
  .byte #%00010100;$34
  .byte #%00010100;$70
  .byte #%00011100;$70
  .byte #%00011100;$0E
  .byte #%00101010;$0E
  .byte #%00111110;$0E
  .byte #%00001000;$3E
  .byte #%00011000;$00

StanSpriteRide
  .byte #$00
  .byte #%00010100;$34
  .byte #%00010100;$70
  .byte #%00011100;$70
  .byte #%00011100;$0E
  .byte #%00101010;$0E
  .byte #%00111110;$0E
  .byte #%00001000;$3E
  .byte #%00011000;$00

GuySprite
  .byte #$00
  .byte #%00010100;$34
  .byte #%00010100;$70
  .byte #%00011100;$70
  .byte #%00011100;$0E
  .byte #%00101010;$0E
  .byte #%00111110;$0E
  .byte #%00001000;$3E
  .byte #%00011000;$00

StanColor
  .byte #$00
  .byte #$34;
  .byte #$70;
  .byte #$70;
  .byte #$0E;
  .byte #$0E;
  .byte #$0E;
  .byte #$3E;
  .byte #$00;

StanColorRide
  .byte #$00
  .byte #$34;
  .byte #$70;
  .byte #$70;
  .byte #$0E;
  .byte #$0E;
  .byte #$0E;
  .byte #$3E;
  .byte #$00;

GuyColor
  .byte #$00
  .byte #$34;
  .byte #$70;
  .byte #$70;
  .byte #$0E;
  .byte #$0E;
  .byte #$0E;
  .byte #$3E;
  .byte #$00;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Complete ROM size with exactly 4KB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC                ; move to position $FFFC
    word Reset               ; write 2 bytes with the program reset address
    word Reset               ; write 2 bytes with the interruption vector
