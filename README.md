# ESCOMPong

![Prototype](https://github.com/cdelaof26/ESCOMPong/blob/main/images/image_945bb35b4626f346ad4f6663dd094a53_68256a8fedd37.jpeg?raw=true)

Mini ping pong using an FPGA and VHDL.

Chinese FPGA Board: EP4CE6E22C8

### Requirements
- The board
- A PS2 scan code set 2 compatible keyboard

### Controls
- **Player 1**: 
    - Q - UP
    - A - DOWN

- **Player 2**: 
    - O - UP
    - L - DOWN

**Disable second ball**: 1
**Enable second ball**: 2

2nd ball cannot be enabled/disabled once game is started.

### Credits

`ps2_keyboard.vhd` and `debounce.vhd` were taken from [howardjones/fpga-vt](https://github.com/howardjones/fpga-vt/)

`font_16x16_bold.vhd` was taken from [andremourato/BasketballScoreboard](https://github.com/andremourato/BasketballScoreboard)

### Versioning

#### v0.0.3 Beep and 2nd ball

#### v0.0.2-1 Refactoring

#### v0.0.2 Game logic

#### v0.0.1 Initial project
