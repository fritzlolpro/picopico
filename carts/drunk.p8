pico-8 cartridge // http://www.pico-8.com
version 39

__lua__
-- drunk
-- by fritzlolpro
game_state = {
    main_menu = 0,
    playing = 1,
    payday = 2,
    minigame = 3,
    game_over = 4,
    win = 5
}
-- ⬇️⬆️➡️⬅️🅾️❎
-- Game constants
game_duration = 360 -- Total game duration in seconds
salary = 267 -- Salary amount in rubles per payment
salary_frequency = 30 -- How often salary comes in seconds
-- salary_frequency = 5 -- How often salary comes in seconds
base_liver_health = 2000 -- Initial liver health in units
liver_damage_factor = 0.001833 -- Liver damage growth factor per second (+0.1833% damage each second)
base_sobering_rate = 15 -- Intoxication units lost every SOBERING_FREQUENCY seconds
sobering_acceleration = 0.011667 -- Sobering acceleration over time (+0.01167 units speed each second)
sobering_frequency = 1 -- How often sobering occurs in seconds
tolerance_factor = 0.0015 -- Alcohol effectiveness decrease over time (-0.15% effectiveness each second)
drinking_frequency = 5 -- How often character drinks a shot in seconds

-- Consumption progression constants
liver_damage_per_consumption = 0.01 -- Liver damage increase per consumption (1% per drink)
intoxication_penalty_per_consecutive = 0.05 -- Intoxication effectiveness penalty per consecutive drink (5% per drink)
min_intoxication_effectiveness = 0.2 -- Minimum intoxication effectiveness (20%)
price_increase_per_consumption = 0.1 -- Price increase per consumption (10% per drink)


-- Game variables (initialized in init_game_state())
money = nil
liver_health = nil
intoxication = nil
selected_drink_index = nil
selected_bonus_index = nil
game_over_reason = nil
last_drink_index = nil -- Track last consumed drink for consecutive counting

-- Character animation
character_animation_timer = nil
drinking_animation_trigger = nil
drinking_animation_duration = 60 -- Duration of drinking animation (1 second)

-- Slowmotion effect
slow_motion_multiplier = 4 -- How much slower time goes during slowmotion

-- Wasted protection mechanism
wasted_protection_uses = 3 -- How many times player can be saved from auto-drinking when wasted
wasted_protection_remaining = nil
was_wasted_last_frame = nil
wasted_overflow_liver_damage = 50 -- Base liver damage when entering wasted after protection is exhausted
wasted_total_count = nil
wasted_cycle_count = nil
wasted_duration = 300 -- How long to stay in wasted state (5 seconds at 60fps)
wasted_timer = nil

-- Critical protection mechanism
critical_duration = 600 -- How long to stay in critical state (10 seconds at 60fps)
critical_timer = nil
critical_liver_damage = 500 -- Liver damage when critical timer expires
was_critical_last_frame = nil

-- Intoxication parameters
intoxication_min_threshold = 0 -- Below this - game over
intoxication_optimal_min = 60 -- Optimal range
intoxication_optimal_max = 400 -- Optimal range
intoxication_wasted_threshold = 430 -- "Wasted" - penalties
intoxication_critical = 480 -- Critical level - game over


-- Glitch effect constants
glitch_intoxication_threshold = 100 -- Intoxication level when pixel corruption starts
glitch_medium_threshold = 170 -- Medium intensity pixel corruption
glitch_high_threshold = 250 -- High intensity with chaotic corruption
glitch_max_intensity = 300 -- Maximum glitch intensity

-- Payday bonuses
payday_bonuses = {
    { name = "zakuska", effect = "heal_liver", value = 200, cost = 100, description = "heal liver" },
    { name = "opohmel", effect = "remove_intoxication", value = 150,  cost = 120, description = "feel better" },
    { name = "halturka", effect = "add_money", value = 123,  cost = 0, description = "side hassle" },
    { name = "activated carbon", effect = "liver_protection", value = 0.47, duration = 1800,  cost = 100, description = "protect liver" },
    { name = "ascorbic", effect = "increase_max_liver", value = 189, cost = 100, description = "liver got stronger" },
    { name = "alcoholic training", effect = "drinking_efficiency", value = 0.30, duration = 1800,  cost = 10, description = "become strongman" }
}

-- Temporary bonus effects
liver_protection_bonus = nil
liver_protection_timer = nil
drinking_efficiency_bonus = nil
drinking_efficiency_timer = nil
max_liver_bonus = nil

-- Sobriety protection system
sobriety_timer = nil
sobriety_duration = 600 -- 10 seconds at 60fps (10 * 60)
last_intoxication_check = nil

-- Drink effect functions
function sanitizer_effect()
    -- Shaking selection (frame randomly shifts)
    shaking_timer = 300
    -- 5 seconds at 60fps
end

function cologne_effect()
    -- Slowmotion 4 sec (slow frame movement)
    slowmotion_timer = 600
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
    minigame_timer = 0 -- Reset timer to trigger initialization
    change_state(game_state.minigame)
end

function vodka_effect()
    -- Blackout 2 sec (controls don't work)
    blackout_timer = 360
    -- 2 seconds at 60fps
end

function yorsh_effect()
    -- Chaotic frame (moves randomly)
    chaotic_movement_timer = 480
    if rnd(1, 100) <= 80 then
        change_state(game_state.minigame)
    end
    
end

drinks = {
    {
        name = "sanitizer",
        base_price = 13,
        price = 13,
        intoxication = 85,
        liver_damage = 11,
        effect_chance = 0.20,
        effect_func = sanitizer_effect,
        total_consumed = 0,
        consecutive_consumed = 0
    },
    {
        name = "cologne_shipr",
        base_price = 21,
        price = 21,
        intoxication = 145,
        -- intoxication = 0,
        liver_damage = 11,
        effect_chance = 0.25,
        effect_func = cologne_effect,
        total_consumed = 0,
        consecutive_consumed = 0
    },
    {
        name = "antifreeze",
        base_price = 43,
        price = 43,
        intoxication = 265,
        liver_damage = 13,
        effect_chance = 0.35,
        effect_func = antifreeze_effect,
        total_consumed = 0,
        consecutive_consumed = 0
    },
    {
        name = "cognac_777",
        base_price = 89,
        price = 89,
        intoxication = 160,
        liver_damage = 6,
        effect_chance = 0.08,
        effect_func = cognac_effect,
        total_consumed = 0,
        consecutive_consumed = 0
    },
    {
        name = "beer",
        base_price = 29,
        price = 29,
        intoxication = 65,
        liver_damage = 3,
        effect_chance = 0.20,
        -- effect_chance = 1,
        effect_func = beer_effect,
        total_consumed = 0,
        consecutive_consumed = 0
    },
    {
        name = "vodka",
        base_price = 67,
        price = 67,
        intoxication = 235,
        liver_damage = 7,
        effect_chance = 0.12,
        effect_func = vodka_effect,
        total_consumed = 0,
        consecutive_consumed = 0
    },
    {
        name = "yorsh",
        base_price = 73,
        price = 73,
        intoxication = 305,
        liver_damage = 6,
        effect_chance = 0.30,
        effect_func = yorsh_effect,
        total_consumed = 0,
        consecutive_consumed = 0
    }
}

function init_game_state()
    -- Basic resources
    money = 267
    liver_health = base_liver_health
    intoxication = 230
    selected_drink_index = 1
    selected_bonus_index = 1
    game_over_reason = ""
    last_drink_index = nil -- Track last consumed drink for consecutive counting
    
    -- Time tracking
    total_seconds = 0
    frames = 0
    
    -- Character animation
    character_animation_timer = 0
    drinking_animation_trigger = false
    drinking_animation_duration = 60
    
    -- Wasted protection
    wasted_protection_remaining = wasted_protection_uses
    was_wasted_last_frame = false
    wasted_total_count = 0
    wasted_cycle_count = 0
    wasted_timer = 0
    
    -- Critical protection
    critical_timer = 0
    was_critical_last_frame = false
    
    -- Sobriety protection
    sobriety_timer = 0
    last_intoxication_check = 0
    
    -- Temporary bonus effects
    liver_protection_bonus = 0
    liver_protection_timer = 0
    drinking_efficiency_bonus = 0
    drinking_efficiency_timer = 0
    max_liver_bonus = 0
    
    -- Effect timers
    blind_timer = 0
    hallucination_timer = 0
    blackout_timer = 0
    shaking_timer = 0
    slowmotion_timer = 0
    inverted_controls_timer = 0
    chaotic_movement_timer = 0
    chaotic_last_jump_time = 0
    
    -- Drinking timing (separate from game time to handle slowmotion correctly)
    next_drink_timer = drinking_frequency * 60 -- Convert to frames for precise timing
    
    -- Minigame variables
    minigame_timer = 0
    minigame_target = 0
    minigame_progress = 0
    stream_x = 64
    stream_y = 120
    stream_length = 30
    stream_max_length = 80
    toilet_x = 64
    toilet_y = 64
    toilet_size = 4
    toilet_hit_time = 0
    toilet_vel_x = 0
    toilet_vel_y = 0
    toilet_speed = 0.8
end

-- Function to reset game statistics (drink consumption counters)
function reset_game_stats()
    -- Reset consumption statistics for all drinks
    for i = 1, #drinks do
        drinks[i].total_consumed = 0
        drinks[i].consecutive_consumed = 0
        drinks[i].price = drinks[i].base_price
    end
    
    -- Reset last drink tracking
    last_drink_index = 0
end

-- Function to reset drink prices to base values
function reset_drink_prices()
    for i = 1, #drinks do
        drinks[i].price = drinks[i].base_price
    end
end

function _init()
    -- Initialize game state
    init_game_state()
    reset_game_stats()
    current_state = game_state.main_menu
    
    previous_state = current_state
    music(9)
end

-- Function called once when state changes
function on_state_change(from_state, to_state)
    -- This function is called exactly once when state transitions occur
  
    music(-1)
    if to_state == game_state.minigame then
        music(2)
    end
    if to_state == game_state.playing then
        music(7)
    end
    if to_state == game_state.payday then
        music(8)
    end
    if to_state == game_state.game_over then
        music(10)
    end
    if to_state == game_state.win then
        music(19)
    end
end

-- Check if state has changed and call on_state_change if needed
function check_state_change()
    if current_state != previous_state then
        on_state_change(previous_state, current_state)
        previous_state = current_state
    end
end

-- Helper function to safely change state (optional, for convenience)
function change_state(new_state)
    if current_state != new_state then
        current_state = new_state
        -- check_state_change() will be called on next _update60()
    end
end

function _update60()
    -- Check for state changes
    check_state_change()
    check_game_conditions()
    -- Handle payday state first
    if current_state == game_state.payday then
        update_payday()
        return
    end
    
    -- Update character animation timer (slower during slowmotion)
    if slowmotion_timer > 0 then
        if frames % slow_motion_multiplier == 0 then
            character_animation_timer += 1
        end
    else
        character_animation_timer += 1
    end
    
    -- Update drinking animation trigger
    if drinking_animation_trigger then
        drinking_animation_duration -= 1
        if drinking_animation_duration <= 0 then
            drinking_animation_trigger = false
            drinking_animation_duration = 60 -- Reset for next time
        end
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
    
    -- Update sobriety timer (considering slowmotion)
    if intoxication < intoxication_optimal_min then
        if slowmotion_timer > 0 then
            if frames % slow_motion_multiplier == 0 then
                sobriety_timer += 1
            end
        else
            sobriety_timer += 1
        end
        
        -- Check if timer expired
        if sobriety_timer >= sobriety_duration then
            -- Game over - too sober
            change_state(game_state.game_over)
            game_over_reason = "sobriety is a sin"
        end
    else
        -- Reset timer when not too sober
        sobriety_timer = 0
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
    elseif current_state == game_state.minigame then
        update_minigame()
    elseif current_state == game_state.game_over then
        update_game_over()
    elseif current_state == game_state.win then
        update_win()
    end
end

-- Time variables (initialized in init_game_state())
frames = nil
total_seconds = nil

function update_time()
    -- Don't update time during payday
    if current_state == game_state.payday then
        return
    end
    
    frames += 1
    
    -- Game time always runs at normal speed (60 FPS)
    -- Slowmotion only affects drinking frequency, not game time
    if frames >= 60 then
        frames = 0
        total_seconds += 1

        -- Update wasted protection mechanism
        update_wasted_protection()
        
        -- Update critical protection mechanism
        update_critical_protection()
        
        

        -- Apply sobering (not affected by slowmotion, blocked during blackout and minigame)
        if total_seconds % sobering_frequency == 0 and blackout_timer <= 0 and current_state ~= game_state.minigame then
            update_sobering()
        end
        -- Salary every SALARY_FREQUENCY seconds (not affected by slowmotion)
        if total_seconds % salary_frequency == 0 then
            money += salary
            trigger_payday()
        end
    end
end

-- Effect variables (initialized in init_game_state())
blind_timer = nil
hallucination_timer = nil
blackout_timer = nil
shaking_timer = nil
slowmotion_timer = nil
inverted_controls_timer = nil
chaotic_movement_timer = nil
chaotic_last_jump_time = nil
next_drink_timer = nil -- Timer for next automatic drink (in frames)

-- Update effect timers
function update_effects()
    if blind_timer > 0 then
        blind_timer -= 1
    end

    -- Update drinking timer (affected by slowmotion)
    if current_state == game_state.playing then
        local drink_rate = 1
        if slowmotion_timer > 0 then
            drink_rate = 1 / slow_motion_multiplier -- Slower drinking during slowmotion
        end
        
        next_drink_timer -= drink_rate
        
        -- Check if it's time to drink
        if next_drink_timer <= 0 and can_auto_drink() then
            drink_alcohol()
            drinking_animation_trigger = true
            next_drink_timer = drinking_frequency * 60 -- Reset timer
        end
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
        
        -- Auto-jump to adjacent cell every second
        if total_seconds > chaotic_last_jump_time then
            chaotic_last_jump_time = total_seconds
            -- Jump to adjacent cell
            if rnd(1) < 0.5 then
                selected_drink_index = max(1, selected_drink_index - 1)
            else
                selected_drink_index = min(#drinks, selected_drink_index + 1)
            end
        end
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
        
        -- On the last frame of blackout, apply blackout consequences
        if blackout_timer == 0 then
            -- Set intoxication to wasted threshold
            intoxication = intoxication_wasted_threshold
            -- Halve the money
            money = flr(money / 2)
            -- Damage liver by 10% of current health
            local liver_damage = liver_health * 0.1
            liver_health -= liver_damage
        end
        
        -- During blackout, block drinking and sobering
        return true
    end

    return false
end

-- Function to drink alcohol (referenced in update_time)
function drink_alcohol()
    if #drinks > 0 then
        -- Check if we have enough money
        if money >= drinks[selected_drink_index].price then
            sfx(6)
            consume_drink(drinks[selected_drink_index])
        end
    end
end

-- Function for consuming drink with progression formulas applied
function consume_drink(drink)
    money -= drink.price

    -- Update drink statistics
    drink.total_consumed += 1
    
    -- Update consecutive consumption
    if last_drink_index == selected_drink_index then
        -- Same drink as last time - increment consecutive counter
        drink.consecutive_consumed += 1
    else
        -- Different drink - reset all consecutive counters and start new streak
        for i = 1, #drinks do
            drinks[i].consecutive_consumed = 0
        end
        drink.consecutive_consumed = 1
    end
    
    -- Remember this drink for next time
    last_drink_index = selected_drink_index

    -- Update drink price (increase by percentage each consumption)
    drink.price = drink.base_price * (1 + drink.total_consumed * price_increase_per_consumption)

    -- Apply progression formulas
    local effective_intoxication = calculate_effective_intoxication(drink)
    local effective_liver_damage = calculate_effective_liver_damage(drink)

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
function calculate_effective_intoxication(drink)
    local base_intoxication = drink.intoxication
    local consecutive_consumed = drink.consecutive_consumed
    
    local tolerance_level = tolerance_factor * total_seconds
    local effectiveness = 1 - tolerance_level
    -- Tolerance grows by +0.15% each second, effectiveness decreases accordingly
    
    -- Reduce effectiveness for consecutive consumption of the same drink
    local consecutive_penalty = 1 - ((consecutive_consumed - 1) * intoxication_penalty_per_consecutive)
    consecutive_penalty = max(consecutive_penalty, min_intoxication_effectiveness)
    
    local final_intoxication = base_intoxication * effectiveness * consecutive_penalty

    -- Apply drinking efficiency bonus if active
    if drinking_efficiency_timer > 0 then
        final_intoxication = final_intoxication * (1 - drinking_efficiency_bonus)
    end

    -- Apply penalty for high intoxication
    local drunk_penalty = get_drunk_penalty()
    final_intoxication = final_intoxication * drunk_penalty

    return max(final_intoxication, base_intoxication * 0.1)
    -- minimum 10% effectiveness
end

-- Liver damage increase formula
function calculate_effective_liver_damage(drink)
    local base_damage = drink.liver_damage
    local total_consumed = drink.total_consumed
    
    local damage_multiplier = 1 + (liver_damage_factor * total_seconds)
    -- +0.1833% damage each second
    
    -- Add damage increase for each time this specific drink was consumed
    local consumption_multiplier = 1 + (total_consumed * liver_damage_per_consumption)
    
    local final_damage = base_damage * damage_multiplier * consumption_multiplier

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
        -- Instant game over on liver failure
        change_state(game_state.game_over)
        game_over_reason = "liver is dead"
    elseif total_seconds >= game_duration then
        -- 360 seconds passed - victory
        change_state(game_state.win)
    end
    -- Note: too sober and critical intoxication are now handled by timer mechanisms
    -- in update_sobriety_protection() and critical_timer logic
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
    -- No drinking during blackout
    if blackout_timer > 0 then
        return false
    end
    
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
    -- Only credit salary, don't apply bonus yet
    change_state(game_state.payday)
end

-- Placeholder update functions
function update_menu()
    -- Handle menu input
    if btnp(5) then
        -- X button
        change_state(game_state.playing)
    end
end

function update_game()
    -- Main game logic
    -- Handle drink selection, consumption, etc.

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

    -- Shaking selection - sometimes randomly shifts during input
    if shaking_timer > 0 and rnd(1) < 0.3 then
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

-- Mini-game variables (initialized in init_game_state())
minigame_timer = nil
minigame_target = nil
minigame_progress = nil

-- Stream minigame variables (initialized in init_game_state())
stream_x = nil
stream_y = nil
stream_length = nil
stream_max_length = 80 -- Maximum stream length (constant)
toilet_x = nil
toilet_y = nil
toilet_size = nil
toilet_hit_time = nil
toilet_target_time = 2 * 60 -- Target time to hit toilet in frames (2 seconds)
toilet_vel_x = nil
toilet_vel_y = nil
toilet_speed = 0.8 -- Base toilet movement speed (constant)
minigame_game_length = 15 * 60 -- Total mini-game length: 15 seconds in frames (constant)
minigame_sobriety_reduction = 0.2 -- Reduce sobriety by 20% after completing minigame

function update_minigame()
    if minigame_timer == 0 then
        -- Mini-game initialization
        minigame_timer = minigame_game_length -- Set total game time
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
    else
        -- Reset hit time when not hitting (must be continuous)
        toilet_hit_time = 0
    end

    -- Check mini-game completion
    if toilet_hit_time >= toilet_target_time then
        -- Success - player hit continuously for required time
        liver_health += 100
        -- Reduce sobriety after completing minigame
        intoxication -= intoxication * minigame_sobriety_reduction
        minigame_timer = 0
        change_state(game_state.playing)
    elseif minigame_timer <= 0 then
        -- Failure - lose liver health
        
        liver_health -= 200
        -- Reduce sobriety after completing minigame (even on failure)
        intoxication -= intoxication * minigame_sobriety_reduction
        minigame_timer = 0
        change_state(game_state.playing)
    end
end

function update_payday()
    -- Handle bonus selection with arrow keys
    if btnp(0) then -- Left
        selected_bonus_index = max(1, selected_bonus_index - 1)
    elseif btnp(1) then -- Right
        selected_bonus_index = min(#payday_bonuses, selected_bonus_index + 1)
    elseif btnp(2) then -- Up
        selected_bonus_index = max(1, selected_bonus_index - 3)
    elseif btnp(3) then -- Down
        selected_bonus_index = min(#payday_bonuses, selected_bonus_index + 3)
    elseif btnp(5) then
        -- X button to apply selected bonus
        local selected_bonus = payday_bonuses[selected_bonus_index]
        if money >= selected_bonus.cost then
            money -= selected_bonus.cost
            apply_bonus_effect(selected_bonus)
        end
        -- Reset drink prices for new payday period
        reset_drink_prices()
        change_state(game_state.playing)
    end
end

-- Apply bonus effect
function apply_bonus_effect(bonus)
    if bonus.effect == "heal_liver" then
        liver_health = liver_health + bonus.value
    elseif bonus.effect == "remove_intoxication" then
        intoxication -= bonus.value
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
    if btnp(5) then
        -- X button to restart
        init_game_state()
        reset_game_stats()
        change_state(game_state.playing)
    end
end

function update_win()
    -- Handle win screen
    if btnp(5) then
        -- X button to restart
        init_game_state()
        reset_game_stats()
        change_state(game_state.playing)
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
    elseif current_state == game_state.minigame then
        draw_minigame()
    elseif current_state == game_state.game_over then
        draw_game_over()
        -- draw_game()
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
    -- ⬇️⬆️➡️⬅️🅾️❎
    print("⬇️⬆️➡️⬅️ select drink", 10, 85, 6)
    print("❎ interact", 10, 95, 6)
    print("press ❎ to start", 10, 115, 12)
end

-- Individual glitch effect functions (call during draw phase)
function glitch_screen_shake(intensity)
    -- Screen shake effect - call before main drawing
    if rnd(1) < intensity * 0.3 then
        camera(rnd(4) - 2, rnd(4) - 2)
    end
end

function glitch_palette_corruption(intensity)
    -- Random palette corruption - call before main drawing
    if rnd(1) < intensity * 0.1 then
        for i = 0, 15 do
            pal(i, flr(rnd(16)))
        end
    end
end

function glitch_scanlines(intensity)
    -- Random horizontal lines - call after main drawing
    if rnd(1) < intensity * 0.2 then
        for i = 1, 3 do
            local y = flr(rnd(128))
            local color = flr(rnd(16))
            line(0, y, 128, y, color)
        end
    end
end

function glitch_pixel_corruption(intensity)
    -- Enhanced pixel corruption based on intoxication thresholds
    -- Uses global constants for progression boundaries
    
    -- Determine current intoxication level for different effects
    local is_medium = intoxication >= glitch_medium_threshold
    local is_high = intoxication >= glitch_high_threshold
    
    -- Base corruption - happens more often at higher levels
    local base_chance = is_high and 0.6 or (is_medium and 0.4 or 0.2)
    if rnd(1) < intensity * base_chance then
        local pixel_count = flr(intensity * (is_high and 20 or (is_medium and 15 or 8))) + 2
        for i = 1, pixel_count do
            local x = flr(rnd(128))
            local y = flr(rnd(128))
            
            -- Prefer bright, noticeable colors for drunk effect
            local bright_colors = {7, 10, 9, 8, 12, 14, 15}
            local color = bright_colors[flr(rnd(#bright_colors)) + 1]
            
            pset(x, y, color)
        end
    end
    
    -- Additional chaotic corruption only at high threshold
    if is_high and rnd(1) < 0.3 then
        for i = 1, flr(intensity * 12) do
            local x = flr(rnd(128))
            local y = flr(rnd(128))
            local color = flr(rnd(16)) -- Any random color for chaos
            pset(x, y, color)
        end
    end



  
end

function glitch_screen_inversion(intensity)
    -- Full screen color inversion - call after main drawing
    if rnd(1) < intensity * 0.05 then
        for x = 0, 127 do
            for y = 0, 127 do
                local current_color = pget(x, y)
                pset(x, y, 15 - current_color)
            end
        end
    end
end

function glitch_reset_effects()
    -- Reset camera and palette - call at end of draw phase
    camera(0, 0)
    pal()
end

function before_draw_game()
    -- No pre-draw glitch effects for intoxication
    -- Other glitch effects can be called manually for specific events
    
    if shaking_timer > 0 then
        -- Apply screen shake effect for specific events
        glitch_screen_shake(1.0)
    end

    if slowmotion_timer > 0 then
        -- Apply slow-motion effect (e.g. draw at half speed)
        if frames % slow_motion_multiplier == 0 then
            glitch_palette_corruption(1)
            return
        end
    end
end


function after_draw_game()
    -- Calculate glitch intensity based on intoxication level
    local glitch_intensity = 0
    if intoxication > glitch_intoxication_threshold then
        glitch_intensity = min(1, (intoxication - glitch_intoxication_threshold) / (glitch_max_intensity - glitch_intoxication_threshold))
    end
    
    -- Apply post-draw glitch effects
    if glitch_intensity > 0 then
        glitch_pixel_corruption(glitch_intensity)
    end

    if blackout_timer > 0 then
        -- Apply blackout effect
        glitch_screen_inversion(1.0)
    end

    if wasted_timer > 0 and rnd(1) <= 0.5 then
        -- Apply additional glitch effects when wasted
        glitch_scanlines(1.0)
    end

    -- Always reset effects at the end
    glitch_reset_effects()
end

-- Draw drinking fireworks effect
function draw_drinking_fireworks(center_x, center_y)
    -- Create white pixel fireworks during drinking animation
    local fireworks_intensity = (60 - drinking_animation_duration) / 60 -- Intensity grows over time
    local particle_count = flr(fireworks_intensity * 12) + 3 -- 3-15 particles
    
    for i = 1, particle_count do
        -- Random angle and distance for each particle
        local angle = rnd(1) * 6.28 -- Random angle (0 to 2π)
        local distance = fireworks_intensity * 20 + rnd(10) -- Distance grows with time
        
        -- Calculate particle position
        local px = center_x + cos(angle) * distance
        local py = center_y + sin(angle) * distance
        
        -- Only draw if particle is on screen
        if px >= 0 and px < 128 and py >= 0 and py < 128 then
            -- White particles with occasional bright colors
            local color = 7 -- Default white
            if rnd(1) < 0.2 then
                color = 10 -- Occasional yellow for variety
            end
            pset(px, py, color)
        end
    end
end

function draw_game()
    before_draw_game()
    local first_row_text_y = 1
    local first_row_sprite_y = 0

    local second_row_text_y = 15
    local second_row_sprite_y = 14

    local third_row_text_y = 25
    local third_row_sprite_y = 24

    -- Main information
    local money_id = 52
    spr(money_id, 5, first_row_sprite_y)
    print(flr(money), 15, first_row_text_y, 7)

    -- Salary countdown
    local time_to_salary = salary_frequency - (total_seconds % salary_frequency)
    print("salary in: " .. time_to_salary .. "s", 5, first_row_text_y + 8, 7)
    
    -- Next sip countdown (uses frame-based timer for slowmotion accuracy)
    local time_to_sip = max(0, flr(next_drink_timer / 60))
    print("sip in: " .. time_to_sip .. "s", 5, first_row_text_y + 16, 6)

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
        print("protection: " .. flr(liver_protection_timer / 60) .. "s", 5, third_row_text_y, 11)
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

    -- Draw character with animation
    local current_char_sprite = char_sprite_idle_id
    
    -- Check if currently in wasted state
    local is_wasted = intoxication >= intoxication_wasted_threshold or wasted_timer > 0
    
    if is_wasted then
        -- Wasted state: use old timer-based animation (every second)
        if flr(character_animation_timer / 60) % 2 == 1 then
            current_char_sprite = char_sprite_drinking_id
        end
    else
        -- Non-wasted state: synchronized with drinking
        if drinking_animation_trigger then
            current_char_sprite = char_sprite_drinking_id
        end
    end

    spr(current_char_sprite, 78, third_row_sprite_y, 2, 2)
    
    -- Draw drinking fireworks effect during drinking animation
    if drinking_animation_trigger then
        draw_drinking_fireworks(78 + 8, third_row_sprite_y + 8) -- Center of character sprite
    end

    local intox_color = get_intoxication_color()
    print("drunk: " .. flr(intoxication), 68, third_row_sprite_y + 17, intox_color)
    print(get_intoxication_status(intoxication), 68, third_row_sprite_y + 25, intox_color)

    local effect_info_y = third_row_sprite_y + 25

    

    if drinking_efficiency_timer > 0 then
        print("boost: " .. flr(drinking_efficiency_timer / 60) .. "s", 6, effect_info_y - 10, 12)
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
    print(drink.name .. " - " .. flr(drink.price) .. "r", 5, drink_info_y, color)
    
    -- Calculate effective values for display (without modifying drink object)
    local effective_intoxication = calculate_effective_intoxication(drink)
    local effective_liver_damage = calculate_effective_liver_damage(drink)
    
    print("drunk+" .. flr(effective_intoxication) .. " liver dmg+" .. flr(effective_liver_damage), 5, drink_info_y + 10, 6)

    -- Tolerance progression (grows over time)
    local tolerance_level = flr((tolerance_factor * total_seconds) * 100)
    local drunk_penalty = get_drunk_penalty()
    local total_tolerance = flr(tolerance_level * drunk_penalty)
    print("tolerance: " .. total_tolerance .. "%", 5, drink_info_y + 20, 5)

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

    after_draw_game()
end

function after_draw_minigame()
    
    glitch_palette_corruption(0.5) -- Apply palette corruption effect
    glitch_scanlines(0.5) -- Apply scanlines effect
    glitch_pixel_corruption(0.5) -- Apply pixel corruption effect
    glitch_screen_inversion(0.5) -- Apply screen inversion effect


    glitch_reset_effects() -- Reset camera and palette after mini-game drawing
end

function before_draw_minigame()
    glitch_screen_shake(1) -- Apply screen shake effect
end

function draw_minigame()
    before_draw_minigame()
    cls(1)
    print("bathroom emergency!", 20, 5, 7)
    print("hit toilet for " .. flr(toilet_target_time/60) .. " seconds!", 15, 15, 8)
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
    print("hit time: "..flr(toilet_hit_time/60).."/"..flr(toilet_target_time/60).."s", 5, 120, 11)

    local intox_color = get_intoxication_color()
    print("drunk: " .. flr(intoxication), 80, 110, intox_color)
    print(get_intoxication_status(), 80, 120, intox_color)
    -- Visual feedback when hitting toilet
    if stream_x >= toilet_x and stream_x <= toilet_x + toilet_size * 8 and
       (stream_y - stream_length) <= toilet_y + toilet_size * 8 and stream_y >= toilet_y then
        print("hit!", toilet_x, toilet_y - 8, 8)
    end
    after_draw_minigame()
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
    if intoxication < intoxication_optimal_min then
        -- Always show sobriety timer when below optimal minimum
        local remaining_time = flr((sobriety_duration - sobriety_timer) / 60)
        return "too sober " .. remaining_time .. "s"
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
    cls(0)
    print("payday!", 35, 10, 7)
    print("salary: " .. salary .. "r", 30, 20, 6)
    print("money: " .. flr(money) .. "r", 30, 30, 7)

    -- Draw bonus icons in 3x2 grid
    local start_x = 20
    local start_y = 45
    local icon_spacing = 30
    
    for i = 1, #payday_bonuses do
        local bonus = payday_bonuses[i]
        local col = (i - 1) % 3
        local row = flr((i - 1) / 3)
        local x = start_x + col * icon_spacing
        local y = start_y + row * icon_spacing
        
        -- Draw bonus icon (sprites 68-73)
        local icon_id = 67 + i -- sprites 68-73
        spr(icon_id, x, y)
        
        -- Draw cost below icon
        print(bonus.cost .. "r", x, y + 10, 6)
        
        -- Draw selection cursor
        if i == selected_bonus_index then
            rect(x - 1, y - 1, x + 8, y + 8, 7)
        end
        
        -- Show if player can't afford
        if money < bonus.cost then
            print("x", x + 2, y + 2, 8)
        end
    end
    
    -- Instructions
    print("⬇️⬆️➡️⬅️ select, ❎ buy", 5, 96, 7)
    
    -- Show selected bonus info
    local selected_bonus = payday_bonuses[selected_bonus_index]
    print(selected_bonus.name, 5, 102, 11)
    print(selected_bonus.description, 5, 108, 6)
end

function draw_game_over()
    cls(8)
    print("you died", 10, 50, 2)

    -- Display the reason stored in game_over_reason
    if game_over_reason != "" then
        print(game_over_reason, 10, 65, 7)
    end
    -- ⬇️⬆️➡️⬅️🅾️❎
    print("press ❎ to restart", 10, 85, 6)
end

function draw_win()
    cls(11)
    print("you win!", 30, 50, 7)
    print("survived another drunkard year", 0, 65, 6)
    
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
    elseif current_state == game_state.minigame then
        draw_minigame()
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
00000bbbbbbb000000000bbbbbbb0000000000000067600000000000009999000000000000000000000000000000000000000000000000000000000000000000
000bbbbbbbbbb000000bbbbbbbbbb000000444000676760000444400077766e0009bb0000022dd00000000000000000000000000000000000000000000000000
000baaaaaaabb000000baaaaaaabb00000eee34009797900050000500716166009aa960002222dd0000000000000000000000000000000000000000000000000
0bbbbbbbbbbbb0000bbbbbbbbbbbb0000ee7ee3f09a7a999b44a944b071111609baba9600005d000000000000000000000000000000000000000000000000000
00111111a111110000111111a11111004ef7fef309aaa909454a9444071666609abaa9600005d000000000000000000000000000000000000000000000000000
006666aaaa666600006666aaaa6666004eefee3009aaa90945444444071116609babbaaa0005d000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaa0000aaaa1a1aaaaa0055eee30009aaa9908555555806161660ba99aaa203333dd0000000000000000000000000000000000000000000000000
0aaa111aa111aaa00aaa11aaa11aaaa0005f300000999000b888888b0555555009aaaa0000333300000000000000000000000000000000000000000000000000
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
__sfx__
000400001832018331183412435230312003000030000300183201833118341243523031200300003000030018320183311834124352303120030000300003001832018331183412435230312003000030000300
0005000016714177100c7201a7301c7301f73021730237301a7301d7302273036720357103f71526700287002a7002d70032700367003c7003f70025700277002a7002c7002e7003270035700397003d70000700
00010000085101051014510185101b5101d5101d5101d5101d5101d5101b51018510145100f5100d5100a5100951008510095100a5100e51012510165101d510235102c5002e5003250035500395003d50000500
000200001e7631e7531f7431f733237232a713007030f7031d7331e733207332271325713297131e7031d7030f7231072312723177131a7131e713237032170313713167131a7131d71321713277131270310703
000900000017500165001550014500135001250217502125031750315503135031150017500155001350011506105061050610506105061050610506105061050610506105061050610506105061050610506105
000200000a5170b517085270e537105371353715537175370e5371153716537225271d5171751710557285072a5072d50732507365073c5073f50725507275072a5072c5072e5073250735507395073d50700507
9505000017745177451674514745117350e7350a7350672502725007150b705007050770504705017050070500705007050070501705017050270502705157051370514705167051770518705197051b7051d705
010400001657511575095750457515565125650b565085650456500565125550c5550455500555105450d5450654502545005450d535095350353500535005350952505525015250052506515045150051500515
010200002f2662d25629246262362422621216122060f20623236212361d2361a21618216152161e2061d20623526215261d5261a5161851615516232062120623716217161d7161a71618716157161220610206
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2e0e000013045130251301513015252251b0051f0251b005370050f005130351b0052f7251b005180151b00513045130251301513015397251b0051f0251b005370050f005130351b005252251b005180151b005
d50500000f5450f5250f5450f5251b5451b5251b5451b5250f5350f5150f5350f5151b5351b5151b5351b5150f5250f5150f5250f5151b5251b5151b5251b5150f5150f5050f5150f5050f5150f5050f5151b505
010700000a5450a5250a5450a525165451652516545165250a5350a5150a5350a515165351651516535165150a5250a5150a5250a515165251651516525165150a5150a5050a5150a50516515165051651516505
010700000c5450c5250c5450c525185451852518545185250c5350c5150c5350c515185351851518535185150c5250c5150c5250c515185251851518525185150c5150c5050c5150c50518515185051851518505
010700000554505525055450552511545115251154511525055350551505535055151153511515115351151505515055050551505505115151150511515115050550505505055050550511505115051150511505
010e00003002430032300423004230032300112d0412d0422d0422d0422d0422d0422d0322d0322d0222d0122f0412f0322f0422f0422f0322f01230042300423004230042320423204132031320323202232012
010e00003405532055300552f0552d0452b0452904528045260352403523035210351f0251d0251c0251a02523055230452303523025230152301523015230152301523015230152301523015230152301523015
010e00001c055260552405523055210451f0451d0451c0451a0351803517035150351302511025100150e01520075210752307524075210652306524055260552026521265232552425521245232352422526215
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01090000297752977529755297552974529735297252972529715297152b7752b7752b7552b7552b7452b7352b7252b7252b7152b7152d7752d7752d7552d7552d7452d7352d7252d7252d7152d7152d7052d715
230800003a7523a7323a7223a71539752397323972239715377523774237732377223771237715357523573539752397323972239715377523773237722377153575235732357223571533752337323372233715
930a000037652376323762237615356523563235622356153365233625326523263232622326153565235642356323562235612356153560235612356023561500602006021a6020060232652326253065230625
d60b00002e2522e2322e2222e21530252302323022230215322523223232222322153325233232332223321530252302323022230215322523223232222322153325233225352523524235232352223522235215
0e0a00003565235632356223561537652376323762237615396523962537652376323762237615356523564235632356223562235615356523563235622356153765237632376223761539652396323962239615
01070000355523553235522355153755237532375223751539552395253555235542355323552235512355123a5523a5323a5223a515355523553235522355153755237532375223751538552385323852238515
0107000039552395323952239515293222934129332293222b3222b3412b3322b3222c3222c3412c3322c3222d3322d3412d3322d322355523553235522355153755237532375223751539552395323952239515
010700003a5523a5323a5223a515293222934129332293222b3222b3412b3322b3222d3222d3412d3322d3222e3222e3412e3322e322355523553235522355153755237532375223751539552395323952239515
010700003c5523c5323c5223c512293222934129332293222b3222b3412b3322b3222d3222d3412d3322d32230322303413033230322355523553235522355153755237532375223751539552395323952239515
010700003e5523e5323e5223e515293222934129332293222b3222b3412b3322b3222d3222d3412d3322d322323223234132332323223a5523a5323a5223a5153c5523c5323c5223c5153e5523e5323e5223e515
110a00003f3523f3323f3023f3123f3523f3323f3223f312333023f312003003f3123f3523f3323f3223f312323023f312003003f3123e3523e3323e3023e3123c3523c3323c3223c312323023c312323023c312
010700003e7523e7423e7323e7323e7223e7223e7123e712327023e712007003e715327023e702007003e70232702007000070000700327020070000700007003e7523e7423e7323e7323e7223e7123e7023e712
010700003c7523c7423c7423c7323c7323c7223c7123c712377023c712007003c7153775237742377423773237732377223771237712007003771200700377153e7523e7323e7223e712327023e712007003e715
000700003c7523c7423c7423c7323c7323c7223c7223c712007003c712007003c7120070000700007000070000700007000070000700357523573235722357153775237732377223771538752387323872238715
010700003c7523c7423c7423c7323c7323c7223c7223c712375023c712000003c71535552355323552235512375023551200000355153e5523e5323e5023e5153c5523c5323c5023c5153e5523e5323e5023e512
010700003a7523a7423a7423a7323a7323a7223a7223a712357023a712007003a7150070000700007000070037702007000070000700355523553235522355153755237532375223751539552395323952239515
010900001177211772117521175211742117321172211722117121171513772137721375213752137421373213722137221371213715157721577215752157521574215732157221572215712157122d70215715
010500000a5500a5300a51000500165501653016510005000a5500a5300a51000500165501653016510005000a5500a5300a51000500165501653016510005000a5500a5300a5100050016550165301651000500
8e0b00000735007330073100030013350133301331000300073500733007310003001335013330133100030007350073300731000300133501333013310003000735007330073100030013350133301331000300
01070000057500573005710007001375013730137100070014750147301471000700157501573015710007000a7500a7300a71000700167501673016710007000a7500a7300a7100070016750167301671000700
010700000975009730097100c700157501573015710007000975009730097100c700157501573015710007000975009730097100c700157501573015710007000975009730097100c70015750157301571000700
010700000975009730097100070015750157301571000700097500973009710007001575015730157100070009750097300971000700157501573015710007000975009730097100070015750157301571000700
010700000a7500a7300a71000700167501673016710007000a7500a7300a71000700167501673016710007000a7500a7300a7100070011750117301171000700187501873018710007001a7501a7301a71000700
010a0000037500373003710007000f7500f7300f71000700037500373003710007000f7500f7300f71000700037500373003710007000f7500f7300f71000700037500373003710007000f7500f7300f71000700
01070000007500073000710007000c7500c7300c71000700007500073000710007000c7500c7300c71000700007500073000710007000c7500c7300c71000700007500073000710007000c7500c7300c71000700
010700000575005730057100070011750117301171000700057500573005710007001175011730117100070005750057300571000700117501173011710007001375013730137100070014750147301471000700
010700000a7500a7300a71000700167501673016710007000a7500a7300a71000700167501673016710007000a7500a7300a71000700117501173011710007001375013730137100070015750157301571000700
590500002776527765277552775527745277452773527735277252772527715277152776527755277552774527735277252772527715267652675526745267352476524755247552474524745247352472524715
010700002676526755267452673527765277552774527735277652775527745277352976529755297452973522765227552274522735227252272522715227152271522705227152270522715227052270522705
010700002476524765247552475524745247452473524735247252472524715247151f7651f7551f7451f7351f7251f7251f7251f7151f7151f7051f7151f7052676526755267452673526725267252671526715
010400002476224765247622476524752247552475224755247422474524742247452473224735247322473524722247252472224725247222472524722247252472224725247222472524712247152471224715
0108000033055330322e0552e0322b0552b03227055270322e0552e0322b0552b0323305533032270552703233055330322e0552e0322b0552b03227055270322e0552e0322b0552b03233055330322705527032
010800002e0552e032290552903226055260322205522032290552903226055260322e0552e03222055220322e0552e032290552903226055260322205522032290552903226055260322e0552e0322205522032
01100000215551d555215551d555215551d5551f55521555225551f555225551f555225551f55521555225552455521555245552155524555215552255524555225551f555225551f555225551f5552155522555
011000000503511055050351105505035110550503511055070351305507035130550703513055070351305509035150550903515055090351505509035150550a035160550a035160550a035160550a03516055
010e0000091550912515155151250c1350c1251013510115091550912515155151250c1350c12510135101150415504125101551012507135071250b1350b1150415504125101551012507135071250b1350b115
010e00000e1550e1251a1551a125111351112515135151150e1550e1251a1551a1251113511125151351511510155101251c1551c1251313513125171351711510155101251c1551c12513135131251713517115
010e00000e1550e1251a1551a125111351112515135151150e1550e1251a1551a12511135111251513515115091550912515155151250d1350d12513135131150915509125111551112509135091251013510115
010e00000c1750c1251817518125101651012513135131150c1750c12516175161251516515125111351111510175101251317513125151651512517135171151017510125161751612515165151251313513155
010e0000243752434524345243352434524325213652133521345213352134521325213452132521325213152336523335233452333523355233251f3451f3351f3351f3151f3551f3151a3551a3150e3350e315
010e00001d0751d0551d0451d0350c0550c0251f0751f0451f0451f0350c0550c015210652103521035210151c0651c0651c0451c03510055100151c0751c0551c0351c0151c0551c01510045100151002510015
010e0000240652406524045240351835518325210652106521045210452103521035152551522521045210152306523065230452303517455174251f0651f0651f0451f0451f0351f03513255132250706507035
010e00001d0751d0551d0451d0350c2650c2351f0751f0751f0451f0350c3650c335210652104521265212351c0651c0651c0451c03510465104451c0651c0551c0351c01510265102351c0551c0151045510435
010e00001d0751d0751d0451d0350c4650c4451f0751f0751f0451f0350c2650c2352107521045211652113520065200452005520035143451432521065210652116521135210452101523265232351706517025
__music__
00 41424344
00 41424344
03 2f0c4304
00 300d4344
04 310e4304
07 320f4344
03 14244344
03 5565430b
03 16254344
03 17264344
03 18264344
00 15254344
00 16254344
00 17264344
00 19274344
03 1a284344
03 1b254344
03 1c294344
03 1d2a4344
03 1e2b4344
00 1f254344
00 202c4344
00 212d4344
00 1a284344
00 1b254344
00 1c294344
00 1d2a4344
00 1e2b4344
00 1f254344
00 222c4344
02 232e4344
00 41424344
00 35364344
00 35364344
00 41424344
01 373d7f0b
00 373c510b
00 383e7f0b
00 393f7f0b
00 373d3b0b
00 373c110b
00 383e110b
02 393f120b
02 7a424344
00 7a424344

