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

MAX_STICK = 128
STICK_SEGMENT = 42
HORIZONTAL_SEGMENT = 48
CHERRY_BONUS = 5
PLATFORM_Y = 21
HERO_Y = 20
STICK_VERTICAL = $85
STICK_HORIZONTAL = $86
GRASS_TOP = $87
STONE_A = $88
STONE_B = $89
HILL_FILL = $8a
HILL_LEFT = $8b
HILL_RIGHT = $8c
TREE_LEAVES = $8d
TREE_TRUNK = $8e
CLOUD_TILE = $8f
CLOUD_TOP_LEFT = $9e
CLOUD_TOP_MIDDLE = $9f
CLOUD_TOP_RIGHT = $a0
CLOUD_BOTTOM_LEFT = $a1
CLOUD_BOTTOM_MIDDLE = $a2
CLOUD_BOTTOM_RIGHT = $a3
TREE_TOP = $a4
screen_ptr = $02
text_ptr = $04
color_ptr = $06

start:
    ; The KERNAL IRQ handler reuses the zero-page scratch used by our pointers.
    sei
    ; KERNAL keyboard scanning can leave CIA1 Port A configured as outputs.
    ; Joystick port 2 uses its lower five input lines.
    lda $dc02
    and #$e0
    sta $dc02
    lda $dc00
    ora #$1f
    sta $dc00
    lda #$06
    sta $d020
    lda #$03
    sta $d021
    jsr setup_graphics
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
    sta fire_lockout
    lda #1
    sta plot_color
    jsr generate_target
    jsr hide_stick_sprites
    jsr draw_title
    jsr draw_score
    jsr draw_scene
    jsr spawn_cherry
    rts

spawn_cherry:
    lda #0
    sta cherry_active
    lda $d015
    and #$df
    sta $d015
    jsr random_byte
    and #$03
    bne cherry_spawn_done
    jsr random_byte
    and #$03
    clc
    adc #3
    adc hero_x
    sta cherry_x
    asl
    asl
    asl
    clc
    adc #2
    sta $d00a
    lda #197
    sta $d00b
    lda $d010
    and #$df
    sta $d010
    lda $d015
    ora #$20
    sta $d015
    lda #1
    sta cherry_active
cherry_spawn_done:
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

setup_graphics:
    jsr copy_character_rom
    jsr install_graphics_tiles
    lda #$18
    sta $d018
    lda #1
    sta $d015
    lda #$21
    sta $d01c
    lda #0
    sta $d01b
    lda #$1e
    sta $d017
    lda #0
    sta $d01d
    lda #$01
    sta $d025
    lda #$02
    sta $d026
    lda #$00
    sta $d027
    lda #$05
    sta $d02c
    lda #$a0
    sta $07f8
    lda #$a1
    sta $07f9
    lda #$a2
    sta $07fa
    lda #$a3
    sta $07fb
    lda #$a4
    sta $07fc
    lda #$a5
    sta $07fd
    lda #$01
    sta $d028
    sta $d029
    sta $d02a
    sta $d02b
    lda #$08
    sta $d405
    sta $d40c
    lda #$a4
    sta $d406
    sta $d40d
    lda #$10
    sta $d404
    sta $d40b
    lda #$0f
    sta $d418
    rts

copy_character_rom:
    lda $01
    sta saved_port
    and #$fb
    sta $01
    lda #<$d000
    sta text_ptr
    lda #>$d000
    sta text_ptr+1
    lda #<$2000
    sta screen_ptr
    lda #>$2000
    sta screen_ptr+1
    ldy #0
copy_charset_page:
    lda (text_ptr),y
    sta (screen_ptr),y
    iny
    bne copy_charset_page
    inc text_ptr+1
    inc screen_ptr+1
    lda text_ptr+1
    cmp #$d8
    bne copy_charset_page
    lda saved_port
    sta $01
    rts

install_graphics_tiles:
    lda #<graphics_tiles
    sta text_ptr
    lda #>graphics_tiles
    sta text_ptr+1
    lda #<$2428
    sta screen_ptr
    lda #>$2428
    sta screen_ptr+1
    lda #<(graphics_tiles_end-graphics_tiles)
    sta tile_bytes_left
    lda #>(graphics_tiles_end-graphics_tiles)
    sta tile_bytes_left+1
copy_tile_bytes:
    ldy #0
    lda (text_ptr),y
    sta (screen_ptr),y
    inc text_ptr
    bne tile_source_ready
    inc text_ptr+1
tile_source_ready:
    inc screen_ptr
    bne tile_destination_ready
    inc screen_ptr+1
tile_destination_ready:
    lda tile_bytes_left
    bne tile_count_low
    dec tile_bytes_left+1
tile_count_low:
    dec tile_bytes_left
    lda tile_bytes_left
    ora tile_bytes_left+1
    bne copy_tile_bytes
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
    lda fire_lockout
    beq wait_check_fire
    lda fire_pressed
    bne wait_done
    lda #0
    sta fire_lockout
    rts
wait_check_fire:
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
    lda #$10
    sta $d404
    rts

grow_stick:
    lda stick_len
    cmp #MAX_STICK
    bcs grow_done
    clc
    adc #2
    sta stick_len
    jsr draw_vertical_stick_sprites
    jsr sound_grow
grow_done:
    rts

sound_grow:
    lda #0
    sta $d400
    lda #$20
    sta $d401
    lda #$21
    sta $d404
    rts

hide_stick_sprites:
    lda $d015
    and #$e1
    sta $d015
    rts

draw_vertical_stick_sprites:
    lda #$1e
    sta $d017
    lda #0
    sta $d01d
    lda #<vertical_sprite_pointers
    sta text_ptr
    lda #>vertical_sprite_pointers
    sta text_ptr+1
    ldy #0
    ldx #4
set_vertical_sprite_pointers:
    lda (text_ptr),y
    sta $07f9,y
    iny
    dex
    bne set_vertical_sprite_pointers

    lda $d015
    and #$e1
    sta $d015
    lda stick_len
    bne vertical_stick_nonzero
    jmp vertical_sprites_done

vertical_stick_nonzero:
    sta top_segment_len
vertical_find_top_segment:
    lda top_segment_len
    cmp #STICK_SEGMENT+1
    bcc vertical_top_segment_ready
    sec
    sbc #STICK_SEGMENT
    sta top_segment_len
    jmp vertical_find_top_segment
vertical_top_segment_ready:
    lda stick_len
    sec
    sbc top_segment_len
    sta remaining_len
    lda #218
    sec
    sbc stick_len
    sta sprite_y_work
    sta $d003

    lda #<vertical_sprite_partial
    sta text_ptr
    lda #>vertical_sprite_partial
    sta text_ptr+1
    lda top_segment_len
    lsr
    sta segment_count
    ldy #1
    ldx #21
vertical_partial_bitmap:
    lda segment_count
    beq vertical_partial_clear
    dec segment_count
    lda #$08
    bne vertical_partial_write
vertical_partial_clear:
    lda #0
vertical_partial_write:
    sta (text_ptr),y
vertical_partial_advance:
    tya
    clc
    adc #3
    tay
    dex
    bne vertical_partial_bitmap

    lda $d015
    ora #$02
    sta $d015
    lda #$04
    sta sprite_enable_mask
    lda remaining_len
    beq vertical_sprites_done
    lda sprite_y_work
    clc
    adc top_segment_len
    sta sprite_y_work
    ldx #5
vertical_full_segment:
    lda remaining_len
    beq vertical_sprites_done
    lda sprite_y_work
    sta $d000,x
    lda $d015
    ora sprite_enable_mask
    sta $d015
    lda remaining_len
    sec
    sbc #STICK_SEGMENT
    sta remaining_len
    lda sprite_y_work
    clc
    adc #STICK_SEGMENT
    sta sprite_y_work
    cpx #9
    beq vertical_sprites_done
    asl sprite_enable_mask
    inx
    inx
    cpx #11
    bcc vertical_full_segment
vertical_sprites_done:
    jsr get_anchor
    lda anchor_x
    asl
    asl
    asl
    sec
    sbc #8
    sta $d002
    sta $d004
    sta $d006
    sta $d008
    lda $d010
    and #$e1
    sta $d010
    lda #0
    sta $d01d
    lda #$1e
    sta $d017
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
    jsr draw_horizontal_stick_sprites
    jsr get_anchor
    lda anchor_x
    clc
    adc #0
    sta stick_tip
    lda stick_len
    clc
    adc #6
    lsr
    lsr
    lsr
    clc
    adc stick_tip
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

draw_horizontal_stick_sprites:
    lda #0
    sta $d017
    lda #$1e
    sta $d01d
    lda #$a3
    sta $07f9
    lda #$a3
    sta $07fa
    lda #$a3
    sta $07fb
    lda #$a4
    sta $07fc
    lda #198
    sta $d003
    sta $d005
    sta $d007
    sta $d009
    lda $d015
    and #$e1
    sta $d015
    lda #0
    sta full_segments
    lda stick_len
    sec
    sbc #1
horizontal_count_full:
    cmp #HORIZONTAL_SEGMENT
    bcc horizontal_segment_ready
    sec
    sbc #HORIZONTAL_SEGMENT
    inc full_segments
    jmp horizontal_count_full
horizontal_segment_ready:
    clc
    adc #1
    sta segment_len
    jsr get_anchor
    lda anchor_x
    asl
    asl
    asl
    clc
    adc #7
    sta sprite_x_work
    lda #$02
    sta sprite_mask_work
    ldx #2
horizontal_full_segments:
    lda full_segments
    beq horizontal_partial_segment
    dec full_segments
    lda sprite_x_work
    sta $d000,x
    lda $d015
    ora sprite_mask_work
    sta $d015
    lda sprite_mask_work
    asl
    sta sprite_mask_work
    lda sprite_x_work
    clc
    adc #HORIZONTAL_SEGMENT
    sta sprite_x_work
    inx
    inx
    jmp horizontal_full_segments
horizontal_partial_segment:
    lda sprite_x_work
    sta $d008
    lda $d015
    ora #$10
    sta $d015
    lda segment_len
    lsr
    sta remaining_len
    lda #<horizontal_run_masks
    sta text_ptr
    lda #>horizontal_run_masks
    sta text_ptr+1
    lda #<$293c
    sta screen_ptr
    lda #>$293c
    sta screen_ptr+1
    ldy #0
horizontal_mask_byte:
    lda remaining_len
    cmp #9
    bcs horizontal_mask_full_byte
    tax
    lda horizontal_run_masks,x
    sta mask_work
    lda #0
    sta remaining_len
    lda mask_work
    jmp horizontal_mask_store
horizontal_mask_full_byte:
    sec
    sbc #8
    sta remaining_len
    lda #$ff
horizontal_mask_store:
    sta (screen_ptr),y
    inc screen_ptr
    iny
    cpy #3
    bcc horizontal_mask_byte
    lda $d010
    and #$e1
    sta $d010
    rts

update_walk:
    lda hero_x
    cmp move_target
    bcs walk_arrived
    inc hero_x
    jsr draw_hero
    jsr collect_cherry
    rts

collect_cherry:
    lda cherry_active
    beq cherry_collect_done
    lda hero_x
    cmp cherry_x
    bcc cherry_collect_done
    lda #0
    sta cherry_active
    lda $d015
    and #$df
    sta $d015
    lda #CHERRY_BONUS
    sta cherry_bonus_count
cherry_bonus_loop:
    jsr add_point
    dec cherry_bonus_count
    bne cherry_bonus_loop
cherry_collect_done:
    rts

walk_arrived:
    lda landed
    beq show_game_over
    jsr sound_crossing
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
    lda #0
    sta stick_len
    sta turn_ticks
    jsr draw_title
    jsr draw_score
    jsr draw_scene
    jsr spawn_cherry
    jsr hide_stick_sprites
    rts

sound_crossing:
    lda #0
    sta $d407
    lda #$24
    sta $d408
    lda #$11
    sta $d40b
    ldx #4
crossing_note_one:
    jsr wait_frame
    dex
    bne crossing_note_one
    lda #$20
    sta $d40b
    ldx #2
crossing_note_gap:
    jsr wait_frame
    dex
    bne crossing_note_gap
    lda #$2c
    sta $d408
    lda #$11
    sta $d40b
    ldx #5
crossing_note_two:
    jsr wait_frame
    dex
    bne crossing_note_two
    lda #$20
    sta $d40b
    rts

show_game_over:
    lda #STATE_OVER
    sta state
    lda $d015
    and #$df
    sta $d015
    lda $d015
    and #$df
    sta $d015
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
    lda #1
    sta fire_lockout
game_over_done:
    rts

add_point:
    lda score
    cmp #255
    bcs add_point_done
    inc score
    lda score
    cmp high_score
    bcc add_point_done
    sta high_score
add_point_done:
    jsr draw_score
    rts

get_anchor:
    lda base_x
    clc
    adc base_w
    clc
    adc #1
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

    lda #1
    sta draw_y
    lda #11
    sta draw_x
    lda #<best_text
    sta text_ptr
    lda #>best_text
    sta text_ptr+1
    jsr draw_text

    lda high_score
    sta number_work
    lda #0
    sta hundreds
count_best_hundreds:
    lda number_work
    cmp #100
    bcc count_best_tens_start
    sec
    sbc #100
    sta number_work
    inc hundreds
    jmp count_best_hundreds
count_best_tens_start:
    lda #0
    sta tens
count_best_tens:
    lda number_work
    cmp #10
    bcc draw_best_digits
    sec
    sbc #10
    sta number_work
    inc tens
    jmp count_best_tens
draw_best_digits:
    lda #16
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
    jsr draw_hills
    jsr draw_clouds
    jsr draw_trees
    lda #1
    sta plot_color
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

draw_hills:
    lda #0
    sta text_index
    ldx #hill_row_count
draw_hill_loop:
    ldy text_index
    lda hill_rows,y
    sta draw_y
    iny
    lda hill_rows,y
    sta draw_x
    iny
    lda hill_rows,y
    sta segment_count
    iny
    lda hill_rows,y
    sta draw_char
    iny
    lda hill_rows,y
    sta plot_color
    iny
    lda hill_rows,y
    sta hill_side_x
    iny
    lda hill_rows,y
    sta hill_side_char
    iny
    sty text_index
    jsr fill_hill_segment
    lda hill_side_x
    sta draw_x
    lda hill_side_char
    jsr plot
    dex
    bne draw_hill_loop
    rts

fill_hill_segment:
    lda draw_x
    sta hill_start_x
hill_fill_loop:
    lda draw_char
    jsr plot
    inc draw_x
    dec segment_count
    bne hill_fill_loop
    lda hill_start_x
    sta draw_x
    rts

draw_clouds:
    lda #<cloud_tiles
    sta text_ptr
    lda #>cloud_tiles
    sta text_ptr+1
    lda #cloud_tile_count
    sta decoration_count
    jmp draw_decoration_tiles

draw_trees:
    lda #<tree_tiles
    sta text_ptr
    lda #>tree_tiles
    sta text_ptr+1
    lda #tree_tile_count
    sta decoration_count

draw_decoration_tiles:
    lda #0
    sta text_index
    ldx decoration_count
draw_decoration_loop:
    ldy text_index
    lda (text_ptr),y
    sta draw_x
    iny
    lda (text_ptr),y
    sta draw_y
    iny
    lda (text_ptr),y
    sta draw_char
    iny
    lda (text_ptr),y
    sta plot_color
    iny
    sty text_index
    lda draw_char
    jsr plot
    dex
    bne draw_decoration_loop
    lda #1
    sta plot_color
    rts

draw_platform:
    lda #PLATFORM_Y
    sta draw_y
    lda #GRASS_TOP
    sta draw_char
    lda #5
    sta plot_color
    jsr draw_platform_row
    inc draw_y
    lda #9
    sta plot_color
    ldx #3
platform_row:
    txa
    and #1
    beq platform_stone_a
    lda #STONE_B
    bne platform_stone_ready
platform_stone_a:
    lda #STONE_A
platform_stone_ready:
    sta draw_char
    jsr draw_platform_row
    inc draw_y
    dex
    bne platform_row
    lda #1
    sta plot_color
    rts

draw_platform_row:
    lda platform_x
    sta draw_x
    lda platform_w
    sta segment_count
platform_cell:
    lda draw_char
    jsr plot
    inc draw_x
    dec segment_count
    bne platform_cell
    rts

draw_hero:
    lda #0
    sta hero_x_high
    lda hero_x
    asl
    rol hero_x_high
    asl
    rol hero_x_high
    asl
    rol hero_x_high
    clc
    adc #12
    bcc hero_x_ready
    inc hero_x_high
hero_x_ready:
    sta $d000
    lda $d010
    and #$fe
    ora hero_x_high
    sta $d010
    lda #(50+((HERO_Y+1)*8)-21)
    sta $d001
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
    lda screen_ptr
    sta color_ptr
    lda screen_ptr+1
    clc
    adc #$d4
    sta color_ptr+1
    ldy draw_x
    lda plot_color
    sta (color_ptr),y
    rts

; Screen codes in the copied C64 character ROM remain available for the HUD.
title_text:
    !byte 19,20,9,3,11,32,8,5,18,15,32,3,54,52,0
controls_text:
    !byte 16,50,32,6,9,18,5,32,8,15,12,4,32,20,15,32,7,18,15,23,0
score_text:
    !byte 19,3,15,18,5,0
best_text:
    !byte 2,5,19,20,0
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

hill_row_count = (hill_rows_end-hill_rows)/7
hill_rows:
    !byte 11,0,3,HILL_FILL,13,2,HILL_RIGHT
    !byte 12,0,4,HILL_FILL,13,3,HILL_RIGHT
    !byte 13,0,6,HILL_FILL,13,5,HILL_RIGHT
    !byte 14,0,9,HILL_FILL,13,8,HILL_RIGHT
    !byte 15,0,13,HILL_FILL,13,12,HILL_RIGHT
    !byte 16,0,16,HILL_FILL,5,15,HILL_RIGHT
    !byte 17,0,18,HILL_FILL,5,17,HILL_RIGHT
    !byte 18,0,20,HILL_FILL,5,19,HILL_RIGHT
    !byte 19,0,22,HILL_FILL,5,21,HILL_RIGHT
    !byte 11,37,3,HILL_FILL,13,37,HILL_LEFT
    !byte 12,36,4,HILL_FILL,13,36,HILL_LEFT
    !byte 13,34,6,HILL_FILL,13,34,HILL_LEFT
    !byte 14,31,9,HILL_FILL,13,31,HILL_LEFT
    !byte 15,27,13,HILL_FILL,13,27,HILL_LEFT
    !byte 16,24,16,HILL_FILL,5,24,HILL_LEFT
    !byte 17,22,18,HILL_FILL,5,22,HILL_LEFT
    !byte 18,20,20,HILL_FILL,5,20,HILL_LEFT
    !byte 19,18,22,HILL_FILL,5,18,HILL_LEFT
hill_rows_end:

cloud_tile_count = (cloud_tiles_end-cloud_tiles)/4
cloud_tiles:
    !byte 5,5,CLOUD_TOP_LEFT,1
    !byte 6,5,CLOUD_TOP_MIDDLE,1
    !byte 7,5,CLOUD_TOP_RIGHT,1
    !byte 5,6,CLOUD_BOTTOM_LEFT,1
    !byte 6,6,CLOUD_BOTTOM_MIDDLE,1
    !byte 7,6,CLOUD_BOTTOM_RIGHT,1
    !byte 23,7,CLOUD_TOP_LEFT,1
    !byte 24,7,CLOUD_TOP_MIDDLE,1
    !byte 25,7,CLOUD_TOP_RIGHT,1
    !byte 23,8,CLOUD_BOTTOM_LEFT,1
    !byte 24,8,CLOUD_BOTTOM_MIDDLE,1
    !byte 25,8,CLOUD_BOTTOM_RIGHT,1
cloud_tiles_end:

tree_tile_count = (tree_tiles_end-tree_tiles)/4
tree_tiles:
    !byte 2,15,TREE_LEAVES,5
    !byte 3,15,TREE_LEAVES,5
    !byte 4,15,TREE_LEAVES,5
    !byte 5,15,TREE_LEAVES,5
    !byte 6,15,TREE_LEAVES,5
    !byte 3,14,TREE_LEAVES,13
    !byte 4,14,TREE_LEAVES,13
    !byte 5,14,TREE_LEAVES,13
    !byte 4,13,TREE_TOP,13
    !byte 30,15,TREE_LEAVES,5
    !byte 31,15,TREE_LEAVES,5
    !byte 32,15,TREE_LEAVES,5
    !byte 33,15,TREE_LEAVES,5
    !byte 34,15,TREE_LEAVES,5
    !byte 31,14,TREE_LEAVES,13
    !byte 32,14,TREE_LEAVES,13
    !byte 33,14,TREE_LEAVES,13
    !byte 32,13,TREE_TOP,13
    !byte 4,16,TREE_TRUNK,9
    !byte 4,17,TREE_TRUNK,9
    !byte 4,18,TREE_TRUNK,9
    !byte 32,16,TREE_TRUNK,9
    !byte 32,17,TREE_TRUNK,9
    !byte 32,18,TREE_TRUNK,9
tree_tiles_end:

graphics_tiles:
    ; One-pixel stick glyphs, platform grass and rocky soil.
    !byte $10,$10,$10,$10,$10,$10,$10,$10
    !byte $00,$00,$00,$ff,$00,$00,$00,$00
    !byte $18,$3c,$18,$7e,$ff,$db,$ff,$7e
    !byte $ff,$aa,$d5,$ff,$aa,$55,$ff,$7e
    !byte $ff,$81,$bd,$a5,$bd,$81,$ff,$7e
    ; Speckled hill fill and softened pixel-curved slope edges.
    !byte $aa,$55,$aa,$55,$ff,$55,$aa,$ff
    !byte $00,$00,$01,$03,$07,$1f,$7f,$ff
    !byte $00,$00,$80,$c0,$e0,$f8,$fe,$ff
    ; Leaf, trunk, and cloud tiles.
    !byte $18,$3c,$7e,$ff,$db,$ff,$7e,$3c
    !byte $18,$18,$18,$18,$18,$3c,$3c,$3c
    !byte $00,$00,$18,$3c,$7e,$ff,$ff,$7e
    ; Partial one-pixel-wide stick tips, one through seven pixels tall.
    !byte $00,$00,$00,$00,$00,$00,$00,$10
    !byte $00,$00,$00,$00,$00,$00,$10,$10
    !byte $00,$00,$00,$00,$00,$10,$10,$10
    !byte $00,$00,$00,$00,$10,$10,$10,$10
    !byte $00,$00,$00,$10,$10,$10,$10,$10
    !byte $00,$00,$10,$10,$10,$10,$10,$10
    !byte $00,$10,$10,$10,$10,$10,$10,$10
    ; Partial horizontal stick tips, one through seven pixels long.
    !byte $00,$00,$00,$80,$00,$00,$00,$00
    !byte $00,$00,$00,$c0,$00,$00,$00,$00
    !byte $00,$00,$00,$e0,$00,$00,$00,$00
    !byte $00,$00,$00,$f0,$00,$00,$00,$00
    !byte $00,$00,$00,$f8,$00,$00,$00,$00
    !byte $00,$00,$00,$fc,$00,$00,$00,$00
    !byte $00,$00,$00,$fe,$00,$00,$00,$00
    ; Six contiguous pixel tiles form soft, rounded cloud silhouettes.
    !byte $00,$00,$00,$00,$00,$00,$03,$0f
    !byte $00,$00,$18,$3c,$7e,$7e,$ff,$ff
    !byte $00,$00,$00,$00,$00,$00,$c0,$f0
    !byte $0f,$3f,$7f,$ff,$ff,$ff,$ff,$7e
    !byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$7e
    !byte $f0,$fc,$fe,$ff,$ff,$ff,$ff,$7e
    ; A rounded crown for the distant trees.
    !byte $00,$00,$18,$3c,$7e,$ff,$ff,$ff
graphics_tiles_end:

vertical_sprite_pointers:
    !byte $a1,$a2,$a2,$a2
horizontal_run_masks:
    !byte $00,$80,$c0,$e0,$f0,$f8,$fc,$fe,$ff

state:          !byte STATE_WAIT
retry_armed:    !byte 0
fire_lockout:   !byte 0
saved_port:     !byte 0
score:          !byte 0
high_score:     !byte 0
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
plot_color:     !byte 1
hero_x_high:    !byte 0
hill_side_x:    !byte 0
hill_side_char: !byte 0
hill_start_x:   !byte 0
decoration_count: !byte 0
tile_bytes_left: !word 0
top_segment_len: !byte 0
remaining_len: !byte 0
segment_len: !byte 0
full_segments: !byte 0
sprite_y_work: !byte 0
sprite_enable_mask: !byte 0
sprite_x_work: !byte 0
sprite_mask_work: !byte 0
mask_work: !byte 0
cherry_active: !byte 0
cherry_x: !byte 0
cherry_bonus_count: !byte 0

* = $2800
hero_sprite:
    !byte $00,$28,$a8
    !byte $00,$2a,$a8
    !byte $00,$25,$68
    !byte $00,$2f,$f8
    !byte $00,$09,$68
    !byte $00,$02,$50
    !byte $00,$2a,$a8
    !byte $00,$2b,$fa
    !byte $00,$18,$90
    !byte $00,$18,$90
    !byte $00,$0a,$a8
    !byte $00,$0a,$a8
    !byte $00,$0b,$f8
    !byte $00,$28,$28
    !byte $00,$28,$28
    !byte $00,$28,$28
    !byte $00,$28,$28
    !byte $00,$28,$28
    !byte $00,$28,$28
    !byte $00,$28,$28
    !byte $00,$28,$28
    !byte 0

* = $2840
vertical_sprite_partial:
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte 0

* = $2880
vertical_sprite_full:
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte $00,$08,$00
    !byte 0

* = $28c0
horizontal_sprite_full:
    !fill 60,0
    !byte $ff,$ff,$ff
    !byte 0

* = $2900
horizontal_sprite_partial:
    !fill 64,0

* = $2940
cherry_sprite:
    !byte 0,0,0
    !byte 0,0,$30
    !byte 0,0,$30
    !byte 0,$0c,$30
    !byte 0,$2a,$00
    !byte 0,$aa,$80
    !byte 1,$aa,$c0
    !byte 2,$aa,$a0
    !byte 2,$aa,$a0
    !byte 1,$aa,$c0
    !byte 0,$aa,$80
    !byte 0,$2a,$00
    !byte 0,$00,$00
    !byte 0,$00,$00
    !byte 0,$00,$00
    !byte 0,$00,$00
    !byte 0,$00,$00
    !byte 0,$00,$00
    !byte 0,$00,$00
    !byte 0,$00,$00
    !byte 0,$00,$00
    !byte 0
