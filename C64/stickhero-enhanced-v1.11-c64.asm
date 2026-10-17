; Stick Hero Enhanced V1.11 for the Commodore 64
; 6502 port of the core rules in bytequestmr/stick-hero.
; Copyright (c) 2023 Richard S. Goshen Jr. (upstream project)
; Port implementation: MIT licensed; see README-c64.md.
; Assemble with ACME: acme stickhero-enhanced-v1.11-c64.asm

!to "stickhero-enhanced-v1.11-c64.prg",cbm

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
HORIZONTAL_STRIDE = HORIZONTAL_SEGMENT-1
CHERRY_BONUS = 5
CHERRY_Y = 222
PLATFORM_Y = 21
HERO_Y = 20
HERO_UNDER_OFFSET = 24
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
CITY_BLOCK = $a5
CITY_WINDOW = $a6
SAND_TILE = $a7
SEA_TILE = $a8
SEA_WAVE = $a9
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
    jsr update_cloud_motion
    jsr update_bird_motion
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
    sta cherry_count
    sta scene_round_count
    sta scene_type
    sta difficulty_active
    sta bird_active
    sta bird_frame
    lda #90
    sta bird_spawn_delay
    lda #0
    sta walk_step_ticks
    sta walk_note_index
    sta cherry_sound_ticks
    sta hero_subpixel
    sta hero_under_stick
    sta walk_fire_armed
    jmp build_round

build_round:
    lda #$93
    jsr $ffd2
    lda #$21
    sta $d01c
    lda #$a0
    sta $07f8
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    sta $d418
    lda #$06
    sta $d020
    lda #$03
    sta $d021
    lda #STATE_WAIT
    sta state
    lda #0
    sta stick_len
    sta turn_ticks
    sta walk_step_ticks
    sta cherry_sound_ticks
    sta place_sound_ticks
    sta hero_subpixel
    jsr hide_cherry
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
    rts

spawn_cherry:
    jsr hide_cherry
    jsr random_byte
    and #$03
    bne cherry_spawn_done
    lda #1
    sta cherry_active
    jsr update_cherry_position
cherry_spawn_done:
    rts

update_cherry_position:
    lda cherry_active
    beq cherry_position_done
    lda stick_len
    clc
    adc #8
    lsr
    lsr
    lsr
    lsr
    clc
    adc hero_x
    sta cherry_x
    asl
    asl
    asl
    clc
    adc #2
    sta $d00a
    lda #CHERRY_Y
    sta $d00b
    lda $d010
    and #$df
    sta $d010
    lda $d015
    ora #$20
    sta $d015
cherry_position_done:
    rts

hide_cherry:
    lda #0
    sta cherry_active
    lda $d015
    and #$df
    sta $d015
    rts

update_cloud_motion:
    inc cloud_motion_ticks
    lda cloud_motion_ticks
    cmp #8
    bcc cloud_motion_done
    lda #0
    sta cloud_motion_ticks
    inc cloud_left_phase
    lda cloud_left_phase
    and #$0f
    sta cloud_left_phase
    tax
    lda bird_active
    bne cloud_left_motion_done
    lda cloud_bob_offsets,x
    clc
    adc cloud_left_base_y
    sta $d00d
cloud_left_motion_done:
    inc cloud_right_phase
    lda cloud_right_phase
    and #$0f
    sta cloud_right_phase
    tax
    lda cloud_bob_offsets,x
    clc
    adc cloud_right_base_y
    sta $d00f
cloud_motion_done:
    rts

update_bird_motion:
    lda bird_active
    bne bird_flight_update
    lda bird_spawn_delay
    beq bird_try_spawn
    dec bird_spawn_delay
    rts
bird_try_spawn:
    jsr random_byte
    and #$07
    bne bird_schedule_next
    jsr start_bird_flight
    rts
bird_schedule_next:
    jsr random_byte
    and #$7f
    clc
    adc #90
    sta bird_spawn_delay
    rts
bird_flight_update:
    inc bird_animation_ticks
    lda bird_animation_ticks
    cmp #6
    bcc bird_move
    lda #0
    sta bird_animation_ticks
    lda bird_frame
    eor #1
    sta bird_frame
    beq bird_set_frame_a
    lda #$ae
    bne bird_set_sprite_pointer
bird_set_frame_a:
    lda #$ad
bird_set_sprite_pointer:
    sta $07fe
bird_move:
    lda bird_x
    clc
    adc #3
    sta bird_x
    bcc bird_x_ready
    lda #1
    sta bird_x_high
    lda #$40
    sta bird_x_high_mask
bird_x_ready:
    lda bird_x
    sta $d00c
    lda $d010
    and #$bf
    ora bird_x_high_mask
    sta $d010
    lda bird_x_high
    beq bird_flight_done
    lda bird_x
    cmp #80
    bcc bird_flight_done
    jsr finish_bird_flight
bird_flight_done:
    rts

start_bird_flight:
    lda #1
    sta bird_active
    lda $d00c
    sta bird_saved_cloud_x
    lda $d00d
    sta bird_saved_cloud_y
    lda $d010
    and #$40
    sta bird_saved_cloud_x_high
    lda #16
    sta bird_x
    lda #0
    sta bird_x_high
    sta bird_x_high_mask
    sta bird_frame
    sta bird_animation_ticks
    lda $d010
    and #$bf
    sta $d010
    lda #$ad
    sta $07fe
    lda $d01c
    ora #$40
    sta $d01c
    lda #7
    sta $d02e
    lda $d00f
    clc
    adc #6
    sta $d00d
    lda bird_x
    sta $d00c
    lda $d015
    ora #$40
    sta $d015
    rts

finish_bird_flight:
    lda #0
    sta bird_active
    lda #$ab
    sta $07fe
    lda #$21
    sta $d01c
    lda #1
    sta $d02e
    lda bird_saved_cloud_x
    sta $d00c
    lda bird_saved_cloud_y
    sta $d00d
    lda $d010
    and #$bf
    ora bird_saved_cloud_x_high
    sta $d010
    lda cloud_sprites_visible
    beq bird_cloud_hidden
    lda $d015
    ora #$40
    sta $d015
bird_cloud_hidden:
    jsr random_byte
    and #$7f
    clc
    adc #150
    sta bird_spawn_delay
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
    lda difficulty_active
    beq generate_target_done
generate_target_reduction:
    jsr random_byte
    and #$03
    beq generate_target_reduction
    sta target_reduction
    lda target_w
    sec
    sbc target_reduction
    sta target_w
generate_target_done:
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
    lda #$06
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
    sta $d414
    lda #$08
    sta $d413
    lda #$10
    sta $d404
    sta $d40b
    sta $d412
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
    jsr spawn_cherry
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
    jsr sound_place
    rts

grow_stick:
    lda stick_len
    cmp #MAX_STICK
    bcs grow_done
    clc
    adc #2
    sta stick_len
    jsr draw_vertical_stick_sprites
    jsr update_cherry_position
    jsr sound_grow
grow_done:
    rts

sound_grow:
    lda #0
    sta $d400
    lda stick_len
    clc
    adc #$10
    sta $d401
    lda #$0f
    sta $d418
    lda #$21
    sta $d404
    rts

sound_place:
    lda #$10
    sta $d404
    lda #0
    sta $d400
    lda #$28
    sta $d401
    lda #$0f
    sta $d418
    lda #$21
    sta $d404
    lda #6
    sta place_sound_ticks
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
    sbc #7
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
    lda place_sound_ticks
    beq turn_sound_done
    dec place_sound_ticks
    bne turn_sound_done
    lda #$10
    sta $d404
turn_sound_done:
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
    sta delta_work
    lda stick_len
    clc
    adc #5
    lsr
    lsr
    lsr
    beq stick_tip_offset_ready
    sec
    sbc #1
stick_tip_offset_ready:
    clc
    adc delta_work
    sta stick_tip
    lda target_x
    sec
    sbc delta_work
    sta delta_work
    asl
    asl
    asl
    clc
    adc #4
    sta threshold_work
    lda stick_len
    cmp threshold_work
    bcs stick_reaches_near_edge
    jmp stick_missed
stick_reaches_near_edge:
    lda delta_work
    clc
    adc target_w
    bcs stick_landed
    asl
    bcs stick_landed
    asl
    bcs stick_landed
    asl
    bcs stick_landed
    clc
    adc #3
    bcs stick_landed
    sta threshold_work
    lda stick_len
    cmp threshold_work
    bcc stick_landed
    beq stick_landed
    jmp stick_missed
stick_landed:
    lda #1
    sta landed
    lda target_x
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
    lda #0
    sta walk_step_ticks
    sta walk_note_index
    sta hero_under_stick
    sta walk_fire_armed
    lda landed
    bne walking_with_cherry
    jsr hide_cherry
walking_with_cherry:
    jsr sound_walk_step
    rts

draw_horizontal_stick_sprites:
    lda #0
    sta $d017
    lda #$06
    sta $d01d
    lda #$a3
    sta $07f9
    lda #$a3
    sta $07fa
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
    sta segment_len
horizontal_count_full:
    lda segment_len
    cmp #HORIZONTAL_SEGMENT
    bcc horizontal_segments_counted
    sec
    sbc #HORIZONTAL_SEGMENT
    sta segment_len
    inc full_segments
    jmp horizontal_count_full
horizontal_segments_counted:
    lda full_segments
    sta segment_count
    jsr get_anchor
    lda anchor_x
    asl
    asl
    asl
    clc
    adc #11
    sta sprite_x_work
    lda #$02
    sta sprite_mask_work
    ldx #2
horizontal_full_segments:
    lda segment_count
    beq horizontal_partial_segment
    dec segment_count
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
    adc #HORIZONTAL_STRIDE
    sta sprite_x_work
    inx
    inx
    jmp horizontal_full_segments
horizontal_partial_segment:
    lda segment_len
    clc
    adc full_segments
    sta remaining_len
    bne horizontal_tail_nonzero
    jmp horizontal_segments_done
horizontal_tail_nonzero:
    cmp #25
    bcc horizontal_partial_sprite3
    lda #$a3
    sta $07fb
    lda sprite_x_work
    sta $d006
    lda $d015
    ora #$08
    sta $d015
    lda sprite_x_work
    clc
    adc #24
    sta sprite_x_work
    lda remaining_len
    sec
    sbc #24
    sta remaining_len
    lda sprite_x_work
    sta $d008
    lda $d015
    ora #$10
    sta $d015
    jmp horizontal_write_partial
horizontal_partial_sprite3:
    lda #$a4
    sta $07fb
    lda sprite_x_work
    sta $d006
    lda $d015
    ora #$08
    sta $d015
horizontal_write_partial:
    lda remaining_len
    beq horizontal_segments_done
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
horizontal_segments_done:
    lda $d010
    and #$e1
    sta $d010
    rts

update_walk:
    lda fire_pressed
    beq walk_fire_released
    lda walk_fire_armed
    beq walk_fire_checked
    lda #0
    sta walk_fire_armed
    lda hero_under_stick
    eor #1
    sta hero_under_stick
    jsr draw_hero
    jmp walk_fire_checked
walk_fire_released:
    lda #1
    sta walk_fire_armed
walk_fire_checked:
    lda hero_x
    cmp move_target
    bcc walk_not_arrived
    jmp walk_arrived
walk_not_arrived:
    lda hero_subpixel
    clc
    adc #2
    cmp #8
    bcc walk_subpixel_ready
    sec
    sbc #8
    inc hero_x
walk_subpixel_ready:
    sta hero_subpixel
    jsr draw_hero
    jsr collect_cherry
    lda cherry_sound_ticks
    beq walk_melody_tick
    dec cherry_sound_ticks
    bne walk_step_wait
    lda #$10
    sta $d404
    sta $d412
    jmp walk_step_wait
walk_melody_tick:
    inc walk_step_ticks
    lda walk_step_ticks
    cmp #6
    bcc walk_step_wait
    lda #0
    sta walk_step_ticks
    jsr sound_walk_step
walk_step_wait:
    rts

collect_cherry:
    lda cherry_active
    beq cherry_collect_done
    lda hero_under_stick
    beq cherry_collect_done
    lda hero_x
    clc
    adc #3
    cmp cherry_x
    bcc cherry_collect_done
    lda #0
    sta cherry_active
    lda $d015
    and #$df
    sta $d015
    jsr sound_cherry
    lda cherry_count
    cmp #255
    bcs cherry_count_done
    inc cherry_count
cherry_count_done:
    jsr draw_score
    lda #CHERRY_BONUS
    sta cherry_bonus_count
cherry_bonus_loop:
    jsr add_point
    dec cherry_bonus_count
    bne cherry_bonus_loop
cherry_collect_done:
    rts

sound_cherry:
    lda #20
    sta cherry_sound_ticks
    lda #$0f
    sta $d418
    lda #$60
    sta $d400
    lda #$22
    sta $d401
    lda #$8e
    sta $d407
    lda #$2a
    sta $d408
    lda #$5f
    sta $d40e
    lda #$33
    sta $d40f
    lda #$21
    sta $d404
    sta $d40b
    sta $d412
    rts

walk_arrived:
    lda #$10
    sta $d404
    sta $d40b
    sta $d412
    lda hero_under_stick
    beq walk_arrived_upright
    lda #0
    sta landed
walk_arrived_upright:
    lda #0
    sta hero_under_stick
    jsr draw_hero
    lda landed
    bne walk_landed_success
    jmp show_game_over
walk_landed_success:
    jsr advance_scene
    lda #4
    sta base_x
    lda #8
    sta base_w
    lda #9
    sta hero_x
    lda #0
    sta stick_len
    sta hero_subpixel
    sta hero_under_stick
    sta walk_fire_armed
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
    sta walk_step_ticks
    sta cherry_sound_ticks
    jsr hide_cherry
    jsr draw_title
    jsr draw_score
    jsr draw_scene
    jsr hide_stick_sprites
    rts

advance_scene:
    inc scene_round_count
    lda scene_round_count
    cmp #10
    bcc advance_scene_done
    lda #0
    sta scene_round_count
    lda #1
    sta difficulty_active
    inc scene_type
    lda scene_type
    cmp #3
    bcc advance_scene_done
    lda #0
    sta scene_type
advance_scene_done:
    rts

sound_walk_step:
    ldx walk_note_index
    lda walk_note_low,x
    sta $d407
    lda walk_note_high,x
    sta $d408
    lda #$0f
    sta $d418
    lda #$21
    sta $d40b
    inx
    txa
    and #$03
    sta walk_note_index
    rts

show_game_over:
    lda #STATE_OVER
    sta state
    lda #$02
    sta $d020
    jsr hide_cherry
    jsr hide_stick_sprites
    jsr show_fallen_hero
    jsr sound_game_over
    lda #0
    sta retry_armed
    lda #4
    sta draw_y
    lda #7
    sta draw_x
    lda #2
    sta plot_color
    lda #<game_over_text
    sta text_ptr
    lda #>game_over_text
    sta text_ptr+1
    jsr draw_text
    lda #1
    sta plot_color
    rts

update_game_over:
    jsr update_game_over_sound
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

show_fallen_hero:
    lda #$aa
    sta $07f8
    lda $d01c
    and #$fe
    sta $d01c
    lda $d001
    clc
    adc #8
    sta $d001
    rts

sound_game_over:
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    sta game_over_sound_ticks
    sta game_over_sound_step
    sta go_voice1_low
    sta go_voice2_low
    sta go_voice3_low
    sta $d400
    sta $d407
    sta $d40e
    lda #$48
    sta go_voice1_high
    sta $d401
    lda #$38
    sta go_voice2_high
    sta $d408
    lda #$2b
    sta go_voice3_high
    sta $d40f
    lda #0
    sta $d405
    sta $d40c
    sta $d413
    lda #$f0
    sta $d406
    sta $d40d
    sta $d414
    lda #$0f
    sta $d418
    lda #$11
    sta $d404
    sta $d40b
    sta $d412
    rts

update_game_over_sound:
    lda game_over_sound_step
    cmp #24
    bcs game_over_sound_done
    inc game_over_sound_ticks
    lda game_over_sound_ticks
    cmp #3
    bcc game_over_sound_done
    lda #0
    sta game_over_sound_ticks
    sec
    lda go_voice1_low
    sbc #$80
    sta go_voice1_low
    sta $d400
    lda go_voice1_high
    sbc #$01
    sta go_voice1_high
    sta $d401
    sec
    lda go_voice2_low
    sbc #$80
    sta go_voice2_low
    lda go_voice2_high
    sbc #$01
    sta go_voice2_high
    sta $d408
    lda go_voice2_low
    sta $d407
    sec
    lda go_voice3_low
    sbc #$80
    sta go_voice3_low
    lda go_voice3_high
    sbc #$01
    sta go_voice3_high
    sta $d40f
    lda go_voice3_low
    sta $d40e
    inc game_over_sound_step
    lda game_over_sound_step
    cmp #24
    bcc game_over_sound_done
    lda #0
    sta $d404
    sta $d40b
    sta $d412
game_over_sound_done:
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
    lda #12
    sta plot_color
    lda #0
    sta draw_y
    sta draw_x
    lda #<title_text
    sta text_ptr
    lda #>title_text
    sta text_ptr+1
    jsr draw_text
    lda #1
    sta plot_color
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
    lda #20
    sta draw_x
    lda #<cherries_text
    sta text_ptr
    lda #>cherries_text
    sta text_ptr+1
    jsr draw_text

    lda cherry_count
    sta number_work
    lda #0
    sta hundreds
count_cherries_hundreds:
    lda number_work
    cmp #100
    bcc count_cherries_tens_start
    sec
    sbc #100
    sta number_work
    inc hundreds
    jmp count_cherries_hundreds
count_cherries_tens_start:
    lda #0
    sta tens
count_cherries_tens:
    lda number_work
    cmp #10
    bcc draw_cherries_digits
    sec
    sbc #10
    sta number_work
    inc tens
    jmp count_cherries_tens
draw_cherries_digits:
    lda #29
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
    lda bird_active
    beq draw_scene_clear
    jsr finish_bird_flight
draw_scene_clear:
    lda #4
    sta draw_y
    lda #0
    sta draw_x
    lda #<blank_line
    sta text_ptr
    lda #>blank_line
    sta text_ptr+1
    jsr draw_text
    jsr randomize_background
    lda scene_type
    bne draw_non_nature_scene
    jmp draw_nature_scene
draw_non_nature_scene:
    cmp #1
    bne draw_beach_scene_start
    jmp draw_city_scene
draw_beach_scene_start:
    jsr draw_beach_scene
    jsr draw_clouds
    jmp draw_scene_platforms
draw_nature_scene:
    lda #$06
    sta $d020
    lda #$03
    sta $d021
    jsr draw_hills
    jsr draw_clouds
    jsr draw_trees
    jmp draw_scene_platforms
draw_city_scene:
    lda #$0c
    sta $d020
    lda #$06
    sta $d021
    lda $d015
    and #$3f
    sta $d015
    lda #0
    sta cloud_sprites_visible
    jsr draw_city_scene_art
draw_scene_platforms:
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

draw_city_scene_art:
    lda #1
    sta scene_rect_x
    lda #6
    sta scene_rect_width
    lda #12
    sta scene_rect_color
    lda #9
    sta city_building_base_y
    jsr draw_random_city_building

    lda #8
    sta scene_rect_x
    lda #5
    sta scene_rect_width
    lda #11
    sta scene_rect_color
    lda #7
    sta city_building_base_y
    jsr draw_random_city_building

    lda #15
    sta scene_rect_x
    lda #8
    sta scene_rect_width
    lda #12
    sta scene_rect_color
    lda #10
    sta city_building_base_y
    jsr draw_random_city_building

    lda #25
    sta scene_rect_x
    lda #7
    sta scene_rect_width
    lda #11
    sta scene_rect_color
    lda #6
    sta city_building_base_y
    jsr draw_random_city_building

    lda #34
    sta scene_rect_x
    lda #6
    sta scene_rect_width
    lda #12
    sta scene_rect_color
    lda #9
    sta city_building_base_y
    jsr draw_random_city_building

    lda #CITY_WINDOW
    sta scene_rect_char
    lda #7
    sta plot_color

    lda #2
    ldx #12
    ldy #4
    jsr draw_city_window_column
    lda #4
    ldx #12
    ldy #4
    jsr draw_city_window_column
    lda #9
    ldx #10
    ldy #5
    jsr draw_city_window_column
    lda #11
    ldx #10
    ldy #5
    jsr draw_city_window_column
    lda #16
    ldx #14
    ldy #4
    jsr draw_city_window_column
    lda #18
    ldx #14
    ldy #4
    jsr draw_city_window_column
    lda #21
    ldx #14
    ldy #4
    jsr draw_city_window_column
    lda #26
    ldx #9
    ldy #6
    jsr draw_city_window_column
    lda #28
    ldx #9
    ldy #6
    jsr draw_city_window_column
    lda #30
    ldx #9
    ldy #6
    jsr draw_city_window_column
    lda #35
    ldx #12
    ldy #4
    jsr draw_city_window_column
    lda #37
    ldx #12
    ldy #4
    jsr draw_city_window_column
    rts

draw_random_city_building:
    lda #CITY_BLOCK
    sta scene_rect_char
    jsr random_byte
    and #$03
    clc
    adc city_building_base_y
    sta scene_rect_y
    lda #21
    sec
    sbc scene_rect_y
    sta scene_rect_height
    jsr fill_scene_rect
    rts

draw_city_window_column:
    sta scene_rect_x
    lda #7
    sta plot_color
    stx scene_rect_y
    sty scene_rect_height
city_window_loop:
    lda scene_rect_x
    sta draw_x
    lda scene_rect_y
    sta draw_y
    lda #CITY_WINDOW
    jsr plot
    lda scene_rect_y
    clc
    adc #2
    sta scene_rect_y
    dec scene_rect_height
    bne city_window_loop
    rts

draw_beach_scene:
    lda #$07
    sta $d020
    lda #$03
    sta $d021
    lda $d015
    and #$3f
    sta $d015

    jsr random_byte
    and #$03
    clc
    adc #17
    sta beach_shore_y

    lda #0
    sta scene_rect_x
    lda #13
    sta scene_rect_y
    lda #40
    sta scene_rect_width
    lda beach_shore_y
    sec
    sbc #13
    sta scene_rect_height
    lda #SEA_TILE
    sta scene_rect_char
    lda #6
    sta scene_rect_color
    jsr fill_scene_rect

    lda #0
    sta scene_rect_x
    lda beach_shore_y
    sta scene_rect_y
    lda #40
    sta scene_rect_width
    lda #21
    sec
    sbc beach_shore_y
    sta scene_rect_height
    lda #SAND_TILE
    sta scene_rect_char
    lda #9
    sta scene_rect_color
    jsr fill_scene_rect

    lda #SEA_WAVE
    sta scene_rect_char
    jsr draw_random_beach_wave
    jsr draw_random_beach_wave
    jsr draw_random_beach_wave
    rts

draw_random_beach_wave:
    jsr random_byte
    and #$1f
    sta scene_rect_x
    jsr random_byte
    and #$03
    clc
    adc #13
    sta scene_rect_y
    jsr random_byte
    and #$03
    clc
    adc #3
    sta scene_rect_width
    lda #14
    sta plot_color
    ldx scene_rect_width
beach_wave_loop:
    lda scene_rect_x
    sta draw_x
    lda scene_rect_y
    sta draw_y
    lda scene_rect_char
    jsr plot
    inc scene_rect_x
    dex
    bne beach_wave_loop
    rts

fill_scene_rect:
    lda scene_rect_color
    sta plot_color
scene_rect_row:
    lda scene_rect_width
    sta segment_count
    lda scene_rect_x
    sta draw_x
    lda scene_rect_y
    sta draw_y
scene_rect_column:
    lda scene_rect_char
    jsr plot
    inc draw_x
    dec segment_count
    bne scene_rect_column
    inc scene_rect_y
    dec scene_rect_height
    bne scene_rect_row
    rts

randomize_background:
    jsr random_byte
    and #$03
    sta hill_left_offset
    jsr random_byte
    and #$03
    sta hill_right_offset
    jsr random_byte
    and #$03
    sta tree_left_offset
    jsr random_byte
    and #$03
    sta tree_right_offset
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
    lda text_index
    cmp #70
    bcs draw_right_hill_row
    lda draw_x
    clc
    adc hill_left_offset
    sta draw_x
    lda hill_side_x
    clc
    adc hill_left_offset
    sta hill_side_x
    jmp draw_hill_row_ready
draw_right_hill_row:
    lda draw_x
    sec
    sbc hill_right_offset
    sta draw_x
    lda hill_side_x
    sec
    sbc hill_right_offset
    sta hill_side_x
draw_hill_row_ready:
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
    lda #$ab
    sta $07fe
    lda #$ac
    sta $07ff
    lda #$01
    sta $d02e
    sta $d02f
    lda #1
    sta cloud_sprites_visible
    lda #0
    sta cloud_motion_ticks
    sta cloud_left_phase
    lda #4
    sta cloud_right_phase
    jsr random_byte
    and #$1f
    clc
    adc #80
    sta $d00c
    jsr random_byte
    and #$0f
    clc
    adc #96
    sta cloud_left_base_y
    sta $d00d
    jsr random_byte
    and #$1f
    clc
    adc #144
    sta $d00e
    jsr random_byte
    and #$0f
    clc
    adc #104
    sta cloud_right_base_y
    sta $d00f
    lda $d010
    and #$3f
    sta $d010
    lda $d015
    ora #$c0
    sta $d015
    rts

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
    lda text_index
    cmp #52
    bcs draw_right_tree_tile
    lda draw_x
    clc
    adc tree_left_offset
    sta draw_x
    jmp draw_tree_tile_ready
draw_right_tree_tile:
    lda draw_x
    sec
    sbc tree_right_offset
    sta draw_x
draw_tree_tile_ready:
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
    lda scene_type
    beq draw_platform_nature
    cmp #1
    beq draw_platform_city
    lda #9
    bne draw_platform_top_color
draw_platform_city:
    lda #12
    bne draw_platform_top_color
draw_platform_nature:
    lda #5
draw_platform_top_color:
    sta plot_color
    jsr draw_platform_row
    inc draw_y
    lda scene_type
    beq draw_platform_nature_soil
    cmp #1
    beq draw_platform_city_soil
    lda #8
    bne draw_platform_soil_color
draw_platform_city_soil:
    lda #11
    bne draw_platform_soil_color
draw_platform_nature_soil:
    lda #9
draw_platform_soil_color:
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
    bcc hero_x_add_subpixel
    inc hero_x_high
hero_x_add_subpixel:
    clc
    adc hero_subpixel
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
    lda hero_under_stick
    beq hero_y_ready
    lda $d001
    clc
    adc #HERO_UNDER_OFFSET
    sta $d001
hero_y_ready:
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
    !byte 19,20,9,3,11,32,8,5,18,15,32,5,14,8,1,14,3,5,4,32,22,49,46,49,49,0
controls_text:
    !byte 8,15,12,4,32,6,9,18,5,32,7,18,15,23,44,32,20,1,16,32,6,9,18,5,32,4,21,3,11,47,18,9,19,5,0
score_text:
    !byte 19,3,15,18,5,0
best_text:
    !byte 2,5,19,20,0
cherries_text:
    !byte 3,8,5,18,18,9,5,19,0
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
    !byte 4,16,TREE_TRUNK,9
    !byte 4,17,TREE_TRUNK,9
    !byte 4,18,TREE_TRUNK,9
    !byte 30,15,TREE_LEAVES,5
    !byte 31,15,TREE_LEAVES,5
    !byte 32,15,TREE_LEAVES,5
    !byte 33,15,TREE_LEAVES,5
    !byte 34,15,TREE_LEAVES,5
    !byte 31,14,TREE_LEAVES,13
    !byte 32,14,TREE_LEAVES,13
    !byte 33,14,TREE_LEAVES,13
    !byte 32,13,TREE_TOP,13
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
    ; City facades and windows, followed by sand, sea, and rolling waves.
    !byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    !byte $00,$7e,$42,$5a,$42,$5a,$7e,$00
    !byte $aa,$55,$aa,$55,$55,$aa,$55,$aa
    !byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    !byte $00,$18,$3c,$7e,$3c,$18,$00,$00
graphics_tiles_end:

vertical_sprite_pointers:
    !byte $a1,$a2,$a2,$a2
horizontal_run_masks:
    !byte $00,$80,$c0,$e0,$f0,$f8,$fc,$fe,$ff
walk_note_low:
    !byte $90,$62,$03,$20
walk_note_high:
    !byte $11,$16,$1b,$22
cloud_bob_offsets:
    !byte 0,1,2,3,4,3,2,1,0,1,2,3,4,3,2,1

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
target_reduction: !byte 0
hero_x:         !byte 9
hero_subpixel:  !byte 0
hero_under_stick: !byte 0
walk_fire_armed: !byte 0
stick_len:      !byte 0
turn_ticks:     !byte 0
landed:         !byte 0
move_target:    !byte 0
stick_tip:      !byte 0
anchor_x:       !byte 0
gap_size:       !byte 0
fire_pressed:   !byte 0
random_seed:    !byte $a5
hill_left_offset: !byte 0
hill_right_offset: !byte 0
tree_left_offset: !byte 0
tree_right_offset: !byte 0
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
delta_work: !byte 0
threshold_work: !byte 0
walk_step_ticks: !byte 0
walk_note_index: !byte 0
cherry_sound_ticks: !byte 0
place_sound_ticks: !byte 0
cherry_count: !byte 0
scene_type: !byte 0
scene_round_count: !byte 0
difficulty_active: !byte 0
scene_rect_x: !byte 0
scene_rect_y: !byte 0
scene_rect_width: !byte 0
scene_rect_height: !byte 0
scene_rect_char: !byte 0
scene_rect_color: !byte 0
city_building_base_y: !byte 0
beach_shore_y: !byte 0
cloud_sprites_visible: !byte 0
bird_active: !byte 0
bird_spawn_delay: !byte 90
bird_animation_ticks: !byte 0
bird_frame: !byte 0
bird_x: !byte 0
bird_x_high: !byte 0
bird_x_high_mask: !byte $40
bird_saved_cloud_x: !byte 0
bird_saved_cloud_y: !byte 0
bird_saved_cloud_x_high: !byte 0
cloud_motion_ticks: !byte 0
cloud_left_phase: !byte 0
cloud_right_phase: !byte 0
cloud_left_base_y: !byte 0
cloud_right_base_y: !byte 0
game_over_sound_ticks: !byte 0
game_over_sound_step: !byte 0
go_voice1_low: !byte 0
go_voice1_high: !byte 0
go_voice2_low: !byte 0
go_voice2_high: !byte 0
go_voice3_low: !byte 0
go_voice3_high: !byte 0

* = $2800
hero_sprite:
    !byte $00,$aa,$00
    !byte $00,$be,$00
    !byte $00,$be,$00
    !byte $00,$aa,$00
    !byte $00,$28,$00
    !byte $00,$aa,$00
    !byte $00,$aa,$00
    !byte $00,$aa,$00
    !byte $00,$aa,$00
    !byte $00,$aa,$00
    !byte $00,$28,$00
    !byte $00,$28,$00
    !byte $00,$28,$00
    !byte $00,$aa,$00
    !byte $00,$aa,$00
    !byte $00,$8a,$00
    !byte $00,$8a,$00
    !byte $00,$8a,$00
    !byte $00,$8a,$00
    !byte $00,$8a,$00
    !byte $00,$8a,$00
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
    !byte $00,$00,$00
    !byte $00,$30,$00
    !byte $00,$cc,$00
    !byte $03,$03,$00
    !byte $0f,$83,$e0
    !byte $3a,$8e,$a0
    !byte $0a,$02,$80
    !byte $03,$c3,$c0
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte 0

* = $2a80
fallen_hero_sprite:
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$01,$00
    !byte $00,$03,$80
    !byte $04,$03,$88
    !byte $1f,$07,$fe
    !byte $3f,$93,$ff
    !byte $3f,$ff,$be
    !byte $7f,$ff,$cc
    !byte $3f,$ff,$8e
    !byte $3f,$93,$ee
    !byte $1f,$07,$ff
    !byte $04,$03,$ee
    !byte $00,$00,$8e
    !byte $00,$00,$04
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte 0

* = $2ac0
cloud_left_sprite:
    !byte $00,$00,$00
    !byte $00,$08,$00
    !byte $00,$3e,$00
    !byte $00,$7f,$00
    !byte $00,$ff,$80
    !byte $01,$ff,$c0
    !byte $03,$ff,$e0
    !byte $0f,$ff,$f8
    !byte $1f,$ff,$fc
    !byte $3f,$ff,$fe
    !byte $3f,$ff,$fe
    !byte $3f,$ff,$fe
    !byte $7f,$ff,$ff
    !byte $3f,$ff,$fe
    !byte $7f,$ff,$ff
    !byte $3f,$ff,$fe
    !byte $3f,$ff,$fe
    !byte $0f,$ff,$f8
    !byte $03,$ff,$e0
    !byte $00,$08,$00
    !byte $00,$00,$00
    !byte 0

* = $2b40
bird_sprite_wings_up:
    !byte $00,$00,$00
    !byte $00,$10,$00
    !byte $00,$44,$00
    !byte $01,$45,$00
    !byte $05,$55,$40
    !byte $15,$55,$50
    !byte $05,$55,$40
    !byte $01,$55,$00
    !byte $00,$55,$00
    !byte $00,$44,$00
    !byte $00,$10,$00
    !fill 31,0

* = $2b80
bird_sprite_wings_down:
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$10,$00
    !byte $01,$55,$00
    !byte $05,$55,$40
    !byte $15,$55,$50
    !byte $05,$55,$40
    !byte $01,$45,$00
    !byte $00,$44,$00
    !byte $00,$10,$00
    !fill 34,0

* = $2b00
cloud_right_sprite:
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$00,$00
    !byte $00,$20,$00
    !byte $01,$fc,$40
    !byte $03,$ff,$f8
    !byte $03,$ff,$fc
    !byte $07,$ff,$fc
    !byte $07,$ff,$fe
    !byte $3f,$ff,$fe
    !byte $7f,$ff,$fe
    !byte $7f,$ff,$ff
    !byte $7f,$ff,$fe
    !byte $ff,$ff,$fe
    !byte $7f,$ff,$fe
    !byte $7f,$ff,$ff
    !byte $7f,$ff,$fe
    !byte $3f,$ff,$fc
    !byte $07,$ff,$f0
    !byte $00,$08,$00
    !byte $00,$00,$00
    !byte 0
