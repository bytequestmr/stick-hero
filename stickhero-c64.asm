; Stick Hero for the Commodore 64
; 6502 port of the core rules in bytequestmr/stick-hero.
; Copyright (c) 2023 Richard S. Goshen Jr. (upstream project)
; Port implementation: MIT licensed; see README-c64.md.
; Assemble with ACME: acme stickhero-c64.asm

!to "stickhero-c64.prg",cbm

* = $0801
!word basic_end
!word 10
!byte $9e
!text "2061"
!byte 0
basic_end:
!word 0

* = $080d

STATE_WAIT = 0
STATE_GROW = 1
STATE_TURN = 2
STATE_WALK = 3
STATE_OVER = 4

MAX_STICK = 16
PLATFORM_Y = 21
HERO_Y = 20
screen_ptr = $fb
text_ptr = $fd

start:
    lda #$01
    sta $0286
    lda #$06
    sta $d020
    sta $d021
    jsr reset_game

main_loop:
    jsr wait_frame
    jsr read_fire
    lda state
    cmp #STATE_WAIT
    bne check_grow
    jsr update_wait
    jmp main_loop
check_grow:
    cmp #STATE_GROW
    bne check_turn
    jsr update_grow
    jmp main_loop
check_turn:
    cmp #STATE_TURN
    bne check_walk
    jsr update_turn
    jmp main_loop
check_walk:
    cmp #STATE_WALK
    bne update_over
    jsr update_walk
    jmp main_loop
update_over:
    jsr update_game_over
    jmp main_loop

reset_game:
    lda #0
    sta score
    jmp build_round

build_round:
    lda #$93
    jsr $ffd2
    lda #STATE_WAIT
    sta state
    lda #0
    sta stick_len
    sta turn_ticks
    lda #4
    sta base_x
    lda #8
    sta base_w
    lda #9
    sta hero_x
    lda #0
    sta retry_armed
    jsr generate_target
    jsr draw_title
    jsr draw_score
    jsr draw_scene
    rts

generate_target:
    jsr random_byte
    and #$07
    clc
    adc #5
    sta gap_size
    lda base_x
    clc
    adc base_w
    adc gap_size
    sta target_x
    jsr random_byte
    and #$07
    clc
    adc #4
    sta target_w
    rts

random_byte:
    lda random_seed
    asl
    bcc random_no_xor
    eor #$1d
random_no_xor:
    sta random_seed
    rts

read_fire:
    lda #0
    sta fire_pressed
    lda $dc00
    and #$10
    bne fire_done
    lda #1
    sta fire_pressed
fire_done:
    rts

wait_frame:
    lda $d012
    cmp #$f0
    bne wait_frame
wait_frame_end:
    lda $d012
    cmp #$f0
    beq wait_frame_end
    rts

update_wait:
    lda fire_pressed
    beq wait_done
    lda #STATE_GROW
    sta state
    jsr grow_stick
wait_done:
    rts

update_grow:
    lda fire_pressed
    beq begin_turn
    jsr grow_stick
    rts
begin_turn:
    lda #STATE_TURN
    sta state
    lda #0
    sta turn_ticks
    rts

grow_stick:
    lda stick_len
    cmp #MAX_STICK
    bcs grow_done
    inc stick_len
    jsr get_anchor
    lda #HERO_Y
    sec
    sbc stick_len
    sta draw_y
    lda anchor_x
    sta draw_x
    lda #$23
    jsr plot
grow_done:
    rts

update_turn:
    inc turn_ticks
    lda turn_ticks
    cmp #8
    bcc turn_done
    jsr resolve_stick
turn_done:
    rts

resolve_stick:
    jsr erase_vertical_stick
    jsr draw_horizontal_stick
    jsr get_anchor
    lda anchor_x
    clc
    adc stick_len
    sta stick_tip
    cmp target_x
    bcc stick_missed
    sec
    sbc target_x
    cmp target_w
    bcs stick_missed

    lda #1
    sta landed
    lda target_x
    clc
    adc #1
    sta move_target
    lda target_w
    lsr
    clc
    adc target_x
    cmp stick_tip
    bne ordinary_hit
    jsr add_point
    jsr add_point
    jmp start_walking
ordinary_hit:
    jsr add_point
    jmp start_walking

stick_missed:
    lda #0
    sta landed
    lda stick_tip
    clc
    adc #2
    sta move_target
start_walking:
    lda #STATE_WALK
    sta state
    rts

erase_vertical_stick:
    lda stick_len
    sta segment_count
erase_vertical_loop:
    lda segment_count
    beq erase_vertical_done
    lda #HERO_Y
    sec
    sbc segment_count
    sta draw_y
    jsr get_anchor
    lda anchor_x
    sta draw_x
    lda #$20
    jsr plot
    dec segment_count
    jmp erase_vertical_loop
erase_vertical_done:
    rts

draw_horizontal_stick:
    lda stick_len
    beq horizontal_done
    sta segment_count
    jsr get_anchor
    lda anchor_x
    clc
    adc #1
    sta draw_x
    lda #HERO_Y
    sta draw_y
horizontal_loop:
    lda #$2d
    jsr plot
    inc draw_x
    dec segment_count
    bne horizontal_loop
horizontal_done:
    rts

update_walk:
    lda hero_x
    cmp move_target
    bcs walk_arrived
    lda #$20
    sta draw_char
    lda hero_x
    sta draw_x
    lda #HERO_Y
    sta draw_y
    lda draw_char
    jsr plot
    inc hero_x
    jsr draw_hero
    rts

walk_arrived:
    lda landed
    beq show_game_over
    lda #4
    sta base_x
    lda #8
    sta base_w
    lda #9
    sta hero_x
    lda #0
    sta stick_len
    jsr generate_target
    jsr build_round_keep_score
    rts

build_round_keep_score:
    lda #$93
    jsr $ffd2
    lda #STATE_WAIT
    sta state
    jsr draw_title
    jsr draw_score
    jsr draw_scene
    rts

show_game_over:
    lda #STATE_OVER
    sta state
    lda #0
    sta retry_armed
    lda #4
    sta draw_y
    lda #7
    sta draw_x
    lda #<game_over_text
    sta text_ptr
    lda #>game_over_text
    sta text_ptr+1
    jsr draw_text
    rts

update_game_over:
    lda fire_pressed
    bne game_over_pressed
    lda #1
    sta retry_armed
    rts
game_over_pressed:
    lda retry_armed
    beq game_over_done
    jsr reset_game
game_over_done:
    rts

add_point:
    lda score
    cmp #255
    bcs add_point_done
    inc score
add_point_done:
    jsr draw_score
    rts

get_anchor:
    lda base_x
    clc
    adc base_w
    sec
    sbc #1
    sta anchor_x
    rts

draw_title:
    lda #0
    sta draw_y
    sta draw_x
    lda #<title_text
    sta text_ptr
    lda #>title_text
    sta text_ptr+1
    jsr draw_text
    lda #2
    sta draw_y
    lda #0
    sta draw_x
    lda #<controls_text
    sta text_ptr
    lda #>controls_text
    sta text_ptr+1
    jsr draw_text
    rts

draw_score:
    lda #1
    sta draw_y
    lda #0
    sta draw_x
    lda #<score_text
    sta text_ptr
    lda #>score_text
    sta text_ptr+1
    jsr draw_text

    lda score
    sta number_work
    lda #0
    sta hundreds
count_hundreds:
    lda number_work
    cmp #100
    bcc count_tens_start
    sec
    sbc #100
    sta number_work
    inc hundreds
    jmp count_hundreds
count_tens_start:
    lda #0
    sta tens
count_tens:
    lda number_work
    cmp #10
    bcc draw_digits
    sec
    sbc #10
    sta number_work
    inc tens
    jmp count_tens
draw_digits:
    lda #6
    sta draw_x
    lda hundreds
    clc
    adc #$30
    jsr plot
    inc draw_x
    lda tens
    clc
    adc #$30
    jsr plot
    inc draw_x
    lda number_work
    clc
    adc #$30
    jsr plot
    rts

draw_scene:
    lda #4
    sta draw_y
    lda #0
    sta draw_x
    lda #<blank_line
    sta text_ptr
    lda #>blank_line
    sta text_ptr+1
    jsr draw_text
    lda base_x
    sta platform_x
    lda base_w
    sta platform_w
    jsr draw_platform
    lda target_x
    sta platform_x
    lda target_w
    sta platform_w
    jsr draw_platform
    jsr draw_hero
    rts

draw_platform:
    lda #PLATFORM_Y
    sta draw_y
    ldx #4
platform_row:
    lda platform_x
    sta draw_x
    lda platform_w
    sta segment_count
platform_cell:
    lda #$3d
    jsr plot
    inc draw_x
    dec segment_count
    bne platform_cell
    inc draw_y
    dex
    bne platform_row
    rts

draw_hero:
    lda hero_x
    sta draw_x
    lda #HERO_Y
    sta draw_y
    lda #$00
    jsr plot
    rts

draw_text:
    ldy #0
draw_text_loop:
    lda (text_ptr),y
    beq draw_text_done
    sta plot_char
    sty text_index
    lda plot_char
    jsr plot
    inc draw_x
    ldy text_index
    iny
    bne draw_text_loop
draw_text_done:
    rts

plot:
    sta plot_char
    ldy draw_y
    lda row_lo,y
    sta screen_ptr
    lda row_hi,y
    sta screen_ptr+1
    ldy draw_x
    lda plot_char
    sta (screen_ptr),y
    rts

; Screen codes for the C64's default uppercase/graphics character set.
title_text:
    !byte 19,20,9,3,11,32,8,5,18,15,32,3,54,52,0
controls_text:
    !byte 16,50,32,6,9,18,5,32,8,15,12,4,32,20,15,32,7,18,15,23,0
score_text:
    !byte 19,3,15,18,5,0
game_over_text:
    !byte 7,1,13,5,32,15,22,5,18,32,45,32,6,9,18,5,32,20,15,32,18,5,20,18,25,0
blank_line:
    !byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    !byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,0

row_lo:
    !byte <$0400,<$0428,<$0450,<$0478,<$04a0
    !byte <$04c8,<$04f0,<$0518,<$0540,<$0568
    !byte <$0590,<$05b8,<$05e0,<$0608,<$0630
    !byte <$0658,<$0680,<$06a8,<$06d0,<$06f8
    !byte <$0720,<$0748,<$0770,<$0798,<$07c0
row_hi:
    !byte >$0400,>$0428,>$0450,>$0478,>$04a0
    !byte >$04c8,>$04f0,>$0518,>$0540,>$0568
    !byte >$0590,>$05b8,>$05e0,>$0608,>$0630
    !byte >$0658,>$0680,>$06a8,>$06d0,>$06f8
    !byte >$0720,>$0748,>$0770,>$0798,>$07c0

state:          !byte STATE_WAIT
retry_armed:    !byte 0
score:          !byte 0
base_x:         !byte 4
base_w:         !byte 8
target_x:       !byte 17
target_w:       !byte 6
hero_x:         !byte 9
stick_len:      !byte 0
turn_ticks:     !byte 0
landed:         !byte 0
move_target:    !byte 0
stick_tip:      !byte 0
anchor_x:       !byte 0
gap_size:       !byte 0
fire_pressed:   !byte 0
random_seed:    !byte $a5
platform_x:     !byte 0
platform_w:     !byte 0
segment_count:  !byte 0
draw_x:         !byte 0
draw_y:         !byte 0
draw_char:      !byte 0
plot_char:      !byte 0
text_index:     !byte 0
number_work:    !byte 0
hundreds:       !byte 0
tens:           !byte 0
