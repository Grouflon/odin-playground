package main

import "core:fmt"
import "core:math"

import rl "vendor:raylib"

SpriteSheet :: struct
{
    texture : rl.Texture2D,
    columns : int,
    rows : int,
    cell_width : int,
    cell_height : int,
}

build_spritesheet :: proc (_texture : rl.Texture2D, _columns : int, _rows : int) -> SpriteSheet
{
    return SpriteSheet{
        texture = _texture,
        columns = _columns,
        rows = _rows,
        cell_width = int(_texture.width) / _columns,
        cell_height = int(_texture.height) / _rows,
    }
}

AnimFrame :: struct
{
    index : int,
    duration : int,
}

Animation :: struct
{
    spritesheet : ^SpriteSheet,
    loop : bool,
    frames : [dynamic]AnimFrame,
}

AnimationPlayer :: struct
{
    fps : f32,

    _current_animation : ^Animation,
    _total_animation_frames : int,
    _frame : f32,
}

CosmonautState :: enum
{
    IDLE,
    WALKING,
}

play_animation :: proc(_player : ^AnimationPlayer, _animation : ^Animation)
{
    if _player._current_animation == _animation { return }

    _player._current_animation = _animation
    _player._frame = 0.0
    _player._total_animation_frames = 0

    if _player._current_animation != nil
    {
        for frame in _player._current_animation.frames
        {
            _player._total_animation_frames += frame.duration
        }
    }
}

update_animation_player :: proc(_player : ^AnimationPlayer, _dt : f32)
{
    if _player._total_animation_frames <= 0 { return }

    total_frames : f32 = f32(len(_player._current_animation.frames))
    if total_frames <= 0 { return }

    _player._frame += _player.fps * _dt
    if (_player._current_animation.loop)
    {
        for _player._frame > total_frames
        {
            _player._frame -= total_frames;
        }
    }
    else
    {
        _player._frame = math.max(total_frames - 1.0, _player._frame)
    }
}

draw_animation:: proc(_player : ^AnimationPlayer, _position : rl.Vector2, _flip_x : bool = false, _flip_y : bool = false, _tint : rl.Color = rl.WHITE)
{
    if _player._total_animation_frames <= 0 { return }

    frame_index := int(math.floor(_player._frame))

    sprite_index := -1
    current_frame_index := 0
    for frame in _player._current_animation.frames
    {
        if frame_index >= current_frame_index && frame_index < current_frame_index + frame.duration
        {
            sprite_index = frame.index
            break
        }
        current_frame_index += frame.duration
    }
    assert(sprite_index >= 0)

    spritesheet := _player._current_animation.spritesheet
    x := sprite_index % spritesheet.columns
    y := sprite_index / spritesheet.columns
    rl.DrawTextureRec(
        spritesheet.texture,
        {
            f32(x * spritesheet.cell_width),
            f32(y * spritesheet.cell_height),
            (_flip_x ? -1.0 : 1.0) * f32(spritesheet.cell_width),
            (_flip_y ? -1.0 : 1.0) * f32(spritesheet.cell_height)
        },
        _position,
        _tint
    );
}


main :: proc()
{
    // Misc
    time : f32 = 0.0

    // Window
    game_width, game_height : i32 = 300, 200
    pixel_ratio : i32 = 5
    window_width, window_height : i32 = game_width * pixel_ratio, game_height * pixel_ratio

    rl.InitWindow(window_width, window_height, "cosmonaut")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    // Rendering
    game_render_target := rl.LoadRenderTexture(game_width, game_height);
    defer rl.UnloadRenderTexture(game_render_target)

    source_rect := rl.Rectangle{ 0.0, 0.0, f32(game_render_target.texture.width), -f32(game_render_target.texture.height) }
    dest_rect := rl.Rectangle{ 0.0, 0.0, f32(window_width), f32(window_height) }

    game_camera := rl.Camera2D{}
    game_camera.zoom = 1.0

    render_camera := rl.Camera2D{}
    render_camera.zoom = 1.0

    // Cosmonaut
    x : f32 = 150.0
    x_speed : f32 = 16.0
    x_flip := false

    cosmonaut_texture := rl.LoadTexture("data/cosmonaut.png");
    defer rl.UnloadTexture(cosmonaut_texture)
    cosmonaut_spritesheet := build_spritesheet(cosmonaut_texture, 3, 3)

    animation_player := AnimationPlayer{ fps=8 }

    idle_anim := Animation{
        &cosmonaut_spritesheet,
        true,
        {
            {0, 1}
        }
    }

    walk_anim := Animation{
        &cosmonaut_spritesheet,
        true,
        {
            {1, 1},
            {2, 1},
            {3, 1},
            {4, 1},
        }
    }
    play_animation(&animation_player, &walk_anim)

    // === LOOP ===
    for !rl.WindowShouldClose() {

        // === UPDATE ===
        dt := rl.GetFrameTime()
        time += f32(dt)

        x_sign : f32 = 0.0

        if (rl.IsKeyDown(rl.KeyboardKey.LEFT)) { x_sign -= 1.0 }
        if (rl.IsKeyDown(rl.KeyboardKey.RIGHT)) { x_sign += 1.0 }
        is_moving := x_sign != 0.0

        x += x_sign * x_speed * dt

        if (is_moving)
        {
            play_animation(&animation_player, &walk_anim)
            x_flip = x_sign < 0.0 ? true : false
        }
        else
        {
            play_animation(&animation_player, &idle_anim)
        }

        update_animation_player(&animation_player, dt)

        // === DRAW ===
        {
            rl.BeginTextureMode(game_render_target)
            defer rl.EndTextureMode()

            rl.BeginMode2D(game_camera)
            defer rl.EndMode2D()

            rl.ClearBackground(rl.WHITE)
            // rl.DrawTexture(cosmonaut_texture, 50, 50, rl.WHITE)
            draw_animation(&animation_player, {x, 150.0}, x_flip)
        }

        {
            rl.BeginDrawing()
            defer rl.EndDrawing()

            rl.ClearBackground(rl.WHITE)

            {
                rl.BeginMode2D(render_camera)
                defer rl.EndMode2D()

                rl.DrawTexturePro(game_render_target.texture, source_rect, dest_rect, {0.0, 0.0}, 0.0, rl.WHITE)
                rl.DrawFPS(rl.GetScreenWidth() - 95, 10)    
            }
        }
    }
}