require 'dxruby'

# game size
PANEL_X = 6
PANEL_Y = 13 # include line under bottom
COLORS = 5

# pixel per frame
SLIDE_SPEED = 0.3
FALL_SPEED = 3.0

# alpha-value(panel's opacity) decrement per frame
VANISH_SPEED = 3.0

# frames per COM's one input
COM_INPUT_CYCLE = 4

# buttons of game pad
BUTTONS = [P_BUTTON0, P_BUTTON1, P_BUTTON2, P_BUTTON3,
           P_BUTTON4, P_BUTTON5, P_BUTTON6, P_BUTTON7,
           P_BUTTON8, P_BUTTON9, P_BUTTON10, P_BUTTON11,
           P_BUTTON12, P_BUTTON13, P_BUTTON14, P_BUTTON15]

# layout & design
PANEL_SIZE = 40

FIELD_X = PANEL_X * PANEL_SIZE
FIELD_Y = (PANEL_Y - 1) * PANEL_SIZE

WINDOW_X = (FIELD_X + 200) * 2
WINDOW_Y = FIELD_Y

MONO_FONT = Font.new(20, 'Consolas')
TITLE_FONT = Font.new(28, 'Georgia', :italic => true)

TITLE = 'Ruby de Pon!'
TITLE_X = (WINDOW_X - TITLE_FONT.get_width('Ruby de Pon!')) / 2
TITLE_Y = 100

TITLE_NAVI_X = TITLE_X
TITLE_NAVI_Y = 200

SCORE_X = FIELD_X + 40
SCORE_Y = 100

GAMEOVER_X = 10
GAMEOVER_Y = 100

MODE_LIST = ['main', 'vs', 'demo', 'config']
CONFIG_LIST = ['Gamepad exchange', 'Gamepad slide-up', 'end']

class Panel
  attr_accessor :x,
                :y,
                :color,
                :offset_y,
                :combo

  def initialize(x, y, color)
    @x = x
    @y = y # 0: under bottom, 1:bottom
    @color = color # integer
    @image = Image.load('./resources/panel/' + color.to_s + '.png')
    @is_to_vanish = false
    @is_fixed = true
    @is_vanishing = false
    @offset_y = 0.0
    @alpha = (y > 0) ? 255.0 : 128.0 # dark if below base-line
    @combo = 1
  end

  def lighten
    @alpha = 255.0
  end

  def darken
    @alpha = 128.0
  end

  def draw(offset_slide, field_offset)
    axis_x = @x * PANEL_SIZE + field_offset[:x]
    axis_y = WINDOW_Y - y * PANEL_SIZE + @offset_y.floor - offset_slide.floor + field_offset[:y]
    Window.draw_alpha(axis_x, axis_y, @image, @alpha.floor)
  end

  def vanishable?
    !self.vanishing? && self.fixed? && @y > 0
  end

  def vanish_with?(panel1, panel2)
    return false unless self.vanishable? &&
                        panel1 && panel1.vanishable? &&
                        panel2 && panel2.vanishable?

    return @color == panel1.color && @color == panel2.color
  end

  def vanish
    @is_vanishing = true
    @alpha -= VANISH_SPEED
    @alpha = 0.0 if @alpha < 0.0
  end

  def vanishing?
    @is_vanishing
  end

  def vanished?
    @alpha == 0.0
  end

  def to_vanish
    @is_to_vanish = true
  end

  def to_vanish?
    @is_to_vanish
  end

  def unfix
    @is_fixed = false
  end

  def fix
    @is_fixed = true
    @offset_y = 0.0
  end

  def fixed?
    @is_fixed
  end
end

class Cursor
  attr_accessor :x,
                :y

  def initialize(x, y)
    @x = x
    @y = y
    @image = Image.load('./resources/cursor/cursor.png')
  end

  def handle_move(input_hash)
    @y += 1 if input_hash[:up] && @y < PANEL_Y - 1
    @y -= 1 if input_hash[:down] && @y > 1
    @x += 1 if input_hash[:right] && @x < PANEL_X - 2
    @x -= 1 if input_hash[:left] && @x > 0
  end

  def draw(offset_slide, field_offset)
    axis_x = @x * PANEL_SIZE + field_offset[:x]
    axis_y = WINDOW_Y - y * PANEL_SIZE - offset_slide.floor + field_offset[:y]
    Window.draw(axis_x, axis_y, @image)
  end
end

class Score
  def initialize
    @score = 0
    @messages = []
    @del_message_count = 1
  end

  def vanish_score(num)
    @score += num * 10
  end

  def combo_bonus(combo)
    return if combo <= 1
    @score += (combo > 13) ? 0 : 150 * combo - 250
    @messages.push(combo.to_s + ' combo!')
  end

  def many_bonus(num)
    return if num <= 3
    if num < 31
      @score += ((2 * num**2) / 10.0).floor * 10
    elsif num == 31
      @score += 0
    else
      @score += 33000
    end
    @messages.push(num.to_s + ' vanish!')
  end

  def age
    @del_message_count = (@del_message_count + 1) % (60 * 5)
    @messages.delete_at(0) if @messages.length > 10 ||
                              (@messages.length == 0 && @del_message_count == 0)
  end

  def draw(field_offset)
    str = 'Score: ' + @score.to_s + "\n\n"
    @messages.each do |message|
      str += message + "\n"
    end
    Window.draw_font(SCORE_X + field_offset[:x], SCORE_Y + field_offset[:y], str, MONO_FONT)
  end
end

class Panels < Array
  def initialize
    super(PANEL_X) { Array.new(PANEL_Y) }
  end

  def vanish_with_aboves_at?(x, y)
    y > 0 &&
      y + 2 < PANEL_Y &&
      self[x][y] &&
      self[x][y].vanish_with?(self[x][y + 1], self[x][y + 2])
  end

  def vanish_with_belows_at?(x, y)
    self.vanish_with_aboves_at?(x, y - 2)
  end

  def vanish_with_rights_at?(x, y)
    x >= 0 &&
      x + 2 < PANEL_X &&
      self[x][y] &&
      self[x][y].vanish_with?(self[x + 1][y], self[x + 2][y])
  end

  def vanish_with_lefts_at?(x, y)
    self.vanish_with_rights_at?(x - 2, y)
  end

  def fill_init_panels
    is_lined_without_vanish = false
    until is_lined_without_vanish
      panels = Panels.new
      is_lined_without_vanish = true # tmp
      (0...(PANEL_Y / 2)).each do |y|
        panels.make_newline(y)
      end

      # check only vertical vanishing,
      # because make_newline checks horizontal vanishing
      (0...PANEL_X).each do |x|
        (1...(PANEL_Y - 2)).each do |y|
          if panels.vanish_with_aboves_at?(x, y)
            is_lined_without_vanish = false
            next
          end
        end
      end
    end
    return panels
  end

  def make_newline(y)
    (0...PANEL_X).each do |x| # need to exec from left
      self[x][y] = Panel.new(x, y, rand(0...COLORS))
      next if x < 2
      while self[x][y].color == self[x - 1][y].color &&
            self[x][y].color == self[x - 2][y].color
        self[x][y] = Panel.new(x, y, rand(0...COLORS))
      end
    end
  end

  def exchangable_at?(x, y)
    [self[x][y], self[x + 1][y]].each do |panel|
      return false if panel && !panel.vanishable?
    end
    [self[x][y + 1], self[x + 1][y + 1]].each do |above_panel|
      return false if above_panel && !above_panel.fixed?
    end

    return true
  end

  def handle_exchange(cursor)
    x, y = cursor.x, cursor.y
    return unless exchangable_at?(x, y)

    panel_l,       panel_r       = self[x][y],     self[x + 1][y]
    below_panel_l, below_panel_r = self[x][y - 1], self[x + 1][y - 1]

    if panel_l
      panel_l.x += 1 # to right
      panel_l.unfix unless below_panel_r && below_panel_r.fixed?
    end
    if panel_r
      panel_r.x -= 1 # to left
      panel_r.unfix unless below_panel_l && below_panel_l.fixed?
    end

    self[x][y] = panel_r
    self[x + 1][y] = panel_l
  end

  def fall_panels
    (0...PANEL_X).each do |x|
      (1...PANEL_Y).each do |y| # need to exec from bottom
        panel = self[x][y]
        next if !panel || panel.vanishing?

        if panel.fixed?
          below_panel = self[x][y - 1]
          if below_panel && below_panel.fixed?
            panel.combo = 1
          else
            panel.unfix
          end
        else
          panel.offset_y += FALL_SPEED

          if panel.offset_y >= PANEL_SIZE
            self[x][panel.y] = nil
            panel.y -= 1
            self[x][panel.y] = panel
            panel.offset_y -= PANEL_SIZE
          end

          below_panel = self[x][panel.y - 1]
          panel.fix if below_panel && below_panel.fixed?
        end
      end
    end
  end

  def prepare_to_vanish(panels)
    combo = panels.map { |panel| panel.combo }.max
    panels.each do |panel|
      panel.combo = combo
      panel.to_vanish
    end
    return combo
  end

  def exec_vanish
    vanish_num = 0

    (0...PANEL_X).each do |x|
      (1...PANEL_Y).each do |y|
        panel = self[x][y]
        next unless panel

        if panel.to_vanish?
          vanish_num += 1 unless panel.vanishing?
          panel.vanish
        end

        if panel.vanished?
          self[x][y] = nil
          combo_next = panel.combo + 1
          above_panel = self[x][y + 1]
          while above_panel && above_panel.fixed? && !above_panel.to_vanish?
            above_panel.combo = [above_panel.combo, combo_next].max
            above_panel = self[x][above_panel.y + 1]
          end
        end
      end
    end

    return vanish_num
  end

  def vanish_panels
    max_combo = 1

    (0...PANEL_X).each do |x|
      (1...PANEL_Y).each do |y|
        next unless self[x][y] && self[x][y].vanishable?

        if vanish_with_rights_at?(x, y)
          combo = prepare_to_vanish([self[x][y], self[x + 1][y], self[x + 2][y]])
          max_combo = [max_combo, combo].max
        end

        if vanish_with_aboves_at?(x, y)
          combo = prepare_to_vanish([self[x][y], self[x][y + 1], self[x][y + 2]])
          max_combo = [max_combo, combo].max
        end
      end
    end

    vanish_num = exec_vanish

    return { :num => vanish_num, :combo => max_combo }
  end

  def calc_columns_height
    columns_height = Array.new(PANEL_X)
    (0...PANEL_X).each do |x|
      PANEL_Y.downto(0) do |y|
        if self[x][y]
          columns_height[x] = y
          break
        end
      end
    end
    return columns_height
  end

  def draw(offset_slide, field_offset)
    (0...PANEL_X).each do |x|
      (0...PANEL_Y).each do |y|
        self[x][y].draw(offset_slide, field_offset) if self[x][y]
      end
    end
  end

  def darken
    (0...PANEL_X).each do |x|
      (0...PANEL_Y).each do |y|
        self[x][y].darken if self[x][y]
      end
    end
  end
end

class Field
  attr_accessor :panels,
                :cursor,
                :offset_slide

  def initialize(x, y)
    @panels = Panels.new.fill_init_panels
    @offset_slide = 0.0
    @is_continue = true
    @cursor = Cursor.new((PANEL_X - 1) / 2, PANEL_Y / 2)
    @is_force_sliding = false
    @score = Score.new
    @field_offset = {:x => x, :y => y}
  end

  def handle_force_slide
    @is_force_sliding = true
  end

  def handle_exchange
    @panels.handle_exchange(@cursor)
  end

  def slide
    (0...PANEL_X).each do |x|
      (0...PANEL_Y).each do |y|
        panel = @panels[x][y]
        return if panel && (panel.vanishing? || !panel.fixed?)
      end
    end

    @offset_slide += (@is_force_sliding ? 3.0 : 1.0) * SLIDE_SPEED

    if @offset_slide >= PANEL_SIZE
      @offset_slide -= PANEL_SIZE
      add_y_by_sliding
    end
  end

  def add_y_by_sliding
    (0...PANEL_X).each do |x|
      PANEL_Y.downto(0) do |y| # need to exec from top
        panel = @panels[x][y]
        next unless panel
        @panels[x][y] = nil
        panel.y += 1
        @panels[x][y + 1] = panel
        panel.lighten
        @is_force_sliding = false
        die if panel.y == PANEL_Y - 1
      end
    end
    @cursor.y += 1 if @cursor.y < PANEL_Y - 1
    @panels.make_newline(0)
  end

  def vanish_panels
    result = @panels.vanish_panels
    @score.vanish_score(result[:num])
    @score.combo_bonus(result[:combo])
    @score.many_bonus(result[:num])
    @score.age
  end

  def fall_panels
    @panels.fall_panels
  end

  def calc_columns_height
    @panels.calc_columns_height
  end

  def draw_elements
    @panels.darken unless continue?

    @panels.draw(@offset_slide, @field_offset)
    @cursor.draw(@offset_slide, @field_offset)
    @score.draw(@field_offset)
  end

  def die
    @is_continue = false
  end

  def continue?
    @is_continue
  end

  def force_sliding?
    @is_force_sliding
  end
end

class Brain
  def initialize
    @input_queue = []
    @cycle_count = 0
    @exchange_queue = []
  end

  def dequeue_input(field)
    @cycle_count = (@cycle_count + 1) % COM_INPUT_CYCLE
    return nil unless @cycle_count == 0

    @input_queue = make_inputs(field) if @input_queue.length == 0
    return @input_queue.shift
  end

  def make_inputs(field)
    return [nil] if field.force_sliding?

    columns_height = field.calc_columns_height
    return [{ :force_slide => true }] if columns_height.max < PANEL_Y - 4

    exchanges = balance(columns_height) ||
                try_vanish(field.panels) ||
                exchange_random(columns_height)

    return inputs_to_move_and_exchange(field.cursor, exchanges)
  end

  def balance(columns_height)
    (0...(PANEL_X - 1)).each do |x|
      two_height = columns_height[x, 2]
      if (two_height[0] - two_height[1]).abs >= 2
        return { :x => x, :y => two_height.max }
      end
    end
    return nil # don't have to balance
  end

  def try_vanish(panels)
    row_existing_color = Array.new(PANEL_Y) { [] }

    (1...(PANEL_Y - 2)).each do |y|
      row_existing_color[y] = (0...PANEL_X).map { |x| panels[x][y] && panels[x][y].color }
                              .uniq.compact
      next if y <= 2

      target_rows = [y - 2, y - 1, y]
      (0...COLORS).each do |color|
        if target_rows.all? { |_y| row_existing_color[_y].include?(color) }
          now_x = target_rows.map do |_y|
            (0...PANEL_X).select { |x| panels[x][_y] && panels[x][_y].color == color }.sample
          end

          exchanges = []
          now_x.length.times do |i|
            exchanges += exchanges_to_carry_panel(now_x[i], now_x.last, target_rows[i])
          end

          return exchanges
        end
      end
    end
    return nil # can't find vanish
  end

  def exchange_random(columns_height)
    x = rand(0...(PANEL_X - 1))
    max_y = columns_height[x, 2].max
    y = rand(0..max_y)
    return { :x => x, :y => y }
  end

  def exchanges_to_carry_panel(now_x, target_x, y)
    exchanges = []
    if now_x >= target_x
      (now_x - 1).downto(target_x) do |x|
        exchanges.push({ :x => x, :y => y })
      end
    else
      now_x.upto(target_x - 1) do |x|
        exchanges.push({ :x => x, :y => y })
      end
    end
    return exchanges
  end

  def inputs_to_move_and_exchange(now_cursor, exchanges)
    inputs = []
    prev = { :x => now_cursor.x, :y => now_cursor.y }
    exchanges = [exchanges] if exchanges.is_a?(Hash)

    exchanges.each do |exchange|
      x_dist = exchange[:x] - prev[:x]
      y_dist = exchange[:y] - prev[:y]
      if x_dist > 0
        inputs += [{ :right => true }] * x_dist
      else
        inputs += [{ :left => true }] * (-x_dist)
      end
      if y_dist > 0
        inputs += [{ :up => true }] * y_dist
      else
        inputs += [{ :down => true }] * (-y_dist)
      end
      inputs += [{ :exchange => true }]
      prev = exchange
    end
    return inputs
  end
end

module Mode

  module_function # use all funtions in Window.loop

  def decided?
    return true if Input.key_push?(K_SPACE)
    BUTTONS.each do |button|
      return true if Input.pad_push?(button)
    end
    return false
  end

  def select(conf_value)
    Window.draw_font(TITLE_X, TITLE_Y, TITLE, TITLE_FONT)

    cursor = conf_value[:cursor_mode]

    next_mode = decided? ? MODE_LIST[cursor] : 'select'
    if Input.key_push?(K_UP)
      cursor = [cursor - 1, 0].max
    elsif Input.key_push?(K_DOWN)
      cursor = [cursor + 1, MODE_LIST.length - 1].min
    end

    str = ''
    MODE_LIST.length.times do |i|
      str += cursor == i ? '+ ' : '  '
      str += MODE_LIST[i] + "\n"
    end

    Window.draw_font(TITLE_NAVI_X, TITLE_NAVI_Y, str, MONO_FONT)

    conf_value[:cursor_mode] = cursor
    return next_mode
  end

  def config(conf_value)
    Window.draw_font(TITLE_X, TITLE_Y, TITLE, TITLE_FONT)

    cursor = conf_value[:cursor_config]
    btn_assign = conf_value[:btn_assign]

    if Input.key_push?(K_UP)
      cursor = [cursor - 1, 0].max
    elsif Input.key_push?(K_DOWN)
      cursor = [cursor + 1, CONFIG_LIST.length - 1].min
    end

    next_mode = 'config' # if not changed

    case cursor
    when 0
      BUTTONS.length.times do |i|
        if Input.pad_push?(BUTTONS[i])
          btn_assign[1] = btn_assign[0] if i == btn_assign[1]
          btn_assign[0] = i
        end
      end
    when 1
      BUTTONS.length.times do |i|
        if Input.pad_push?(BUTTONS[i])
          btn_assign[0] = btn_assign[1] if i == btn_assign[0]
          btn_assign[1] = i
        end
      end
    when 2
      BUTTONS.each do |button|
        if decided?
          Input.set_config(BUTTONS[btn_assign[0]], K_SPACE)
          Input.set_config(BUTTONS[btn_assign[1]], K_Z)
          next_mode = 'select'
          break
        end
      end
    end

    str = ''
    CONFIG_LIST.length.times do |i|
      str += cursor == i ? '+ ' : '  '
      str += CONFIG_LIST[i]
      str += ' = BUTTON ' + btn_assign[i].to_s if btn_assign[i]
      str += "\n"
    end

    Window.draw_font(TITLE_NAVI_X, TITLE_NAVI_Y, str, MONO_FONT)

    conf_value[:cursor_config] = cursor
    return next_mode
  end

  def main(field)
    input_hash = { :up          => Input.key_push?(K_UP),
                   :down        => Input.key_push?(K_DOWN),
                   :right       => Input.key_push?(K_RIGHT),
                   :left        => Input.key_push?(K_LEFT),
                   :exchange    => Input.key_push?(K_SPACE),
                   :force_slide => Input.key_down?(K_Z)      }
    status = play(field, input_hash)
    return (status == 'dead') ? 'game_over' : 'main'
  end

  def demo(field, brain)
    input_hash = brain.dequeue_input(field) || {}
    status = play(field, input_hash)
    return (status == 'dead') ? 'game_over' : 'demo'
  end

  def vs(field, enemy_field, brain, result)
    input_hash = { :up          => Input.key_push?(K_UP),
                   :down        => Input.key_push?(K_DOWN),
                   :right       => Input.key_push?(K_RIGHT),
                   :left        => Input.key_push?(K_LEFT),
                   :exchange    => Input.key_push?(K_SPACE),
                   :force_slide => Input.key_down?(K_Z)      }
    my_status = play(field, input_hash)
    if my_status == 'dead'
      result = 'lose'
      return 'vs_finish'
    end

    input_hash = brain.dequeue_input(enemy_field) || {}
    enemy_status = play(enemy_field, input_hash)
    if enemy_status == 'dead'
      result = 'win'
      return 'vs_finish'
    end

    return 'vs'
  end

  def play(field, input_hash)
    field.handle_force_slide if input_hash[:force_slide]
    field.cursor.handle_move(input_hash)
    field.handle_exchange if input_hash[:exchange]
    field.vanish_panels
    field.fall_panels
    field.slide

    field.draw_elements

    return (field.continue?) ? 'live' : 'dead'
  end

  def game_over(field)
    message = "*Game Over*\n" +
              "\n" +
              "push SPACE or\n" +
              "any Gamepad button\n" +
              'for start game again'
    Window.draw_font(GAMEOVER_X, GAMEOVER_Y, message, MONO_FONT, :z => 1)
    field.draw_elements
    return decided? ? 'select' : 'game_over'
  end

  def vs_finish(field, enemy_field, result)
    message = (result == 'win') ? "You win!\n" : "You lose...\n" +
              "\n" +
              "push SPACE or \n" +
              "any Gamepad button\n" +
              'for start game again'
    Window.draw_font(GAMEOVER_X, GAMEOVER_Y, message, MONO_FONT, :z => 1)
    field.draw_elements
    enemy_field.draw_elements
    return decided? ? 'select' : 'vs_finish'
  end
end

Window.width = WINDOW_X
Window.height = WINDOW_Y
# Window.fps = 20 # for debug

field = Field.new(0, 0)
brain = Brain.new
enemy_field = Field.new(FIELD_X + 200, 0)
result = nil

mode = 'select'
conf_value = {:cursor_mode   => 0,
              :cursor_config => 0,
              :btn_assign    => [0, 1] }

Window.loop do
  break if Input.key_push?(K_ESCAPE)

  case mode
  when 'select'
    mode = Mode.select(conf_value)

  when 'main'
    mode = Mode.main(field)

  when 'game_over'
    mode = Mode.game_over(field)
    field = Field.new(0, 0) if mode == 'select'

  when 'vs'
    mode = Mode.vs(field, enemy_field, brain, result)

  when 'vs_finish'
    mode = Mode.vs_finish(field, enemy_field, result)
    if mode == 'select'
      field = Field.new(0, 0)
      brain = Brain.new
      enemy_field = Field.new(FIELD_X + 200, 0)
      result = nil
    end

  when 'demo'
    mode = Mode.demo(field, brain)

  when 'config'
    mode = Mode.config(conf_value)
  end
end
