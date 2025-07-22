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

-- Игровые константы
game_duration = 360          -- Общая продолжительность игры в секундах
salary = 267                 -- Размер зарплаты в рублях за один раз
salary_frequency = 30        -- Как часто приходит зарплата в секундах
base_liver_health = 2000     -- Начальное здоровье печени в единицах
liver_damage_factor = 0.001833    -- Коэффициент роста урона печени по времени (+0.1833% урона каждую секунду)
base_sobering_rate = 3       -- Единицы опьянения, теряемые каждые SOBERING_FREQUENCY секунд
sobering_acceleration = 0.011667   -- Ускорение отрезвления по времени (+0.01167 единицы скорости каждую секунду)
sobering_frequency = 1       -- Как часто происходит отрезвление в секундах
tolerance_factor = 0.0015    -- Снижение эффективности алкоголя по времени (-0.15% эффективности каждую секунду)
drinking_frequency = 5       -- Как часто персонаж выпивает стопку в секундах

-- Базовые ресурсы
money = 267
liver_health = base_liver_health
intoxication = 50

-- Параметры опьянения
intoxication_min_threshold = 0   -- Ниже - проигрыш
intoxication_optimal_min = 40     -- Оптимальный диапазон
intoxication_optimal_max = 70     -- Оптимальный диапазон
intoxication_drunk_threshold = 80 -- "В хлам" - штрафы
intoxication_critical = 100       -- Критический уровень - проигрыш

-- Бонусы при получке
payday_bonuses = {
  {name = "zakuska", effect = "heal_liver", value = 173, chance = 0.2},
  {name = "opohmel", effect = "add_intoxication", value = 37, chance = 0.15},
  {name = "halturka", effect = "add_money", value = 123, chance = 0.25},
  {name = "activated_carbon", effect = "liver_protection", value = 0.47, duration = 1800, chance = 0.15}, -- 30 сек
  {name = "ascorbic", effect = "increase_max_liver", value = 189, chance = 0.1},
  {name = "alcoholic_training", effect = "drinking_efficiency", value = 0.31, duration = 1800, chance = 0.15} -- 30 сек
}

-- Временные эффекты бонусов
liver_protection_bonus = 0
liver_protection_timer = 0
drinking_efficiency_bonus = 0
drinking_efficiency_timer = 0
max_liver_bonus = 0

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
    selected_drink = 1 -- Для выбора напитков
end

function _update60()
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
  if frames >= 60 then
    frames = 0
    total_seconds += 1
    
    -- Автоматическое употребление алкоголя каждые DRINKING_FREQUENCY секунд
    if total_seconds % drinking_frequency == 0 then
      drink_alcohol()
    end
    
    -- Зарплата каждые SALARY_FREQUENCY секунд
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
shaking_timer = 0        -- Для эффекта "дрожь выбора"
slowmotion_timer = 0     -- Для эффекта замедления
inverted_controls_timer = 0  -- Для инверсии управления
chaotic_movement_timer = 0   -- Для хаотичного движения рамки

-- Drink effect functions
function sanitizer_effect()
  -- Дрожь выбора (рамка случайно сдвигается)
  shaking_timer = 300  -- 5 seconds at 60fps
end

function cologne_effect()
  -- Замедление 4 сек (медленное движение рамки)
  slowmotion_timer = 240  -- 4 seconds at 60fps
end

function antifreeze_effect()
  -- Слепота 5 сек (не видно напитки)
  blind_timer = 300  -- 5 seconds at 60fps
end

function cognac_effect()
  -- Инверсия управления 6 сек (↑=↓, ←=→)
  inverted_controls_timer = 360  -- 6 seconds at 60fps
end

function beer_effect()
  -- Мочегонный эффект (пауза на мини-игру)
  minigame_active = true
end

function vodka_effect()
  -- Блэкаут 2 сек (управление не работает)
  blackout_timer = 120  -- 2 seconds at 60fps
end

function yorsh_effect()
  -- Хаотичная рамка (движется случайно)
  chaotic_movement_timer = 480  -- 8 seconds at 60fps
end

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
  
  -- Применяем падение опьянения
  update_sobering()
  
  return false
end

-- Function to drink alcohol (referenced in update_time)
function drink_alcohol()
  if #drinks > 0 then
    -- Выбираем случайный напиток (упрощенная логика)
    local drink_index = flr(rnd(#drinks)) + 1
    local drink = drinks[drink_index]
    
    -- Проверяем, хватает ли денег
    if money >= drink.price then
      consume_drink(drink)
    end
  end
end

-- Функция употребления напитка с применением формул прогрессии
function consume_drink(drink)
  money -= drink.price
  
  -- Применяем формулы прогрессии
  local effective_intoxication = calculate_effective_intoxication(drink.intoxication)
  local effective_liver_damage = calculate_effective_liver_damage(drink.liver_damage)
  
  -- Применяем эффекты
  intoxication += effective_intoxication
  liver_health -= effective_liver_damage
  
  -- Проверяем побочный эффект
--   if rnd(1) < drink.effect_chance then
--     drink.effect_func()
--   end
  
  -- Проверяем условия окончания игры
  check_game_conditions()
end

-- Формула толерантности к алкоголю
function calculate_effective_intoxication(base_intoxication)
  local effectiveness = 1 - (tolerance_factor * total_seconds)  -- -0.15% эффективности каждую секунду
  local final_intoxication = base_intoxication * effectiveness
  
  -- Применяем бонус эффективности пьянства если активен
  if drinking_efficiency_timer > 0 then
    final_intoxication = final_intoxication * (1 + drinking_efficiency_bonus)
  end
  
  -- Применяем штраф за высокое опьянение
  local drunk_penalty = get_drunk_penalty()
  final_intoxication = final_intoxication * drunk_penalty
  
  return max(final_intoxication, base_intoxication * 0.1) -- минимум 10% эффективности
end

-- Формула увеличения урона печени
function calculate_effective_liver_damage(base_damage)
  local damage_multiplier = 1 + (liver_damage_factor * total_seconds)  -- +0.1833% урона каждую секунду
  local final_damage = base_damage * damage_multiplier
  
  -- Применяем защиту печени если активна
  if liver_protection_timer > 0 then
    final_damage = final_damage * (1 - liver_protection_bonus)
  end
  
  return final_damage
end

-- Функция падения опьянения
function update_sobering()
  if total_seconds % sobering_frequency == 0 then  -- каждую секунду
    local current_sobering_rate = base_sobering_rate + (sobering_acceleration * total_seconds)
    intoxication = max(0, intoxication - current_sobering_rate)
  end
end

-- Проверка условий окончания игры
function check_game_conditions()
  if liver_health <= 0 then
    -- current_state = game_state.game_over
  elseif intoxication <= intoxication_min_threshold then
    -- Слишком трезвый - проигрыш
    -- current_state = game_state.game_over
  elseif intoxication >= intoxication_critical then
    -- Критическое опьянение - проигрыш  
    -- current_state = game_state.game_over
  elseif total_seconds >= game_duration then
    -- Прошло 360 секунд - победа
    current_state = game_state.win
  end
end

-- Проверка штрафов за высокое опьянение
function get_drunk_penalty()
  if intoxication >= intoxication_drunk_threshold then
    return 0.5  -- 50% штраф к эффективности при опьянении "в хлам"
  end
  return 1.0    -- Нет штрафа
end

-- Function to trigger payday (referenced in update_time)  
function trigger_payday()
  current_state = game_state.payday
end

-- Placeholder update functions
function update_menu()
  -- Handle menu input
  if btnp(4) then -- X button
    current_state = game_state.playing
  end
end

function update_game()
  -- Main game logic
  -- Handle drink selection, consumption, etc.
  
  -- Проверяем активную мини-игру
  if minigame_active then
    update_minigame()
    return
  end
  
  -- Выбор напитка кнопками с учетом эффектов
  local left_pressed = btnp(0)  -- Left
  local right_pressed = btnp(1) -- Right
  local x_pressed = btnp(4)     -- X - купить напиток
  
  -- Инверсия управления
  if inverted_controls_timer > 0 then
    left_pressed = btnp(1)   -- Right становится Left
    right_pressed = btnp(0)  -- Left становится Right
  end
  
  -- Хаотичное движение - случайный выбор
  if chaotic_movement_timer > 0 and (left_pressed or right_pressed) then
    if rnd(1) < 0.5 then
      selected_drink = max(1, selected_drink - 1)
    else
      selected_drink = min(#drinks, selected_drink + 1)
    end
  -- Дрожь выбора - иногда случайно сдвигается
  elseif shaking_timer > 0 and rnd(1) < 0.3 then
    if rnd(1) < 0.5 then
      selected_drink = max(1, selected_drink - 1)
    else
      selected_drink = min(#drinks, selected_drink + 1)
    end
  -- Нормальное управление
  elseif left_pressed then
    selected_drink = max(1, selected_drink - 1)
  elseif right_pressed then
    selected_drink = min(#drinks, selected_drink + 1)
  end
  
  -- Замедление - задержка между нажатиями
  local can_buy = true
  if slowmotion_timer > 0 then
    can_buy = (frames % 30 == 0)  -- Только каждые полсекунды
  end
  
  if x_pressed and can_buy then
    local drink = drinks[selected_drink]
    if money >= drink.price then
      consume_drink(drink)
    end
  end
end

-- Мини-игра для мочегонного эффекта
minigame_timer = 0
minigame_target = 0
minigame_progress = 0

function update_minigame()
  if minigame_timer == 0 then
    -- Инициализация мини-игры
    minigame_timer = 300 -- 5 секунд
    minigame_target = 50 + rnd(50) -- случайная цель
    minigame_progress = 0
  end
  
  minigame_timer -= 1
  
  -- Быстрые нажатия X увеличивают прогресс
  if btnp(4) then
    minigame_progress += 5
  end
  
  -- Проверяем завершение мини-игры
  if minigame_progress >= minigame_target then
    -- Успех - получаем бонус к деньгам
    money += 50
    minigame_active = false
    minigame_timer = 0
  elseif minigame_timer <= 0 then
    -- Провал - теряем здоровье печени
    liver_health -= 50
    minigame_active = false
    minigame_timer = 0
  end
end

function update_payday()
  -- Handle payday logic - зарплата уже начислена в update_time()
  
  -- Применяем случайный бонус при получке
  apply_payday_bonus()
  
  current_state = game_state.playing
end

-- Функция применения бонусов при получке
function apply_payday_bonus()
  for bonus in all(payday_bonuses) do
    if rnd(1) < bonus.chance then
      apply_bonus_effect(bonus)
      break -- только один бонус за раз
    end
  end
end

-- Применение эффекта бонуса
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
    liver_health += bonus.value -- также восстанавливаем здоровье
  elseif bonus.effect == "drinking_efficiency" then
    drinking_efficiency_bonus = bonus.value
    drinking_efficiency_timer = bonus.duration
  end
end

function update_game_over()
  -- Handle game over screen
  if btnp(4) then -- X button to restart
    -- Reset game state
    money = 267
    liver_health = base_liver_health
    intoxication = 50  -- Стартуем в оптимальном диапазоне
    total_seconds = 0
    frames = 0
    selected_drink = 1
    
    -- Сброс бонусов
    liver_protection_bonus = 0
    liver_protection_timer = 0
    drinking_efficiency_bonus = 0
    drinking_efficiency_timer = 0
    max_liver_bonus = 0
    
    -- Сброс эффектов
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
    
    current_state = game_state.main_menu
  end
end

function update_win()
  -- Handle win screen
  if btnp(4) then -- X button to restart
    -- Reset game state (same as game over)
    money = 267
    liver_health = base_liver_health
    intoxication = 50
    total_seconds = 0
    frames = 0
    selected_drink = 1
    
    -- Сброс бонусов
    liver_protection_bonus = 0
    liver_protection_timer = 0
    drinking_efficiency_bonus = 0
    drinking_efficiency_timer = 0
    max_liver_bonus = 0
    
    -- Сброс эффектов
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
    draw_game_over()
  elseif current_state == game_state.win then
    draw_win()
  end
end

function draw_menu()
  print("drunk simulator", 20, 20, 7)
  print("survive 360 seconds", 18, 35, 6)
  print("", 0, 45, 6)
  print("keep drunk level:", 15, 50, 5)
  print("optimal: 40-70", 25, 60, 11)
  print("avoid: <20 or >100", 18, 70, 8)
  print("", 0, 80, 6)
  print("left/right select drink", 15, 85, 6)
  print("x buy/interact", 23, 95, 6)
  print("", 0, 105, 6)
  print("press x to start", 20, 115, 12)
end

function draw_game()
  -- Проверяем активную мини-игру
  if minigame_active then
    draw_minigame()
    return
  end
  
  -- Основная информация
  print("money: "..money.."r", 5, 5, 7)
  print("liver: "..flr(liver_health).."/"..flr(base_liver_health + max_liver_bonus), 5, 15, 8)
  
  -- Опьянение с цветовой индикацией
  local intox_color = get_intoxication_color()
  print("drunk: "..flr(intoxication), 5, 25, intox_color)
  print(get_intoxication_status(), 50, 25, intox_color)
  
  print("time: "..total_seconds.."/"..game_duration.." sec", 5, 35, 6)
  
  -- Прогрессия эффективности
  local effectiveness = flr((1 - (tolerance_factor * total_seconds)) * 100)
  local drunk_penalty = get_drunk_penalty()
  local total_effectiveness = flr(effectiveness * drunk_penalty)
  print("efficiency: "..total_effectiveness.."%", 5, 45, 5)
  
  -- Магазин напитков
  print("shop (left/right select, x buy):", 5, 85, 7)
  local drink = drinks[selected_drink]
  local color = money >= drink.price and 11 or 8
  print(drink.name.." - "..drink.price.."r", 5, 95, color)
  print("drunk+"..drink.intoxication.." dmg+"..drink.liver_damage, 5, 105, 6)
  
  -- Активные эффекты
  local y_offset = 55
  if liver_protection_timer > 0 then
    print("liver protect: "..flr(liver_protection_timer/60).."s", 5, y_offset, 11)
    y_offset += 10
  end
  
  if drinking_efficiency_timer > 0 then
    print("drink boost: "..flr(drinking_efficiency_timer/60).."s", 5, y_offset, 12)
    y_offset += 10
  end
  
  -- Эффекты состояний
  if blind_timer > 0 then
    -- Эффект слепоты - не видно напитки (скрываем магазин)
    rectfill(5, 85, 122, 115, 0)
    print("blind - cant see shop", 10, 100, 8)
  end
  
  if shaking_timer > 0 then
    -- Дрожь выбора - случайное смещение
    print("shaking selection", 10, 64, 8)
  end
  
  if slowmotion_timer > 0 then
    -- Замедление
    print("slow motion", 35, 64, 11)
  end
  
  if inverted_controls_timer > 0 then
    -- Инверсия управления
    print("inverted controls", 20, 64, 14)
  end
  
  if chaotic_movement_timer > 0 then
    -- Хаотичное движение
    print("chaotic movement", 20, 64, 13)
  end
  
  if blackout_timer > 0 then
    -- Полный черный экран при блэкауте
    cls(0)
    print("blackout", 35, 64, 8)
  end
end

-- Функции для отображения состояния опьянения
function get_intoxication_color()
  if intoxication <= intoxication_min_threshold then
    return 8  -- Красный - опасно трезвый
  elseif intoxication >= intoxication_critical then
    return 8  -- Красный - критическое опьянение
  elseif intoxication >= intoxication_drunk_threshold then
    return 9  -- Оранжевый - "в хлам"
  elseif intoxication >= intoxication_optimal_min and intoxication <= intoxication_optimal_max then
    return 11 -- Зеленый - оптимальный уровень
  else
    return 6  -- Серый - не оптимальный, но безопасный
  end
end

function get_intoxication_status()
  if intoxication <= intoxication_min_threshold then
    return "too sober!"
  elseif intoxication >= intoxication_critical then
    return "critical!"
  elseif intoxication >= intoxication_drunk_threshold then
    return "wasted"
  elseif intoxication >= intoxication_optimal_min and intoxication <= intoxication_optimal_max then
    return "optimal"
  else
    return "ok"
  end
end

function draw_minigame()
  cls(1)
  print("bathroom emergency!", 20, 30, 7)
  print("press x rapidly!", 25, 45, 8)
  
  -- Прогресс бар
  local progress_width = (minigame_progress / minigame_target) * 100
  rect(10, 60, 110, 70, 7)
  rectfill(11, 61, 10 + progress_width, 69, 11)
  
  -- Таймер
  print("time: "..flr(minigame_timer/60), 45, 80, 6)
  print("progress: "..flr(minigame_progress).."/"..flr(minigame_target), 25, 90, 6)
end

function draw_payday()
  cls(3)
  print("payday!", 35, 50, 7)
  print("salary: "..salary.."r", 30, 65, 6)
  print("bonus applied!", 30, 80, 11)
end

function draw_game_over()
  cls(8)
  print("game over", 30, 50, 2)
  
  -- Определяем причину проигрыша
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
  print("survived "..game_duration.." seconds!", 15, 65, 6)
  print("final score: "..money.."r", 25, 75, 12)
  print("press x to restart", 20, 85, 12)
end

-- Вспомогательная функция для форматирования времени
function pad_number(num)
  if num < 10 then
    return "0"..num
  else
    return ""..num
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
00000bbbbbbb0000000bbbbbbbbbb000000000000046440000000888000990000009a000000fe000007770000000000000000000000000000000000000000000
000bbbbbbbbbb000000baaaaaaabb0000007c0000004400066666666000a9000000820000007c000077777000000000000000000000000000000000000000000
000baaaaaaabb0000bbbbbbbbbbbb000000cc000066666606000066600333300000820000007c000097a79900000000000000000000000000000000000000000
0bbbbbbbbbbbb0000011a11aa11a1100006666000363636066666666034aa440008822000077cd00079797090000000000000000000000000000000000000000
0011aaaaaaaa110000aa166aa661aa000068ee00063636306cccccc63444a44400877200007ccd0009a9a9090000000000000000000000000000000000000000
00aa11aaaa11aa0000aaaaaaaaaaaa0000888e00037777306c77ccc60aa44aa000877200007ccd00099a99090000000000000000000000000000000000000000
00a1aaaaaaaa1a0000aaa1aaaa1aaa0000e8ee00033333306cccccc604a444a000897200007ccd0009a9a9900000000000000000000000000000000000000000
0aaaa1aaaa1aaaa00aaa11a8a11aaaa000eeee000333333066666666004444000088220000dddd00009990000000000000000000000000000000000000000000
0aaaa1a8aa1aaaa00aaa66a2866aaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aa66a28a66aa0000aaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaa0000ac1aa16aaaaa00000025555000000000002555500000000000289850000000000000000000000000000000000000000000000000000000
0ccaaa1aa1aaa00000ccc1166aaaa0000022ee55552222220022ee555522222200a298a985828282000000000000000000000000000000000000000000000000
0cc0a66116aa00000ccc0666aabb000002ee455eeeeeeeee02ee495eeeee333e09994958e8e83338000000000000000000000000000000000000000000000000
0cc0bb6666bb00000ccabbbbbbbb000002e445444444444002e49a944494434008a89a9444944340000000000000000000000000000000000000000000000000
0ccabbbbbbbba0000000bb0bb0bb000002e445444444440002e4494949a944000888494949a94800000000000000000000000000000000000000000000000000
0000bb0bb0bb000000000bbbbbbb00002ee44544444440002ee4459a949440009888459a94944000000000000000000000000000000000000000000000000000
00000bbbbbbb000000000bbbbbbb00002e555544444400002e55554944440000a9a8aa4948480000000000000000000000000000000000000000000000000000
000bbbbbbbbbb000000bbbbbbbbbb0002544454440000000259995aaa0000000988e8aaaa0000000000000000000000000000000000000000000000000000000
000baaaaaaabb000000baaaaaaabb0000544a555000000000599a555000000000598aa5500000000000000000000000000000000000000000000000000000000
0bbbbbbbbbbbb0000bbbbbbbbbbbb000054aa00550000000059aa00550000000089aa00a50000000000000000000000000000000000000000000000000000000
0011aaaaaaaa110000011aaaa11aa00005aaa0005500000005aaa0005500000005aaa000aa000000000000000000000000000000000000000000000000000000
00a11aaaa11aaa0000166aaaa661aa000aa00000050000000aa00000050000000aa0000005000000000000000000000000000000000000000000000000000000
00166aaaa661aa0000aaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa1a8aa1aaaaa000aa1a8aa1aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa1a1881a1aaaa00aa1a1881a1aaa00099999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a666888666aa000aa666888666aa009aaccca90cccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaa0000aaaaaaaaaaaa009aacaca90cc88cc000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ccaa61aa16aa000000c16a16aaaa0009acccca90c8cc8c000000000000000000000000000000000000000000000000000000000000000000000000000000000
0cc06661166a000000ccc1166aaa00009aacaaa908cccc8000000000000000000000000000000000000000000000000000000000000000000000000000000000
0cc0bb6666bb00000cccbb66aab000009acccca90cccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ccabbbbbbbba0000cabbbbbbbb000009aacaaa90cccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000bb0bb0bb0000000b0bb0bbb00000099999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000c7cc00000000006666664400000000000000008880000000022000000000000009a000000000000001e000000000000000000000000000000000000000
000000c7cc000000000022224444000000000066666666600000000a90000000000000088000000000000007d000000000007777770000000000000000000000
000000c7cc0000000000002244000000000006606666666000000007700000000000000220000000000000022000000000077777777000000000000000000000
0000eeeeeeee00000000006666000000000066006ccccc600000333333440000000000088000000000000007d000000000777777777700000000000000000000
000eeeeeeeeee0000000666666660000000660006ccccc600003444444444000000000888800000000000077dd00000000979797979700000000000000000000
000ee88ee77e0000006363636366000006600066c777c6000322777777224000000081221800000000007ccccd00000007a7a7a7a7799000000000000000000
000ee8888eeee000000363636363600000600066cc787c6004222222222222400000082772800000000007ccccd000000097a7a7a7a709900000000000000000
000ee8888e77e00000033333333330000066666ccc777c6042aa22aa22aa22240000087227800000000007ccccd00000007a7a7a7a7900900000000000000000
000eee88eeeee0000003377777733000006ccccccccccc604222a222a222a2240000082777800000000007aaaad00000007a7a7a7a7900900000000000000000
000eeeeeee77e0000003377777733000006c7c7c7ccccc604722a222a222a2240000082227800000000007a88ad00000009aaaaaaaa900900000000000000000
000ecccccccce0000003377777733000006cc777ccccc6604722a222a222a2440000082227800000000007ccccd000000097a7a7a7a900900000000000000000
000ecccccc77e0000003333333333000006c77777ccc666004222222222224400000082772800000000007ccccd00000009aaaaaaaa909000000000000000000
000ecccccccce0000003333333333000006cc777ccc6660000444777777433000000082112800000000007ccccd000000099a9a9a9a990000000000000000000
000eeccccccee0000002211111133000006c7c7c7c66600000002444444300000000081111800000000007ccccd0000000099a9a9a9000000000000000000000
0000eeeeeeee0000000022222222000000666666666600000000022223300000000008888880000000000dddddd0000000009999990000000000000000000000
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
111111111111111111111111111111111