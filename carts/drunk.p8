pico-8 cartridge // http://www.pico-8.com
version 39
__lua__
game_state = {
    main_menu = 0,
    playing = 1,
    payday = 2,
    game_over = 3,
    win = 4
}

-- Game constants
game_duration = 360 -- Total game duration in seconds
salary = 267 -- Salary amount in rubles per payment
salary_frequency = 30 -- How often salary comes in seconds
base_liver_health = 2000 -- Initial liver health in units
liver_damage_factor = 0.001833 -- Liver damage growth factor per second (+0.1833% damage each second)
base_sobering_rate = 15 -- Intoxication units lost every SOBERING_FREQUENCY seconds
sobering_acceleration = 0.011667 -- Sobering acceleration over time (+0.01167 units speed each second)
sobering_frequency = 1 -- How often sobering occurs in seconds
tolerance_factor = 0.0015 -- Alcohol effectiveness decrease over time (-0.15% effectiveness each second)
drinking_frequency = 5 -- How often character drinks a shot in seconds

-- Basic resources
money = 267
liver_health = base_liver_health
intoxication = 150
selected_drink_index = 1 -- Selected drink in shop

-- Character animation
character_animation_timer = 0 -- Timer for character animation (changes every second)

-- Slowmotion effect
slow_motion_multiplier = 2 -- How much slower time goes during slowmotion

-- Wasted protection mechanism
wasted_protection_uses = 3 -- How many times player can be saved from auto-drinking when wasted
wasted_protection_remaining = 3 -- Remaining uses
was_wasted_last_frame = false -- Track when entering/exiting wasted state
wasted_overflow_liver_damage = 50 -- Base liver damage when entering wasted after protection is exhausted
wasted_total_count = 0 -- Total number of times entered wasted state (for display)
wasted_cycle_count = 0 -- Number of completed cycles (increases damage multiplier)
wasted_duration = 600 -- How long to stay in wasted state (10 seconds at 60fps)
wasted_timer = 0 -- Timer for forced wasted state

-- Critical protection mechanism
critical_duration = 600 -- How long to stay in critical state (10 seconds at 60fps)
critical_timer = 0 -- Timer for forced critical state
critical_liver_damage = 200 -- Liver damage when critical timer expires
was_critical_last_frame = false -- Track when entering/exiting critical state

-- Intoxication parameters
intoxication_min_threshold = 0 -- Below this - game over
intoxication_optimal_min = 150 -- Optimal range
intoxication_optimal_max = 400 -- Optimal range
intoxication_wasted_threshold = 450 -- "Wasted" - penalties
intoxication_critical = 500 -- Critical level - game over

-- Payday bonuses
payday_bonuses = {
    { name = "zakuska", effect = "heal_liver", value = 173, chance = 0.2 },
    { name = "opohmel", effect = "add_intoxication", value = 37, chance = 0.15 },
    { name = "halturka", effect = "add_money", value = 123, chance = 0.25 },
    { name = "activated_carbon", effect = "liver_protection", value = 0.47, duration = 1800, chance = 0.15 }, -- 30 sec
    { name = "ascorbic", effect = "increase_max_liver", value = 189, chance = 0.1 },
    { name = "alcoholic_training", effect = "drinking_efficiency", value = 0.31, duration = 1800, chance = 0.15 } -- 30 sec
}

-- Temporary bonus effects
liver_protection_bonus = 0
liver_protection_timer = 0
drinking_efficiency_bonus = 0
drinking_efficiency_timer = 0
max_liver_bonus = 0

-- Drink effect functions
function sanitizer_effect()
    -- Shaking selection (frame randomly shifts)
    shaking_timer = 300
    -- 5 seconds at 60fps
end

function cologne_effect()
    -- Slowmotion 4 sec (slow frame movement)
    slowmotion_timer = 240
    -- 4 seconds at 60fps
end

function antifreeze_effect()
    -- Blindness 5 sec (can't see drinks)
    blind_timer = 300
    -- 5 seconds at 60fps
end

function cognac_effect()
    -- Inverted controls 6 sec (ヌ●➡️=ヌ●⧗, ヌ●…=ヌ●★)
    inverted_controls_timer = 360
    -- 6 seconds at 60fps
end

function beer_effect()
    -- Diuretic effect (pause for mini-game)
    minigame_active = true
end

function vodka_effect()
    -- Blackout 2 sec (controls don't work)
    blackout_timer = 120
    -- 2 seconds at 60fps
end

function yorsh_effect()
    -- Chaotic frame (moves randomly)
    chaotic_movement_timer = 480
    -- 8 seconds at 60fps
end

drinks = {
    {
        name = "sanitizer",
        price = 13,
        intoxication = 85,
        liver_damage = 11,
        effect_chance = 0.20,
        effect_func = sanitizer_effect
    },
    {
        name = "cologne_shipr",
        price = 21,
        intoxication = 145,
        liver_damage = 13,
        effect_chance = 0.25,
        effect_func = cologne_effect
    },
    {
        name = "antifreeze",
        price = 43,
        intoxication = 265,
        liver_damage = 17,
        effect_chance = 0.35,
        effect_func = antifreeze_effect
    },
    {
        name = "cognac_777",
        price = 89,
        intoxication = 160,
        liver_damage = 4,
        effect_chance = 0.08,
        effect_func = cognac_effect
    },
    {
        name = "beer",
        price = 29,
        intoxication = 65,
        liver_damage = 3,
        effect_chance = 0.20,
        effect_func = beer_effect
    },
    {
        name = "vodka",
        price = 67,
        intoxication = 235,
        liver_damage = 7,
        effect_chance = 0.12,
        effect_func = vodka_effect
    },
    {
        name = "yorsh",
        price = 73,
        intoxication = 305,
        liver_damage = 7,
        effect_chance = 0.30,
        effect_func = yorsh_effect
    }
}

function _init()
    -- Initialize game state
    current_state = game_state.main_menu
end

function _update60()
    -- Update character animation timer (slower during slowmotion)
    if slowmotion_timer > 0 then
        if frames % slow_motion_multiplier == 0 then
            character_animation_timer += 1
        end
    else
        character_animation_timer += 1
    end
    
    -- Update wasted timer (considering slowmotion)
    if wasted_timer > 0 then
        if slowmotion_timer > 0 then
            if frames % slow_motion_multiplier == 0 then
                wasted_timer -= 1
            end
        else
            wasted_timer -= 1
        end
    end
    
    -- Update critical timer (considering slowmotion)
    if critical_timer > 0 then
        if slowmotion_timer > 0 then
            if frames % slow_motion_multiplier == 0 then
                critical_timer -= 1
                if critical_timer <= 0 then
                    -- Timer expired - apply damage and halve intoxication
                    liver_health -= critical_liver_damage
                    intoxication = intoxication / 2
                end
            end
        else
            critical_timer -= 1
            if critical_timer <= 0 then
                -- Timer expired - apply damage and halve intoxication
                liver_health -= critical_liver_damage
                intoxication = intoxication / 2
            end
        end
    end
    
    -- Update effects first
    local in_blackout = update_effects()

    -- Skip game updates during blackout
    if in_blackout then
        return
    end

    -- Update time
    update_time()

    if current_state == game_state.main_menu then
        update_menu()
    elseif current_state == game_state.playing then
        update_game()
    elseif current_state == game_state.payday then
        update_payday()
    elseif current_state == game_state.game_over then
        update_game_over()
    elseif current_state == game_state.win then
        update_win()
    end
end

frames = 0
total_seconds = 0

function update_time()
    frames += 1
    
    -- Calculate effective frame rate (slower during slowmotion)
    local effective_frame_rate = 60
    if slowmotion_timer > 0 then
        effective_frame_rate = 60 * slow_motion_multiplier
    end
    
    if frames >= effective_frame_rate then
        frames = 0
        total_seconds += 1

        -- Update wasted protection mechanism
        update_wasted_protection()
        
        -- Update critical protection mechanism
        update_critical_protection()

        -- Automatic alcohol consumption every DRINKING_FREQUENCY seconds
        -- Use wasted protection mechanism
        if total_seconds % drinking_frequency == 0 and not minigame_active and can_auto_drink() then
            drink_alcohol()
        end

        -- Apply sobering
        if total_seconds % sobering_frequency == 0 then
            update_sobering()
        end
        -- Salary every SALARY_FREQUENCY seconds
        if total_seconds % salary_frequency == 0 then
            money += salary
            trigger_payday()
        end
    end
end

-- Effect variables
blind_timer = 0
hallucination_timer = 0
liver_protection_timer = 0
blackout_timer = 0
minigame_active = false
shaking_timer = 0 -- For "shaking selection" effect
slowmotion_timer = 0 -- For slowmotion effect
inverted_controls_timer = 0 -- For inverted controls
chaotic_movement_timer = 0 -- For chaotic frame movement

-- Update effect timers
function update_effects()
    if blind_timer > 0 then
        blind_timer -= 1
    end

    if shaking_timer > 0 then
        shaking_timer -= 1
    end

    if slowmotion_timer > 0 then
        slowmotion_timer -= 1
    end

    if inverted_controls_timer > 0 then
        inverted_controls_timer -= 1
    end

    if chaotic_movement_timer > 0 then
        chaotic_movement_timer -= 1
    end

    if liver_protection_timer > 0 then
        liver_protection_timer -= 1
        if liver_protection_timer <= 0 then
            liver_protection_bonus = 0
        end
    end

    if drinking_efficiency_timer > 0 then
        drinking_efficiency_timer -= 1
        if drinking_efficiency_timer <= 0 then
            drinking_efficiency_bonus = 0
        end
    end

    if blackout_timer > 0 then
        blackout_timer -= 1
        -- During blackout, skip game updates
        return true
    end

    return false
end

-- Function to drink alcohol (referenced in update_time)
function drink_alcohol()
    if #drinks > 0 then
        -- Check if we have enough money
        if money >= drinks[selected_drink_index].price then
            consume_drink(drinks[selected_drink_index])
        end
    end
end

-- Function for consuming drink with progression formulas applied
function consume_drink(drink)
    money -= drink.price

    -- Apply progression formulas
    local effective_intoxication = calculate_effective_intoxication(drink.intoxication)
    local effective_liver_damage = calculate_effective_liver_damage(drink.liver_damage)

    -- Apply effects
    intoxication += effective_intoxication
    liver_health -= effective_liver_damage

    -- Check for side effect
    if rnd(1) < drink.effect_chance then
        drink.effect_func()
    end

    -- Check game end conditions
    check_game_conditions()
end

-- Alcohol tolerance formula
function calculate_effective_intoxication(base_intoxication)
    local effectiveness = 1 - (tolerance_factor * total_seconds)
    -- -0.15% effectiveness each second
    local final_intoxication = base_intoxication * effectiveness

    -- Apply drinking efficiency bonus if active
    if drinking_efficiency_timer > 0 then
        final_intoxication = final_intoxication * (1 + drinking_efficiency_bonus)
    end

    -- Apply penalty for high intoxication
    local drunk_penalty = get_drunk_penalty()
    final_intoxication = final_intoxication * drunk_penalty

    return max(final_intoxication, base_intoxication * 0.1)
    -- minimum 10% effectiveness
end

-- Liver damage increase formula
function calculate_effective_liver_damage(base_damage)
    local damage_multiplier = 1 + (liver_damage_factor * total_seconds)
    -- +0.1833% damage each second
    local final_damage = base_damage * damage_multiplier

    -- Apply liver protection if active
    if liver_protection_timer > 0 then
        final_damage = final_damage * (1 - liver_protection_bonus)
    end

    return final_damage
end

-- Sobering function
function update_sobering()
    local current_sobering_rate = base_sobering_rate + (sobering_acceleration * total_seconds) / sobering_frequency
    intoxication = max(0, intoxication - current_sobering_rate)
end

-- Check game end conditions
function check_game_conditions()
    if liver_health <= 0 then
        -- current_state = game_state.game_over
    elseif intoxication <= intoxication_min_threshold then
        -- Too sober - game over
        -- current_state = game_state.game_over
    elseif intoxication >= intoxication_critical then
        -- Critical intoxication - game over
        -- current_state = game_state.game_over
    elseif total_seconds >= game_duration then
        -- 360 seconds passed - victory
        current_state = game_state.win
    end
end

-- Check penalties for high intoxication
function get_drunk_penalty()
    if intoxication >= intoxication_wasted_threshold then
        return 0.5 -- 50% penalty to effectiveness when "wasted"
    end
    return 1.0
    -- No penalty
end

-- Wasted protection mechanism
function update_wasted_protection()
    local is_wasted_now = intoxication >= intoxication_wasted_threshold
    
    -- Check if just entered wasted state
    if is_wasted_now and not was_wasted_last_frame then
        wasted_total_count += 1
        wasted_timer = wasted_duration -- Start wasted timer
        
        if wasted_protection_remaining > 0 then
            -- Use protection
            wasted_protection_remaining -= 1
        else
            -- Protection exhausted - deal escalating liver damage and reset protection
            wasted_cycle_count += 1
            local damage = wasted_overflow_liver_damage * wasted_cycle_count
            liver_health -= damage
            
            wasted_protection_remaining = wasted_protection_uses
            wasted_total_count = 1 -- Reset count as we start a new cycle
            
            -- Visual feedback - could add screen shake or flash here
        end
    end
    
    was_wasted_last_frame = is_wasted_now
end

-- Critical protection mechanism
function update_critical_protection()
    local is_critical_now = intoxication >= intoxication_critical
    
    -- Check if just entered critical state
    if is_critical_now and not was_critical_last_frame then
        critical_timer = critical_duration -- Start critical timer
    end
    
    was_critical_last_frame = is_critical_now
end

function can_auto_drink()
    local is_wasted = intoxication >= intoxication_wasted_threshold or wasted_timer > 0
    local is_critical = intoxication >= intoxication_critical or critical_timer > 0
    
    if is_critical then
        return false -- Never auto-drink in critical state
    elseif is_wasted then
        return wasted_protection_remaining > 0
    end
    return true
end

-- Function to trigger payday (referenced in update_time)
function trigger_payday()
    current_state = game_state.payday
end

-- Placeholder update functions
function update_menu()
    -- Handle menu input
    if btnp(4) then
        -- X button
        current_state = game_state.playing
    end
end

function update_game()
    -- Main game logic
    -- Handle drink selection, consumption, etc.

    -- Check active mini-game
    if minigame_active then
        update_minigame()
        return
    end

    -- Handle drink selection
    handle_drink_selection()
end

-- Drink selection handling function
function handle_drink_selection()
    -- Drink selection with effects buttons
    local left_pressed = btnp(0)
    -- Left
    local right_pressed = btnp(1)
    -- Right
    local up_pressed = btnp(2)
    -- Up
    local bottom_pressed = btnp(3)
    -- Down

    -- Inverted controls
    if inverted_controls_timer > 0 then
        left_pressed = btnp(1) -- Right becomes Left
        right_pressed = btnp(0) -- Left becomes Right
        up_pressed = btnp(3) -- Down becomes Up
        bottom_pressed = btnp(2) -- Up becomes Down
    end

    -- Chaotic movement - random selection
    if chaotic_movement_timer > 0 and (left_pressed or right_pressed) then
        if rnd(1) < 0.5 then
            selected_drink_index = max(1, selected_drink_index - 1)
        else
            selected_drink_index = min(#drinks, selected_drink_index + 1)
        end
        -- Shaking selection - sometimes randomly shifts
    elseif shaking_timer > 0 and rnd(1) < 0.3 then
        if rnd(1) < 0.5 then
            selected_drink_index = max(1, selected_drink_index - 1)
        else
            selected_drink_index = min(#drinks, selected_drink_index + 1)
        end

    -- Normal controls
    elseif left_pressed then
        selected_drink_index = max(1, selected_drink_index - 1)
    elseif right_pressed then
        selected_drink_index = min(#drinks, selected_drink_index + 1)
    elseif up_pressed then
        selected_drink_index = max(1, selected_drink_index - 4)
    elseif bottom_pressed then
        selected_drink_index = min(#drinks, selected_drink_index + 4)
    end
end

-- Mini-game for diuretic effect
minigame_timer = 0
minigame_target = 0
minigame_progress = 0

-- Stream minigame variables
stream_x = 64  -- Stream horizontal position
stream_y = 120 -- Stream vertical position (bottom of screen)
stream_length = 30 -- Current stream length
stream_max_length = 80 -- Maximum stream length
toilet_x = 64  -- Toilet horizontal position
toilet_y = 64  -- Toilet vertical position
toilet_size = 4 -- Toilet sprite size: fixed 32x32 pixels (4x4 tiles)
toilet_hit_time = 0 -- Time spent hitting toilet
toilet_target_time = 600 -- 10 seconds at 60fps
toilet_vel_x = 0 -- Toilet velocity X
toilet_vel_y = 0 -- Toilet velocity Y
toilet_speed = 0.8 -- Base toilet movement speed
minigame_game_length = 5 * 60 -- Mini-game length in seconds

function update_minigame()
    if minigame_timer == 0 then
        -- Mini-game initialization
        minigame_timer = toilet_target_time -- 5 seconds
        toilet_hit_time = 0
        -- Reset toilet position and velocity
        toilet_x = 32 + rnd(64) -- Random x between 32-96
        local min_y = stream_y - stream_max_length -- Top boundary based on MAX stream length
        local max_y = 120 - 32  -- Bottom boundary (32px for toilet sprite)
        toilet_y = min_y + rnd(max_y - min_y) -- Random y within max stream reach
        toilet_size = 4 -- Fixed size: 32x32 pixels (4x4 tiles)
        toilet_vel_x = (rnd(2) - 1) * toilet_speed -- Random velocity based on toilet_speed
        toilet_vel_y = (rnd(2) - 1) * toilet_speed
    end

    minigame_timer -= 1

    -- Move toilet with velocity
    toilet_x += toilet_vel_x
    toilet_y += toilet_vel_y
    
    -- Bounce off screen edges and randomize direction
    if toilet_x <= 8 or toilet_x >= 120 - toilet_size * 8 then
        toilet_vel_x = -toilet_vel_x + (rnd(1) - 0.5) -- Bounce and add randomness
        toilet_x = mid(8, toilet_x, 120 - toilet_size * 8)
    end
    
    -- Y boundary: top limit is MAX stream reach, bottom is screen edge
    local min_y = stream_y - stream_max_length -- Top boundary based on MAX stream length
    local max_y = 120 - toilet_size * 8        -- Bottom boundary (screen edge)
    
    if toilet_y <= min_y or toilet_y >= max_y then
        toilet_vel_y = -toilet_vel_y + (rnd(1) - 0.5) -- Bounce and add randomness
        toilet_y = mid(min_y, toilet_y, max_y)
    end
    
    -- Randomly change direction occasionally
    if rnd(1) < 0.01 then -- 1% chance per frame
        toilet_vel_x += (rnd(2) - 1) * (toilet_speed * 0.25) -- Direction change based on speed
        toilet_vel_y += (rnd(2) - 1) * (toilet_speed * 0.25)
        -- Limit velocity based on toilet_speed
        local max_speed = toilet_speed * 1.5
        toilet_vel_x = mid(-max_speed, toilet_vel_x, max_speed)
        toilet_vel_y = mid(-max_speed, toilet_vel_y, max_speed)
    end
    

    -- Control stream with arrow keys
    if btn(0) then -- Left
        stream_x -= 2
    end
    if btn(1) then -- Right  
        stream_x += 2
    end
    if btn(2) then -- Up
        stream_length = min(stream_max_length, stream_length + 2)
    else
        stream_length = max(10, stream_length - 1)
    end
    
    -- Keep stream on screen
    stream_x = mid(4, stream_x, 124)
    
    -- Check if stream hits toilet
    local stream_top_y = stream_y - stream_length
    local toilet_hit = false
    
    if stream_x >= toilet_x and stream_x <= toilet_x + toilet_size * 8 and
       stream_top_y <= toilet_y + toilet_size * 8 and stream_y >= toilet_y then
        toilet_hit = true
        toilet_hit_time += 1
    end

    -- Check mini-game completion
    if toilet_hit_time >= minigame_game_length then
        -- Success - get money bonus
        money += 200
        minigame_active = false
        minigame_timer = 0
    elseif minigame_timer <= 0 then
        -- Failure - lose liver health
        liver_health -= 500
        minigame_active = false
        minigame_timer = 0
    end
end

function update_payday()
    -- Handle payday logic - salary already credited in update_time()

    -- Apply random bonus at payday
    apply_payday_bonus()

    current_state = game_state.playing
end

-- Function for applying payday bonuses
function apply_payday_bonus()
    for bonus in all(payday_bonuses) do
        if rnd(1) < bonus.chance then
            apply_bonus_effect(bonus)
            break -- only one bonus at a time
        end
    end
end

-- Apply bonus effect
function apply_bonus_effect(bonus)
    if bonus.effect == "heal_liver" then
        liver_health = min(1000 + max_liver_bonus, liver_health + bonus.value)
    elseif bonus.effect == "add_intoxication" then
        intoxication += bonus.value
    elseif bonus.effect == "add_money" then
        money += bonus.value
    elseif bonus.effect == "liver_protection" then
        liver_protection_bonus = bonus.value
        liver_protection_timer = bonus.duration
    elseif bonus.effect == "increase_max_liver" then
        max_liver_bonus += bonus.value
        liver_health += bonus.value -- also restore health
    elseif bonus.effect == "drinking_efficiency" then
        drinking_efficiency_bonus = bonus.value
        drinking_efficiency_timer = bonus.duration
    end
end

function update_game_over()
    -- Handle game over screen
    if btnp(4) then
        -- X button to restart
        -- Reset game state
        money = 267
        liver_health = base_liver_health
        intoxication = 50 -- Start in optimal range
        total_seconds = 0
        frames = 0
        selected_drink_index = 1

        -- Reset bonuses
        liver_protection_bonus = 0
        liver_protection_timer = 0
        drinking_efficiency_bonus = 0
        drinking_efficiency_timer = 0
        max_liver_bonus = 0

        -- Reset wasted protection
        wasted_protection_remaining = wasted_protection_uses
        was_wasted_last_frame = false
        wasted_total_count = 0
        wasted_cycle_count = 0
        wasted_timer = 0

        -- Reset critical protection
        critical_timer = 0
        was_critical_last_frame = false

        -- Reset effects
        blind_timer = 0
        shaking_timer = 0
        slowmotion_timer = 0
        inverted_controls_timer = 0
        chaotic_movement_timer = 0
        blackout_timer = 0
        minigame_active = false
        minigame_timer = 0
        minigame_target = 0
        minigame_progress = 0
        
        -- Reset stream minigame variables
        stream_x = 64
        stream_y = 120
        stream_length = 30
        stream_max_length = 80
        toilet_x = 64
        toilet_y = 64
        toilet_size = 2
        toilet_hit_time = 0
        toilet_vel_x = 0
        toilet_vel_y = 0
        toilet_speed = 0.8

        current_state = game_state.main_menu
    end
end

function update_win()
    -- Handle win screen
    if btnp(4) then
        -- X button to restart
        -- Reset game state (same as game over)
        money = 267
        liver_health = base_liver_health
        intoxication = 50
        total_seconds = 0
        frames = 0
        selected_drink_index = 1

        -- Reset bonuses
        liver_protection_bonus = 0
        liver_protection_timer = 0
        drinking_efficiency_bonus = 0
        drinking_efficiency_timer = 0
        max_liver_bonus = 0

        -- Reset wasted protection
        wasted_protection_remaining = wasted_protection_uses
        was_wasted_last_frame = false
        wasted_total_count = 0
        wasted_cycle_count = 0
        wasted_timer = 0

        -- Reset critical protection
        critical_timer = 0
        was_critical_last_frame = false

        -- Reset effects
        blind_timer = 0
        shaking_timer = 0
        slowmotion_timer = 0
        inverted_controls_timer = 0
        chaotic_movement_timer = 0
        blackout_timer = 0
        minigame_active = false
        minigame_timer = 0
        minigame_target = 0
        minigame_progress = 0
        
        -- Reset stream minigame variables
        stream_x = 64
        stream_y = 120
        stream_length = 30
        stream_max_length = 80
        toilet_x = 64
        toilet_y = 64
        toilet_size = 2
        toilet_hit_time = 0
        toilet_vel_x = 0
        toilet_vel_y = 0
        toilet_speed = 0.8

        current_state = game_state.main_menu
    end
end

function _draw()
    cls()

    if current_state == game_state.main_menu then
        draw_menu()
    elseif current_state == game_state.playing then
        draw_game()
    elseif current_state == game_state.payday then
        draw_payday()
    elseif current_state == game_state.game_over then
        -- draw_game_over()
        draw_game()
    elseif current_state == game_state.win then
        draw_win()
    end
end

function draw_menu()
    print("drunk simulator", 10, 10, 7)
    print("survive 360 seconds", 10, 20, 6)
    print("keep optimal drunk level", 10, 30, 5)
    print("avoid being too sober", 10, 40, 8)
    print("avoid being too drunk", 10, 50, 8)
    print("dont kill your liver", 10, 60, 8)

    -- draw liver
    local liver_x_pixel = 32
    local liver_y_pixel = 8

    -- Convert pixel coordinates to sprite ID (PICO-8 uses 8x8 tiles)
    local sprite_id = (liver_x_pixel / 8) + (liver_y_pixel / 8) * 16

    -- Draw the 16x16 drink sprite (2x2 tiles)
    spr(sprite_id, 10, 65, 2, 2)

    print("left/right select drink", 10, 85, 6)
    print("x interact", 10, 95, 6)
    print("press x to start", 10, 115, 12)
end

function draw_game()
    
    -- Check active mini-game
    if minigame_active then
        draw_minigame()
        return
    end

    local first_row_text_y = 1
    local first_row_sprite_y = 0

    local second_row_text_y = 15
    local second_row_sprite_y = 14

    local third_row_text_y = 25
    local third_row_sprite_y = 24

    -- Main information
    local money_id = 52
    spr(money_id, 5, first_row_sprite_y)
    print(money, 15, first_row_text_y, 7)
    
    -- Salary countdown
    local time_to_salary = salary_frequency - (total_seconds % salary_frequency)
    print("salary in: " .. time_to_salary .. "s", 5, first_row_text_y + 8, 7)

    local time_id = 54
    spr(time_id, 32, first_row_sprite_y)
    print(total_seconds .. "/" .. game_duration, 42, first_row_text_y, 6)

    local liver_healthy_id = 20
    local liver_middle_id = 22
    local liver_ruined_id = 24
    local liver_sprite_id = liver_healthy_id
    if liver_health <= base_liver_health * 0.7 then
        liver_sprite_id = liver_middle_id
    end
    if liver_health <= base_liver_health * 0.5 then
        liver_sprite_id = liver_ruined_id
    end

    spr(liver_sprite_id, 78, first_row_sprite_y, 2, 2)

    print(flr(liver_health) .. "/" .. flr(base_liver_health + max_liver_bonus), 68, second_row_text_y, 8)

    if liver_protection_timer > 0 then
        print("protection: " .. flr(liver_protection_timer / 60) .. "s", 5, second_row_text_y, 11)
    end

    local sober_char_idle_id = 64
    local sober_char_drinking_id = 66

    local medium_char_idle_id = 00
    local medium_char_drinking_id = 02

    local drunk_char_idle_id = 32
    local drunk_char_drinking_id = 34

    local wasted_char_idle_id = 96
    local wasted_char_drinking_id = 98

    local char_sprite_idle_id = sober_char_idle_id
    local char_sprite_drinking_id = sober_char_drinking_id

    if intoxication >= intoxication_optimal_min and intoxication <= intoxication_optimal_max then
        char_sprite_idle_id = medium_char_idle_id
        char_sprite_drinking_id = medium_char_drinking_id
    elseif intoxication >= intoxication_wasted_threshold or wasted_timer > 0 then
        -- Wasted state - very high intoxication or timer active
        char_sprite_idle_id = wasted_char_idle_id
        char_sprite_drinking_id = wasted_char_drinking_id
    elseif intoxication > intoxication_optimal_max then
        char_sprite_idle_id = drunk_char_idle_id
        char_sprite_drinking_id = drunk_char_drinking_id
    else
        char_sprite_idle_id = sober_char_idle_id
        char_sprite_drinking_id = sober_char_drinking_id
    end

    -- Override with blackout sprites if blackout is active
    if blackout_timer > 0 then
        char_sprite_idle_id = wasted_char_idle_id
        char_sprite_drinking_id = wasted_char_drinking_id
    end

    -- Draw character with animation (switches every second)
    local current_char_sprite = char_sprite_idle_id
    if flr(character_animation_timer / 60) % 2 == 1 then
        current_char_sprite = char_sprite_drinking_id
    end

    spr(current_char_sprite, 78, third_row_sprite_y, 2, 2)

    local intox_color = get_intoxication_color()
    print("drunk: " .. flr(intoxication), 68, third_row_sprite_y + 17, intox_color)
    print(get_intoxication_status(intoxication), 68, third_row_sprite_y + 25, intox_color)

    local effect_info_y = third_row_sprite_y + 25

    

    if drinking_efficiency_timer > 0 then
        print("boost: " .. flr(drinking_efficiency_timer / 60) .. "s", 0, effect_info_y - 10, 12)
    end

    -- Status effects
    if shaking_timer > 0 then
        -- Shaking selection - random offset
        print("tremor!", 10, effect_info_y, 8)
    end

    if slowmotion_timer > 0 then
        -- Slowdown
        print("slow!", 10, effect_info_y, 11)
    end

    if inverted_controls_timer > 0 then
        -- Inverted controls
        print("confusion!", 10, effect_info_y, 14)
    end

    if chaotic_movement_timer > 0 then
        -- Chaotic movement
        print("chaotic!", 10, effect_info_y, 13)
    end


    local shop_position_y = third_row_sprite_y + 32
    -- Draw drink sprites in 4x3 grid
    for i = 1, #drinks do
        local col, row
        if i <= 4 then
            -- Top row (drinks 1-4)
            col = i - 1
            row = 0
        else
            -- Bottom row (drinks 5-7)
            col = i - 5
            row = 1
        end

        local display_x = 10 + col * 20 -- 20px spacing between sprites
        local display_y = shop_position_y + row * 20 -- 75px for first row (moved up 20px), 95px for second row

        -- Calculate sprite ID from coordinates you provided
        -- Sprites are at y=64, x positions: 0, 16, 32, 48, 64, 80, 96
        local sprite_x_pixel = (i - 1) * 16 -- 0, 16, 32, 48, 64, 80, 96
        local sprite_y_pixel = 64

        -- Convert pixel coordinates to sprite ID (PICO-8 uses 8x8 tiles)
        local sprite_id = (sprite_x_pixel / 8) + (sprite_y_pixel / 8) * 16

        -- Draw the 16x16 drink sprite (2x2 tiles)
        spr(sprite_id, display_x, display_y, 2, 2)

        -- Highlight selected drink
        if i == selected_drink_index then
            rect(display_x - 1, display_y - 1, display_x + 16, display_y + 16, 10)
        end

        -- Show availability by dimming unavailable drinks
        if money < drinks[i].price then
            fillp(0b0101010110101010)
            rectfill(display_x, display_y, display_x + 15, display_y + 15, 0)
            fillp()
        end
    end

    local drink_info_y = shop_position_y + 42
    -- Show selected drink info below sprites
    local drink = drinks[selected_drink_index]
    local color = money >= drink.price and 11 or 8
    print(drink.name .. " - " .. drink.price .. "r", 5, drink_info_y, color)
    print("drunk+" .. drink.intoxication .. " liver dmg+" .. drink.liver_damage, 5, drink_info_y + 10, 6)

    -- Efficiency progression
    local effectiveness = flr((1 - (tolerance_factor * total_seconds)) * 100)
    local drunk_penalty = get_drunk_penalty()
    local total_effectiveness = flr(effectiveness * drunk_penalty)
    print("efficiency: " .. total_effectiveness .. "%", 5, drink_info_y + 20, 5)

    -- Show wasted cycle info if any cycles completed
    if wasted_cycle_count > 0 then
        local next_damage = wasted_overflow_liver_damage * (wasted_cycle_count + 1)
        print("next wasted dmg: " .. next_damage, 5, drink_info_y + 30, 8)
    end

    -- Active effects
    local y_offset = 55
 
    
    if blind_timer > 0 then
        -- Blindness effect - can't see drinks (hide shop)
        rectfill(5, shop_position_y - 1, 127, 127, 0) -- Cover sprite grid and text (moved up 20px)
        print("blind - cant see shop", 10, 80, 8)
    end

    if blackout_timer > 0 then
        -- Complete black screen during blackout
        cls(0)
        print("blackout", 35, 64, 8)
    end
end

function draw_minigame()
    cls(1) -- Blue background
    print("bathroom emergency!", 20, 5, 7)
    print("hit toilet for 5 seconds!", 15, 15, 8)
    map(0, 0, 0, 32, 16, 10)
    -- Draw toilet sprite (moving and resizing)
    local toilet_sprite_id = 12 -- Assuming sprite 12 is your toilet
    spr(toilet_sprite_id, toilet_x, toilet_y, toilet_size, toilet_size)
    
    -- Draw stream
    if stream_length > 0 then
        local stream_top_y = stream_y - stream_length
        -- Draw yellow stream line
        for i = 0, stream_length do
            pset(stream_x, stream_y - i, 10) -- Yellow color
            -- Add some width to the stream
            if i % 2 == 0 then
                pset(stream_x - 1, stream_y - i, 10)
                pset(stream_x + 1, stream_y - i, 10)
            end
        end
    end
    
    -- Draw UI
    print("time: "..flr(minigame_timer/60).."s", 5, 110, 7)
    print("hit time: "..flr(toilet_hit_time/60).."/"..minigame_game_length.."s", 5, 120, 11)

    local intox_color = get_intoxication_color()
    print("drunk: " .. flr(intoxication), 80, 110, intox_color)
    print(get_intoxication_status(), 80, 120, intox_color)
    -- Visual feedback when hitting toilet
    if stream_x >= toilet_x and stream_x <= toilet_x + toilet_size * 8 and
       (stream_y - stream_length) <= toilet_y + toilet_size * 8 and stream_y >= toilet_y then
        print("hit!", toilet_x, toilet_y - 8, 8)
    end
end

-- Functions for displaying intoxication state
function get_intoxication_color()
    if intoxication <= intoxication_min_threshold then
        return 8 -- Red - dangerously sober
    elseif intoxication >= intoxication_critical or critical_timer > 0 then
        return 8 -- Red - critical intoxication
    elseif intoxication >= intoxication_wasted_threshold or wasted_timer > 0 then
        return 9 -- Orange - "wasted"
    elseif intoxication >= intoxication_optimal_min and intoxication <= intoxication_optimal_max then
        return 11 -- Green - optimal level
    else
        return 6 -- Gray - not optimal, but safe
    end
end

function get_intoxication_status()
    if intoxication <= intoxication_min_threshold then
        return "too sober!"
    elseif intoxication >= intoxication_critical or critical_timer > 0 then
        -- Add critical timer to status
        local timer_seconds = flr(critical_timer / 60)
        if critical_timer > 0 then
            return "critical " .. timer_seconds .. "s"
        else
            return "critical!"
        end
    elseif intoxication >= intoxication_wasted_threshold or wasted_timer > 0 then
        -- Add wasted protection info and timer to status
        local timer_seconds = flr(wasted_timer / 60)
        if wasted_timer > 0 then
            return "wasted " .. wasted_total_count .. "/" .. wasted_protection_uses .. " " .. timer_seconds .. "s"
        else
            return "wasted " .. wasted_total_count .. "/" .. wasted_protection_uses
        end
    elseif intoxication >= intoxication_optimal_min and intoxication <= intoxication_optimal_max then
        return "optimal"
    else
        return "ok"
    end
end


function draw_payday()
    cls(3)
    print("payday!", 35, 50, 7)
    print("salary: " .. salary .. "r", 30, 65, 6)
    print("bonus applied!", 30, 80, 11)
end

function draw_game_over()
    cls(8)
    print("game over", 30, 50, 2)

    -- Determine cause of loss
    if liver_health <= 0 then
        print("liver failure", 25, 65, 7)
    elseif intoxication <= intoxication_min_threshold then
        print("too sober to work", 20, 65, 7)
    elseif intoxication >= intoxication_critical then
        print("alcohol poisoning", 20, 65, 7)
    end

    print("press x to restart", 20, 85, 6)
end

function draw_win()
    cls(11)
    print("you win!", 30, 50, 7)
    print("survived " .. game_duration .. " seconds!", 15, 65, 6)
    print("final score: " .. money .. "r", 25, 75, 12)
    print("press x to restart", 20, 85, 12)
end

-- Helper function for time formatting
function pad_number(num)
    if num < 10 then
        return "0" .. num
    else
        return "" .. num
    end
end

function _draw()
    cls()

    if current_state == game_state.main_menu then
        draw_menu()
    elseif current_state == game_state.playing then
        draw_game()
    elseif current_state == game_state.payday then
        draw_payday()
    elseif current_state == game_state.game_over then
        draw_game_over()
    elseif current_state == game_state.win then
        draw_win()
    end
end

__gfx__
00000bbbbbbb0000000bbbbbbbbbb000000000000046440000000888000990000009a000000fe000007770000000000044444444444444444444444444444444
000bbbbbbbbbb000000baaaaaaabb0000007c0000004400066666666000a9000000820000007c000077777000000000047777777777777777777777777777774
000baaaaaaabb0000bbbbbbbbbbbb000000cc000066666606000066600333300000820000007c000097a79900000000047777777777777777777777777777774
0bbbbbbbbbbbb0000011a11aa11a1100006666000363636066666666034aa440008822000077cd00079797090000000047722227777777ffff57777777777774
0011aaaaaaaa110000aa166aa661aa000068ee00063636306cccccc63444a44400877200007ccd0009a9a9090000000047722227777777ffff57777777777774
00aa11aaaa11aa0000aaaaaaaaaaaa0000888e00037777306c77ccc60aa44aa000877200007ccd00099a9909000000004777777777777722ff57777777777774
00a1aaaaaaaa1a0000aaa1aaaa1aaa0000e8ee00033333306cccccc604a444a000897200007ccd0009a9a990000000004777777777777722ff57777777777774
0aaaa1aaaa1aaaa00aaa11a8a11aaaa000eeee000333333066666666004444000088220000dddd00009990000000000047777777777777555577777777777774
0aaaa1a8aa1aaaa00aaa66a2866aaaa0000000000000000000000000000000000000000000000000000000000000000047777777777777777777777777777774
00aa66a28a66aa0000aaaaaaaaaaaa00000000000000000000000000000000000000000000000000077777777777777047777777777777777777777777777774
00aaaaaaaaaaaa0000ac1aa16aaaaa000000255550000000000025555000000000002898500000000722777ff77777704eeeeeeeeeeeeeeeeeeeeeeeeeeeeee4
0ccaaa1aa1aaa00000ccc1166aaaa0000022ee55552222220022ee555522222200a298a98582828207777772f77777704eeeeeeeeeeeeeeeeeeeeeeeeeeeeee4
0cc0a66116aa00000ccc0666aabb000002ee455eeeeeeeee02ee495eeeee333e09994958e8e83338077777777777777044444455555555555555555555444444
0cc0bb6666bb00000ccabbbbbbbb000002e445444444444002e49a944494434008a89a94449443400eeeeeeeeeeeeee000477466666666666666666666477400
0ccabbbbbbbba0000000bb0bb0bb000002e445444444440002e4494949a944000888494949a94800007766666666770000477466d67676767676766d66477400
0000bb0bb0bb000000000bbbbbbb00002ee44544444440002ee4459a949440009888459a94944000007667777776670000477466d677c7c7c7c7c7dd66477400
00000bbbbbbb000000000bbbbbbb00002e555544444400002e55554944440000a9a8aa494848000000766ff11ff6670000477466d6fcfc1c1cfcffdd66477400
000bbbbbbbbbb000000bbbbbbbbbb0002544454440000000259995aaa0000000988e8aaaa00000000076fff11ff6670000477466d6ffff1111ffffdd66477400
000baaaaaaabb000000baaaaaaabb0000544a555000000000599a555000000000598aa5500000000007667fffff667000047746dddffff1111ffffdd66477400
0bbbbbbbbbbbb0000bbbbbbbbbbbb000054aa00550000000059aa00550000000089aa00a5000000000776677776677000047746fddffff1111ffffdd66477400
0011aaaaaaaa110000011aaaa11aa00005aaa0005500000005aaa0005500000005aaa000aa000000000766666666700000477466ddddffffffffffdd66477400
00a11aaaa11aaa0000166aaaa661aa000aa00000050000000aa00000050000000aa000000500000000007777777700000047746666d7ffffffffffdd66477400
00166aaaa661aa0000aaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000777700000000477466666d77c7c7c7ddd666477400
0aaa1a8aa1aaaaa000aa1a8aa1aaaa00000000000000000000000000000000000000000000000000000000000000000000477444666d7676767d666644477400
0aa1a1881a1aaaa00aa1a1881a1aaa00099999900000000000222200000000000000000000000000000000000000000000477774666666666666666647777400
00a666888666aa000aa666888666aa009aaccca90cccccc002666620000000000000000000000000000000000000000000444774444466666666444447744400
00aaaaaaaaaaaa0000aaaaaaaaaaaa009aacaca90cc88cc026626662000000000000000000000000000000000000000000004777777444666644477777740000
0ccaa61aa16aa000000c16a16aaaa0009acccca90c8cc8c026626662000000000000000000000000000000000000000000004447777774444447777774440000
0cc06661166a000000ccc1166aaa00009aacaaa908cccc8026622262000000000000000000000000000000000000000000000047777777777777777774000000
0cc0bb6666bb00000cccbb66aab000009acccca90cccccc026666662000000000000000000000000000000000000000000000044444477777777444444000000
0ccabbbbbbbba0000cabbbbbbbb000009aacaaa90cccccc002666620000000000000000000000000000000000000000000000000000477777777400000000000
0000bb0bb0bb0000000b0bb0bbb00000099999900000000000222200000000000000000000000000000000000000000000000000000444444444400000000000
00000bbbbbbb000000000bbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bbbbbbbbbb000000bbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000baaaaaaabb000000baaaaaaabb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbbbbbbbbbbb0000bbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00111111a111110000111111a1111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
006666aaaa666600006666aaaa666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaa0000aaaa1a1aaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa111aa111aaa00aaa11aaa11aaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaa1a6aa1aaaa00aaa1aa6a1aaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aa66a66a66aa0000aa66a66a66aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaa0000aaaaaa1aaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ccaaa1111aaa000000ac111aaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0cc0aaaaaaaa0000000cccaaaa6a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0cc0bbaaaabb000000cccbaaaabb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ccabbbbbbbba00000cabbbbbbbba000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000bb0bb0bb00000000bb0bb0bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000bbbbbbb000000000bbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bbbbbbbbbb000000bbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000baaaaaaabb000000baaaaaaabb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbbbbbbbbbbb0000bbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0011aaaaaaaa11000011aaaaaaaa1100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaa0000aaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a1a1aa1a1aaa0000aa1aaaa1aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa1aaaa1aaaaa00aa111aa111aaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa161a8161aaaa00aaa1aa8a1aaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a666a8866aaa0000a666a8866aaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaa11aaaaa0000aaaaa11aaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aac1661caa000000aac16c1caa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000aaaaaaaa00000000ac6116ca0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000bbaaaabb00000000c6c6cc6c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000abbbbbbbba000000a6c6cc6c6a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000baabbaab00000000b6a66a6b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000888888888888888
000000c7cc00000000006666664400000000000000008880000000022000000000000009a000000000000001e000000000000000000000008800000000000088
000000c7cc000000000022224444000000000066666666600000000a90000000000000088000000000000007d000000000007777770000008000000000000008
000000c7cc0000000000002244000000000006606666666000000007700000000000000220000000000000022000000000077777777000008000000000000008
0000eeeeeeee00000000006666000000000066006ccccc600000333333440000000000088000000000000007d000000000777777777700008000000000000008
000eeeeeeeeee0000000666666660000000660006ccccc600003444444444000000000888800000000000077dd00000000979797979700008000000000000008
000eee88ee77e0000006363636366000006600066c777c6000322777777224000000081221800000000007ccccd00000007a7a7a7a7799008000000000000008
000ee8888eeee000000363636363600000600066cc787c6004222222222222400000082772800000000007ccccd000000097a7a7a7a709908000000000000008
000ee8888e77e00000033333333330000066666ccc777c6042aa22aa22aa22240000087227800000000007ccccd00000007a7a7a7a7900908000000000000008
000eee88eeeee0000003377777733000006ccccccccccc604222a222a222a2240000082777800000000007aaaad00000007a7a7a7a7900908000000000000008
000eeeeeee77e0000003377777733000006c7c7c7ccccc604722a222a222a2240000082227800000000007a88ad00000009aaaaaaaa900908000000000000008
000ecccccccce0000003377777733000006cc777ccccc6604722a222a222a2440000082227800000000007ccccd000000097a7a7a7a900908000000000000008
000ecccccc77e0000003333333333000006c77777ccc666004222222222224400000082772800000000007ccccd00000009aaaaaaaa909008000000000000008
000ecccccccce0000003333333333000006cc777ccc6660000444777777433000000082112800000000007ccccd000000099a9a9a9a990008000000000000008
000eeccccccee0000002211111133000006c7c7c7c66600000002444444300000000081111800000000007ccccd0000000099a9a9a9000008800000000000088
0000eeeeeeee0000000022222222000000666666666600000000022223300000000008888880000000000dddddd0000000009999990000000888888888888880
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060606060606060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66066606660666060666066606660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060a06060606060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
066076660666066a6606660666066606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60607760606060006060606060606088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66066606660666060666066600000088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060606060606060606080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06660606066606666606660666066606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060606060606060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66066600660666060666060606660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060446060606060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06960666066446440606660666066606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60996060606444446060606060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66099900660646060606066606660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
606999606060606060606060606a9a60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
066999960666060666060606660a99a6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000060699a60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000066699aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000606aa990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000660699a6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000060696aaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000006660a66000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000066066606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888eeeeee888888888888888888888888888888888888888888888888888888888888888888888888ff8ff8888228822888222822888888822888888228888
8888ee888ee88888888888888888888888888888888888888888888888888888888888888888888888ff888ff888222222888222822888882282888888222888
888eee8e8ee88888e88888888888888888888888888888888888888888888888888888888888888888ff888ff888282282888222888888228882888888288888
888eee8e8ee8888eee8888888888888888888888888888888888888888888888888888888888888888ff888ff888222228888228222888882282888222288888
888eee8e8ee88888e88888888888888888888888888888888888888888888888888888888888888888ff888ff888822228888228222888882282888222288888
888eee888ee888888888888888888888888888888888888888888888888888888888888888888888888ff8ff8888828828888228222888888822888222888888
888eeeeeeee888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
8888811111111ddd11dd11dd1ddd1ddd11111ddd1ddd1dd11ddd11dd1ddd1ddd11111ddd1dd11d111ddd111111dd1ddd1ddd1ddd111111111111111111111111
8888811111111d1d1d1d1d1d111d1d1111111ddd1d1d1d1d1d1d1d111d111d1d111111d11d1d1d111d1111111d111d1d1ddd1d11111111111111111111111111
8ddd8ddd11111dd11d1d1d1d11d11dd111111d1d1ddd1d1d1ddd1d111dd11dd1111111d11d1d1d111dd111111d111ddd1d1d1dd1111111111111111111111111
8888811111111d1d1d1d1d1d1d111d1111111d1d1d1d1d1d1d1d1d1d1d111d1d111111d11d1d1d111d1111111d1d1d1d1d1d1d11111111111111111111111111
8888811111111ddd1dd11dd11ddd1ddd11111d1d1d1d1d1d1d1d1ddd1ddd1d1d11111ddd1ddd1ddd1ddd11111ddd1d1d1d1d1ddd111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111ddd1d1d11111ddd1ddd1ddd1ddd1ddd1d1111dd1d111ddd1ddd11dd111111111111111111111111111111111111111111111111111111111111
1111111111111d1d1d1d11111d111d1d11d111d1111d1d111d1d1d111d1d1d1d1d1d111111111111111111111111111111111111111111111111111111111111
1ddd1ddd11111dd11ddd11111dd11dd111d111d111d11d111d1d1d111ddd1dd11d1d111111111111111111111111111111111111111111111111111111111111
1111111111111d1d111d11111d111d1d11d111d11d111d111d1d1d111d111d1d1d1d111111111111111111111111111111111111111111111111111111111111
1111111111111ddd1ddd11111d111d1d1ddd11d11ddd1ddd1dd11ddd1d111d1d1dd1111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111dd1ddd1ddd1ddd11111d1d1ddd1ddd1ddd1ddd1ddd1d111ddd11dd111111111111111111111111111111111111111111111111111111111111
1111111111111d111d1d1ddd1d1111111d1d1d1d1d1d11d11d1d1d1d1d111d111d11111111111111111111111111111111111111111111111111111111111111
1ddd1ddd11111d111ddd1d1d1dd111111d1d1ddd1dd111d11ddd1dd11d111dd11ddd111111111111111111111111111111111111111111111111111111111111
1111111111111d1d1d1d1d1d1d1111111ddd1d1d1d1d11d11d1d1d1d1d111d11111d111111111111111111111111111111111111111111111111111111111111
1111111111111ddd1d1d1d1d1ddd111111d11d1d1d1d1ddd1d1d1ddd1ddd1ddd1dd1111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
166611661661166616161111111111111cc11ccc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1666161616161611161611111777111111c11c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1616161616161661166611111111111111c11c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1616161616161611111611111777111111c11c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
161616611616166616661111111111111ccc1ccc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
16661166116616661666111111611616166616111666166616161111111111111cc1111111111111111111111111111111111111111111111111111111111111
1616161616161116161111111616166616161616161611611111177711111c111111111111111111111111111111111111111111111111111111111111111111
1661161616161161166111111666161616161616161611611111111111111ccc1111111111111111111111111111111111111111111111111111111111111111
161616161616161116111111161616161616161616161161111117771111111c1111111111111111111111111111111111111111111111111111111111111111
1666166116611666166616661616161616611166161611611111111111111ccc1111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
166116661666166116161666166611661111111111111cc111111111111111111111111111111111111111111111111111111111111111111111111111111111
1616161611611616161616111616161111111777111111c111111111111111111111111111111111111111111111111111111111111111111111111111111111
1616166111611616166116611661166611111111111111c111111111111111111111111111111111111111111111111111111111111111111111111111111111
1616161611611616161616111616111611111777111111c111111111111111111111111111111111111111111111111111111111111111111111111111111111
166616161666161616161666161616611111111111111ccc11111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
166616661666166616661111111111111ccc11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
116111611666161116161111177711111c1c11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
116111611616166116611111111111111c1c11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
116111611616161116161111177711111c1c11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
116116661616166616161111111111111ccc11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
116616611666116616161111161116661616166616111111111111111ccc11111111111111111111111111111111111111111111111111111111111111111111
161116161616161116161111161116111616161116111111177711111c1c11111111111111111111111111111111111111111111111111111111111111111111
166616161616116116611111166616611161161116611111111111111c1c11111111111111111111111111111111111111111111111111111111111111111111
111616161616161116161111161116111666161116111111177711111c1c11111111111111111111111111111111111111111111111111111111111111111111
166116161616116616161666166616661161166616661111111111111ccc11111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__map__
c1c2c2c2d2c2c2c2c2c2c2c2c2c2c2c200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c2c0c2c2c2c2c2c2c2d0d3c2d2c0d2c200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c2d1c2c2c2d2c0d2e3d1c2c2c2c2c200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c2c2c2c2c2c2d2d2c2c2c2c2c2c2c2c200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c2d2d2d2c2c2c2c2d2d1c3c2c2c2d1c200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c2c2d0c1c2c2d2c2d2c2c2c0c2d3d2d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c2c2d2c1d2c3d2c2c2c2c2c2c2c2c0d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c2c2c0d2c2c2c2c0c2c2c0c2c2c2d2d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d2c2d2d2d2d2d2d2d2c2c2c2d2c2d2d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
