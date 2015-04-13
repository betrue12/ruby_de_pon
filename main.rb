require 'dxruby'

PANEL_SIZE = 40

PANEL_X = 6
PANEL_Y = 13 # include line under bottom
COLORS = 5

FIELD_X = PANEL_X * PANEL_SIZE
FIELD_Y = (PANEL_Y - 1) * PANEL_SIZE

WINDOW_X = FIELD_X + 200
WINDOW_Y = FIELD_Y

# pixel per second
SLIDE_SPEED = 0.3
FALL_SPEED = 3.0

# alpha-value per second
VANISH_SPEED = 3.0

# seconds for COM's one input
COM_INPUT_CYCLE = 3

# buttons of game pad
BUTTONS = [ P_BUTTON0, P_BUTTON1, P_BUTTON2, P_BUTTON3,
            P_BUTTON4, P_BUTTON5, P_BUTTON6, P_BUTTON7,
            P_BUTTON8, P_BUTTON9, P_BUTTON10, P_BUTTON11,
            P_BUTTON12, P_BUTTON13, P_BUTTON14, P_BUTTON15 ]

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
    file_name = color.to_s + '.png'
    @image = Image.load('./resources/panel/' + file_name) # PANEL_SIZE * PANEL_SIZE
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

  def draw(offset_slide)
    axis_x = @x * PANEL_SIZE
    axis_y = WINDOW_Y - y * PANEL_SIZE + @offset_y.floor - offset_slide.floor
    Window.draw_alpha(axis_x , axis_y, @image, @alpha.floor)
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

  def initialize(x,y)
    @x = x
    @y = y
    @image = Image.load('./resources/cursor/cursor.png') # width: PANEL_SIZE * 2, height: PANEL_SIZE
  end

  def handle_move(input_hash)
    @y += 1 if input_hash[:up] && @y < PANEL_Y - 1
    @y -= 1 if input_hash[:down] && @y > 1
    @x += 1 if input_hash[:right] && @x < PANEL_X - 2
    @x -= 1 if input_hash[:left] && @x > 0
  end

  def draw(offset_slide)
    axis_x = @x * PANEL_SIZE
    axis_y = WINDOW_Y - y * PANEL_SIZE - offset_slide.floor
    Window.draw(axis_x , axis_y, @image)
  end
end

class Score
  def initialize
    @score = 0
    @messages = []
    @del_message_count = 1
    @font = Font.new(16)
  end

  def vanish_score(num)
    @score += num * 10
  end

  def combo_bonus(combo)
    @score += (combo > 13) ? 0 : 150 * combo - 250
    @messages.push(combo.to_s + " combo!")
  end

  def many_bonus(num)
    if num < 31
      @score += ((2 * num**2)/10.0).floor * 10
    elsif num == 31
      @score += 0
    else
      @score += 33000
    end
    @messages.push(num.to_s + " vanish!")
  end

  def age
    @del_message_count = (@del_message_count + 1) % (60 * 5)
    if @del_message_count == 0
      @messages.delete_at(0) if @messages
    end
  end

  def draw
    str = "Score: " + @score.to_s + "\n\n"
    @messages.each{|message|
      str += message + "\n"
    }
    Window.draw_font(FIELD_X + 40, 80, str, @font)
  end
end


class Field
  attr_accessor :panels,
                :cursor,
                :offset_slide

  def initialize
    is_lined_without_vanish = false
    until is_lined_without_vanish
      @panels = Array.new(PANEL_X){ Array.new(PANEL_Y) }
      is_lined_without_vanish = true # tmp
      (0...(PANEL_Y/2)).each {|y|
        make_newline(y)
      }

      # check only vertical vanishing,
      # because make_newline checks horizontal vanishing
      (0...PANEL_X).each {|x|
        (1...(PANEL_Y - 2)).each {|y|
          panel = @panels[x][y]
          above_panel1 = @panels[x][y+1]
          above_panel2 = @panels[x][y+2]
          if panel && panel.vanish_with?(above_panel1, above_panel2)
            is_lined_without_vanish = false
          end
        }
      }
    end

    @offset_slide = 0.0
    @is_continue = true
    @cursor = Cursor.new((PANEL_X - 1)/2, PANEL_Y/2)
    @is_force_sliding = false
    @score = Score.new
  end

  def make_newline(y)
    (0...PANEL_X).each {|x|
      panel = Panel.new(x, y, rand(0...COLORS) )
      left_panel1 = @panels[x-1][y]
      left_panel2 = @panels[x-2][y]
      while x >= 2 && panel.color == left_panel1.color && panel.color == left_panel2.color
        panel = Panel.new(x, y, rand(0...COLORS) )
      end
      @panels[x][y] = panel
    }
  end

  def handle_force_slide
    @is_force_sliding = true
  end

  def handle_exchange
    x = @cursor.x
    y = @cursor.y
    panel_l = @panels[x][y]
    panel_r = @panels[x+1][y]
    above_panel_l = @panels[x][y+1]
    above_panel_r = @panels[x+1][y+1]
    below_panel_l = @panels[x][y-1]
    below_panel_r = @panels[x+1][y-1]

    # condition of exchange impossible
    return if panel_l && !panel_l.vanishable?
    return if panel_r && !panel_r.vanishable?
    return if above_panel_l && !above_panel_l.fixed?
    return if above_panel_r && !above_panel_r.fixed?


    if panel_l
      panel_l.x += 1 # to right
      panel_l.unfix unless below_panel_r && below_panel_r.fixed?
    end
    if panel_r
      panel_r.x -= 1 # to left
      panel_r.unfix unless below_panel_l && below_panel_l.fixed?
    end


    @panels[x][y] = panel_r
    @panels[x+1][y] = panel_l
  end

  def slide
    (0...PANEL_X).each {|x|
      (0...PANEL_Y).each {|y|
        panel = @panels[x][y]
        return if panel && (panel.vanishing? || !panel.fixed?)
      }
    }

    @offset_slide += (@is_force_sliding ? 3.0 : 1.0) * SLIDE_SPEED

    if @offset_slide >= PANEL_SIZE
      @offset_slide -= PANEL_SIZE
      (0...PANEL_X).each {|x|
        PANEL_Y.downto(0) {|y| # need to exec from top
          panel = @panels[x][y]
          next unless panel
          @panels[x][y] = nil
          panel.y += 1
          @panels[x][y+1] = panel
          panel.lighten
          @is_force_sliding = false
          if panel.y == PANEL_Y - 1
            die
            break
          end
        }
      }
      @cursor.y += 1
      make_newline(0)
    end
  end

  def vanish_panels
    vanish_num_for_score = 0
    combo_for_score = 1

    (0...PANEL_X).each {|x|
      (1...PANEL_Y).each {|y|
        base = @panels[x][y]
        next unless base && base.vanishable?

        # horizontal
        if x + 2 < PANEL_X
          right_panel1 = @panels[x+1][y]
          right_panel2 = @panels[x+2][y]
          if base.vanish_with?(right_panel1, right_panel2)
            vanishing_panels = [base, right_panel1, right_panel2]
            combo = vanishing_panels.map{|panel| panel.combo }.max
            vanishing_panels.each{|panel|
              panel.combo = combo
              panel.to_vanish
            }
            combo_for_score = [combo_for_score, combo].max
          end
        end

        # vertical
        if y + 2 < PANEL_Y
          above_panel1 = @panels[x][y+1]
          above_panel2 = @panels[x][y+2]
          if base.vanish_with?(above_panel1, above_panel2)
            vanishing_panels = [base, above_panel1, above_panel2]
            combo = vanishing_panels.map{|panel| panel.combo }.max
            vanishing_panels.each{|panel|
              panel.combo = combo
              panel.to_vanish
            }
            combo_for_score = [combo_for_score, combo].max
          end
        end
      }
    }

    (0...PANEL_X).each {|x|
      (1...PANEL_Y).each {|y|
        panel = @panels[x][y]
        next unless panel
        if panel.to_vanish?
          vanish_num_for_score += 1 unless panel.vanishing?
          panel.vanish
        end
        panel.vanish if panel.to_vanish?
        if panel.vanished?
          combo_next = panel.combo + 1
          above_y = y + 1
          while @panels[x][above_y] && @panels[x][above_y].fixed? && !@panels[x][above_y].to_vanish?
            above_panel = @panels[x][above_y]
            above_panel.combo = [above_panel.combo, combo_next].max
            above_y += 1
          end
          @panels[x][y] = nil
        end
      }
    }
    @score.vanish_score(vanish_num_for_score)
    @score.combo_bonus(combo_for_score) if combo_for_score > 1
    @score.many_bonus(vanish_num_for_score) if vanish_num_for_score > 3
    @score.age

  end

  def fall_panels
    (0...PANEL_X).each {|x|
      (1...PANEL_Y).each {|y|    # need to exec from bottom
        panel = @panels[x][y]
        next if !panel || panel.vanishing?

        if panel.fixed?
          below_panel = @panels[x][y - 1]
          if below_panel && below_panel.fixed?
            panel.combo = 1
          else
            panel.unfix
          end
        else
          panel.offset_y += FALL_SPEED

          if panel.offset_y >= PANEL_SIZE
            @panels[x][panel.y] = nil
            panel.y -= 1
            @panels[x][panel.y] = panel
            panel.offset_y -= PANEL_SIZE
          end

          below_panel = @panels[x][panel.y - 1]
          panel.fix if below_panel && below_panel.fixed?
        end
      }
    }
  end

  def calc_columns_height
    columns_height = Array.new(PANEL_X)
    (0...PANEL_X).each {|x|
      PANEL_Y.downto(0){|y|
        if @panels[x][y]
          columns_height[x] = y
          break
        end
      }
    }
    return columns_height
  end

  def draw_elements
    (0...PANEL_X).each {|x|
      (0...PANEL_Y).each {|y|
        @panels[x][y].draw(@offset_slide) if @panels[x][y]
      }
    }
    @cursor.draw(@offset_slide)
    @score.draw
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

    @input_queue = self.make_inputs(field) if @input_queue.length == 0
    return @input_queue.shift
  end

  def make_inputs(field)
    return [nil] if field.force_sliding?

    columns_height = field.calc_columns_height
    return [{:force_slide => true}] if columns_height.max < PANEL_Y - 4

    targets = balance(columns_height) ||
              try_vanish(field) ||
              exchange_random(columns_height)

    return inputs_to_move_and_exchange(field.cursor, targets)
  end

  def balance(columns_height)
    (0...(PANEL_X - 1)).each {|x|
      two_height = columns_height[x, 2]
      if (two_height[0] - two_height[1]).abs >= 2
        return {:x => x, :y => two_height.max}
      end
    }
    return nil
  end

  def try_vanish(field)
    panels = field.panels
    row_existing_color = Array.new(PANEL_Y){ [] }

    (1...(PANEL_Y - 2)).each {|y|
      row_existing_color[y] = (0...PANEL_X).to_a.map{|x| panels[x][y] && panels[x][y].color}.uniq.select{|elem| elem}
      next if y <= 2
      three_rows_color = row_existing_color[y] + row_existing_color[y-1] + row_existing_color[y-2]
      (0...COLORS).each {|color|
        if three_rows_color.count(color) == 3
          target_rows = [y - 2, y - 1, y]
          now_x = target_rows.map{|tmp_y|
            (0...PANEL_X).each {|x|
              break x if panels[x][tmp_y] && panels[x][tmp_y].color == color
            }
          }
          base_x = now_x[2]
          targets = []
          (now_x.length - 1).times {|i|
            x = now_x[i]
            tmp_y = target_rows[i]
            if x >= base_x
              (x - 1).downto(base_x){|tmp_x|
                targets.push({:x => tmp_x, :y => tmp_y})
              }
            else
              x.upto(base_x - 1){|tmp_x|
                targets.push({:x => tmp_x, :y => tmp_y})
              }
            end
          }
          return targets
        end
      }
    }
    return nil
  end

  def exchange_random(columns_height)
    x = rand(0...(PANEL_X - 1))
    max_y = columns_height[x, 2].max
    y = rand(0..max_y)
    return {:x => x, :y => y}
  end

  def inputs_to_move_and_exchange(now_cursor, targets)
    inputs = []
    prev = {:x => now_cursor.x, :y =>now_cursor.y}
    targets = [targets] if targets.is_a?(Hash)

    targets.each{|target|
      x_dist = target[:x] - prev[:x]
      y_dist = target[:y] - prev[:y]
      if x_dist > 0
        inputs += [{:right => true}] * x_dist
      else
        inputs += [{:left => true}] * (-x_dist)
      end
      if y_dist > 0
        inputs += [{:up => true}] * y_dist
      else
        inputs += [{:down => true}] * (-y_dist)
      end
      inputs += [{:exchange => true}]
      prev = target
    }
    return inputs
  end
end


module Mode
  module_function # use all funtions in Window.loop

  def select
    font = Font.new(16)
    message = "Ruby de Pon!\n" +
              "\n" +
              "*Keyboard*\n" +
              "Push SPACE to start game\n" +
              "SPACE => exchange panel\n" +
              "Z => slide up fast\n" +
              "Array key => move cursor\n" +
              "\n" +
              "*Game pad*\n" +
              "Push any button of pad\n" +
              "for button config, and then start"
    Window.draw_font(10, 100, message, font)

    return 'main' if Input.key_push?(K_SPACE)
    return 'demo' if Input.key_push?(K_Z)

    BUTTONS.each{|button|
      return 'pad_config' if Input.pad_push?(button)
    }

    return 'select'
  end

  def pad_config(step)
    font = Font.new(16)
    case step
    when 0
      Window.draw_font(10, 100, "Push button for exchange panels", font)
      BUTTONS.each{|button|
        if Input.pad_push?(button)
          Input.set_config(button, K_SPACE)
          return step + 1
        end
      }
    when 1
      Window.draw_font(10, 100, "Push button for slide up fast", font)
      BUTTONS.each{|button|
        if Input.pad_push?(button)
          Input.set_config(button, K_Z)
          return step + 1
        end
      }
    end
    return step
  end

  def main(field)
    input_hash = {:up          => Input.key_push?(K_UP),
                  :down        => Input.key_push?(K_DOWN),
                  :right       => Input.key_push?(K_RIGHT),
                  :left        => Input.key_push?(K_LEFT),
                  :exchange    => Input.key_push?(K_SPACE),
                  :force_slide => Input.key_down?(K_Z)      }
    next_mode = play(field, input_hash)
    return next_mode
  end

  def demo(field, brain)
    input_hash = brain.dequeue_input(field) || {}
    next_mode = play(field, input_hash)
    return next_mode
  end

  def play(field, input_hash)
    field.handle_force_slide if input_hash[:force_slide]
    field.cursor.handle_move(input_hash)
    field.handle_exchange if input_hash[:exchange]
    field.vanish_panels
    field.fall_panels
    field.slide

    field.draw_elements

    return (field.continue?) ? nil : 'game_over'
  end

  def game_over
    message = "*Game Over*\n" +
              "\n" +
              "push SPACE or exchange button\n" +
              "for start game again"
    font = Font.new(16)
    Window.draw_font(10, 100, message, font)
    return Input.key_push?(K_SPACE) ? 'main' : 'game_over'
  end
end

Window.width = WINDOW_X
Window.height = WINDOW_Y
# Window.fps = 20 # for debug

field = Field.new
brain = Brain.new

mode = 'select'
conf_step = 0

Window.loop do
  break if Input.key_push?(K_ESCAPE)

  case mode
  when 'select'
    mode = Mode.select || mode

  when 'pad_config'
    conf_step = Mode.pad_config(conf_step)
    mode = 'main' if conf_step == 2

  when 'main'
    mode = Mode.main(field) || mode

  when 'demo'
    mode = Mode.demo(field, brain) || mode

  when 'game_over'
    mode = Mode.game_over || mode
    field = Field.new if mode == 'main'
  end
end
