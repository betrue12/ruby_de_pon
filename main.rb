require 'dxruby'

PANEL_SIZE = 40

PANEL_X = 6
PANEL_Y = 12
COLORS = 5

FIELD_X = PANEL_X * PANEL_SIZE
FIELD_Y = PANEL_Y * PANEL_SIZE

WINDOW_X = FIELD_X
WINDOW_Y = FIELD_Y

#pixel per second
SLIDE_SPEED = 0.3
FALL_SPEED = 3.0

#alpha-value per second
VANISH_SPEED = 5.0

#buttons of game pad
BUTTONS = [ P_BUTTON0, P_BUTTON1, P_BUTTON2, P_BUTTON3,
            P_BUTTON4, P_BUTTON5, P_BUTTON6, P_BUTTON7,
            P_BUTTON8, P_BUTTON9, P_BUTTON10, P_BUTTON11,
            P_BUTTON12, P_BUTTON13, P_BUTTON14, P_BUTTON15 ]

class Panel
  attr_accessor :x,
                :y,
                :color,
                :offset_y

  def initialize(x, y, color)
    @x = x
    @y = y
    @color = color #integer
    file_name = color.to_s + '.png'
    @image = Image.load('./resources/panel/' + file_name) #PANEL_SIZE * PANEL_SIZE
    @is_to_vanish = false
    @is_fixed = true
    @is_vanishing = false
    @offset_y = 0.0
    @alpha = (y >= 0) ? 255.0 : 128.0 #dark if below base-line
  end
  
  def lighten
    @alpha = 255.0
  end
  
  def draw(offset_slide)
    axis_x = @x * PANEL_SIZE
    axis_y = WINDOW_Y - (y + 1) * PANEL_SIZE + @offset_y.floor - offset_slide.floor
    Window.draw_alpha(axis_x , axis_y, @image, @alpha.floor)
  end
  
  def vanishable?
    !self.vanishing? && self.fixed?
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
    @image = Image.load('./resources/cursor/cursor.png') #width: PANEL_SIZE * 2, height: PANEL_SIZE
  end
  
  def handle_move
    @y += 1 if Input.key_push?(K_UP) && @y < PANEL_Y - 1
    @y -= 1 if Input.key_push?(K_DOWN) && @y > 0
    @x += 1 if Input.key_push?(K_RIGHT) && @x < PANEL_X - 2
    @x -= 1 if Input.key_push?(K_LEFT) && @x > 0
  end
  
  def draw(offset_slide)
    axis_x = @x * PANEL_SIZE
    axis_y = WINDOW_Y - (y + 1) * PANEL_SIZE - offset_slide.floor
    Window.draw(axis_x , axis_y, @image)
  end
end

class Field
  attr_accessor :panels,
                :cursor,
                :offset_slide
  
  def initialize
    is_lined_without_vanish = false
    until is_lined_without_vanish
      @panels = []
      is_lined_without_vanish = true #tmp
      (-1...(PANEL_Y/2)).each {|y|
        make_newline(y)
      }
      
      make_sorted_panels
      
      # check only vertical vanishing,
      # because make_newline checks horizontal vanishing
      (0...PANEL_X).each {|x|
        (0...(PANEL_Y - 2)).each {|y|
          panel = @sorted_panels[x][y]
          above_panel1 = @sorted_panels[x][y+1]
          above_panel2 = @sorted_panels[x][y+2]
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
  end
  
  def make_newline(y)
    new_panels = []
    (0...PANEL_X).each {|x|
      panel = Panel.new(x, y, rand(0...COLORS) )
      left_panel1 = new_panels[x-1]
      left_panel2 = new_panels[x-2]
      while x >= 2 && panel.vanish_with?(left_panel1, left_panel2)
        panel = Panel.new(x, y, rand(0...COLORS) )
      end
      new_panels[x] = panel
    }
    @panels.concat(new_panels)
  end
  
  def make_sorted_panels
    @sorted_panels = Array.new(PANEL_X){ Array.new(PANEL_Y) } #2-dimensional array
    @panels.each {|panel|
      @sorted_panels[panel.x][panel.y] = panel if panel.y >= 0
    }
  end
  
  def handle_force_slide
    @is_force_sliding = true if Input.key_down?(K_Z)
  end
  
  def handle_exchange
    return unless Input.key_push?(K_SPACE)
    
    x = @cursor.x
    y = @cursor.y
    panel_l = @sorted_panels[x][y]
    panel_r = @sorted_panels[x+1][y]
    above_panel_l = @sorted_panels[x][y+1]
    above_panel_r = @sorted_panels[x+1][y+1]
    below_panel_l = @sorted_panels[x][y-1]
    below_panel_r = @sorted_panels[x+1][y-1]
    
    #condition of exchange impossible
    return if panel_l && !panel_l.vanishable?
    return if panel_r && !panel_r.vanishable?
    return if above_panel_l && !above_panel_l.fixed?
    return if above_panel_r && !above_panel_r.fixed?
    
    
    if panel_l
      panel_l.x += 1 # to right
      panel_l.unfix if y > 0 && !(below_panel_r && below_panel_r.fixed?)
    end
    if panel_r
      panel_r.x -= 1 # to left
      panel_r.unfix if y > 0 && !(below_panel_l && below_panel_l.fixed?)
    end
    
    
    @sorted_panels[x][y] = panel_r
    @sorted_panels[x+1][y] = panel_l
  end
  
  def slide
    (0...PANEL_X).each {|x|
      (0...PANEL_Y).each {|y|
        panel = @sorted_panels[x][y]
        return if panel && (panel.vanishing? || !panel.fixed?)
      }
    }
    
    @offset_slide += (@is_force_sliding ? 3.0 : 1.0) * SLIDE_SPEED
    
    if @offset_slide >= PANEL_SIZE
      @offset_slide -= PANEL_SIZE
      @panels.each {|panel|
        panel.y += 1
        panel.lighten
        @is_force_sliding = false
        if panel.y == PANEL_Y - 1
          die
          break
        end
      }
      @cursor.y += 1
      make_newline(-1)
    end
  end
  

  
  def vanish_panels
    (0...PANEL_X).each {|x|
      (0...PANEL_Y).each {|y|
        base = @sorted_panels[x][y]
        next unless base && base.vanishable?
        
        #horizontal
        if x + 2 < PANEL_X
          right_panel1 = @sorted_panels[x+1][y]
          right_panel2 = @sorted_panels[x+2][y]
          if base.vanish_with?(right_panel1, right_panel2)
            base.to_vanish
            right_panel1.to_vanish
            right_panel2.to_vanish
          end
        end
        
        #vertical
        if y + 2 < PANEL_Y
          above_panel1 = @sorted_panels[x][y+1]
          above_panel2 = @sorted_panels[x][y+2]
          if base.vanish_with?(above_panel1, above_panel2)
            base.to_vanish
            above_panel1.to_vanish
            above_panel2.to_vanish
          end
        end
      }
    }
    
    @panels.each {|panel|
      panel.vanish if panel.to_vanish?
      @sorted_panels[panel.x][panel.y] = nil if panel.vanished?
    }
    @panels.delete_if{|panel| panel.vanished?}
  end
  
  def fall_panels
    (0...PANEL_X).each {|x|
      (1...PANEL_Y).each {|y|    #need to exec from bottom
        panel = @sorted_panels[x][y]
        next if !panel || panel.vanishing?
        
        if panel.fixed?
          below_panel = @sorted_panels[x][y - 1]
          panel.unfix unless below_panel && below_panel.fixed?
        else
          panel.offset_y += FALL_SPEED
          
          if panel.offset_y >= PANEL_SIZE
            @sorted_panels[x][panel.y] = nil
            panel.y -= 1
            @sorted_panels[x][panel.y] = panel
            panel.offset_y -= PANEL_SIZE
          end
          
          below_panel = @sorted_panels[x][panel.y - 1]
          panel.fix if panel.y < 1 || (below_panel && below_panel.fixed?)
        end
      }
    }
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



module Mode
  module_function #use all funtions in Window.loop
  
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
    return step #not configured
  end
  
  def main(field)
    field.make_sorted_panels
    
    field.handle_force_slide
    field.cursor.handle_move
    field.handle_exchange
    
    field.vanish_panels
    field.fall_panels
    field.slide
    
    field.panels.each {|panel|
      panel.draw(field.offset_slide)
    }
    field.cursor.draw(field.offset_slide)
    
    return (field.continue?) ? 'main' : 'game_over'
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
#Window.fps = 20 #for debug

field = Field.new

mode = 'select'
conf_step = 0

Window.loop do
  break if Input.key_push?(K_ESCAPE)
  
  case mode
  when 'select'
    mode = Mode.select
    
  when 'pad_config'
    conf_step = Mode.pad_config(conf_step)
    mode = 'main' if conf_step == 2
    
  when 'main'
    mode = Mode.main(field)
    
  when 'game_over'
    mode = Mode.game_over
    field = Field.new if mode == 'main'
  end
end