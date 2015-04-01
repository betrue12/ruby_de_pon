Ruby de Pon
====


clone of puzzle game "Panel de Pon"


## Description

Ruby de Pon is a clone of [Panel de Pon](http://ja.wikipedia.org/wiki/%E3%83%91%E3%83%8D%E3%83%AB%E3%81%A7%E3%83%9D%E3%83%B3), puzzle video game published by Nintendo in 1995. In outside of Japan, Panel de Pon is called [Tetris Attack](http://en.wikipedia.org/wiki/Tetris_Attack), [Puzzle League](http://en.wikipedia.org/wiki/Puzzle_League_%28series%29), and so on.

This is written using Ruby and [DXRuby](http://dxruby.sourceforge.jp/). By coincidence, there is a character "Ruby" in Panel de Pon :-)

This is under under development...

There is also [Japanese README](README_ja.md).

## Requirement

* Windows2000 or later
* Ruby 2.1.5 (32bit)
* [DXRuby](http://dxruby.sourceforge.jp/) corresponding to Ruby version
* DirectX 9.0c or later

## How to Start

1. Install Ruby and DXRuby
2. Clone or download this repository
3. run `ruby main.rb`

## How to Play

You can swap two panels in the cursor by pushing `SPACE`.

You arrange panels in horizontal or vertical lines of 3 or more with the same color, then they vanish.

If a panel reaches top of the field, the game is over.

Keys:

* Array keys: The cursor moves
* `SPACE`: Two panels in the cursor swap
* `Z`: Panels slide up fast
* `ESC`: The game ends
* `SPACE` after the game is over: The game starts again

## License

MIT

## Author

[betrue12](https://github.com/betrue12)