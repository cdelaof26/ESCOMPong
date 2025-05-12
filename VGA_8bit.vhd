library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bcd_7seg.all;

entity VGA_8bit is
    port (
        clock    : in  std_logic;
        reset    : in  std_logic;
        PS2_CLOCK, PS2_DATA : in std_logic;
        disp_RGB : out std_logic_vector(2 downto 0);
        hsync    : out std_logic;
        vsync    : out std_logic
    );
end entity VGA_8bit;

architecture Behavioral of VGA_8bit is

    ----------------------------------------------------------------------------
    -- VGA Timing constants for a 640x480 active area.
    ----------------------------------------------------------------------------
    constant hsync_end  : unsigned(9 downto 0) := to_unsigned(95, 10);
    constant hdat_begin : unsigned(9 downto 0) := to_unsigned(143, 10);
    constant hdat_end   : unsigned(9 downto 0) := to_unsigned(783, 10);
    constant hpixel_end : unsigned(9 downto 0) := to_unsigned(799, 10);

    constant vsync_end  : unsigned(9 downto 0) := to_unsigned(1, 10);
    constant vdat_begin : unsigned(9 downto 0) := to_unsigned(34, 10);
    constant vdat_end   : unsigned(9 downto 0) := to_unsigned(514, 10);
    constant vline_end  : unsigned(9 downto 0) := to_unsigned(524, 10);

    ----------------------------------------------------------------------------
    -- Derived active area dimensions: 640x480.
    ----------------------------------------------------------------------------
    constant ACTIVE_WIDTH  : natural := 640;
    constant ACTIVE_HEIGHT : natural := 480;

    ----------------------------------------------------------------------------
    -- Signals for counters and clock division.
    ----------------------------------------------------------------------------
    signal hcount   : unsigned(9 downto 0) := (others => '0');
    signal vcount   : unsigned(9 downto 0) := (others => '0');
    signal vga_clk  : std_logic := '0';

    ----------------------------------------------------------------------------
    -- Active video indicator.
    ----------------------------------------------------------------------------
    signal dat_act  : std_logic;

    ----------------------------------------------------------------------------
    -- Active pixel coordinates (relative to the active area) as unsigned and as integer.
    ----------------------------------------------------------------------------
    signal active_x, active_y : unsigned(9 downto 0);
    signal active_x_int, active_y_int : integer;


    -- Characters
    signal id_char      : std_logic_vector(6 downto 0);  -- Character direction
    signal char_row     : std_logic_vector(3 downto 0);
    signal char_col     : std_logic_vector(3 downto 0);
    signal draw_char_px : std_logic;

    signal id_char_hund_player_1 : std_logic_vector(6 downto 0);
    signal id_char_tens_player_1 : std_logic_vector(6 downto 0);
    signal id_char_ones_player_1 : std_logic_vector(6 downto 0);

    signal id_char_hund_player_2 : std_logic_vector(6 downto 0);
    signal id_char_tens_player_2 : std_logic_vector(6 downto 0);
    signal id_char_ones_player_2 : std_logic_vector(6 downto 0);


    signal score_player_1, score_player_2 : integer range 0 to 127 := 0;

    signal player_1_position, player_2_position : integer range 0 to ACTIVE_HEIGHT;
    signal player_1_width, player_2_width : integer range 0 to ACTIVE_HEIGHT := 60;

    
    signal draw_border, draw_player : std_logic;

    signal read_code : std_logic;
    signal code : std_logic_vector(7 downto 0);
    signal next_read_code : std_logic;
begin

    process(reset, clock, read_code, code)
        variable player_1_position_aux, player_2_position_aux : integer := 0;
    begin
        if reset = '0' then
            player_1_position_aux := 52 + (ACTIVE_HEIGHT - 62) / 2;
            player_2_position_aux := 52 + (ACTIVE_HEIGHT - 62) / 2;
            player_1_position     <= 0;
            player_2_position     <= 0;
        elsif rising_edge(clock) then
            next_read_code <= read_code;
            if read_code = '1' and next_read_code <= '0' then
                case code is
                    when x"15" => -- Q player 1 -> UP
                        if player_1_position_aux - 10 - player_1_width < 52 then
                            player_1_position_aux := ACTIVE_HEIGHT - 10 - player_1_width;
                        else
                            player_1_position_aux := player_1_position_aux - 10;
                        end if;

                        player_1_position <= player_1_position_aux;

                    when x"1C" => -- A player 1 -> DOWN
                        if player_1_position_aux + 10 + player_1_width > ACTIVE_HEIGHT - 10 then
                            player_1_position_aux := 52 + player_1_width;
                        else
                            player_1_position_aux := player_1_position_aux + 10;
                        end if;

                        player_1_position <= player_1_position_aux;

                    when x"44" => -- O player 2 -> UP
                        if player_2_position_aux - 10 - player_2_width < 52 then
                            player_2_position_aux := ACTIVE_HEIGHT - 10 - player_2_width;
                        else
                            player_2_position_aux := player_2_position_aux - 10;
                        end if;

                        player_2_position <= player_2_position_aux;

                    when x"4B" => -- L player 2 -> DOWN
                        if player_2_position_aux + 10 + player_2_width > ACTIVE_HEIGHT - 10 then
                            player_2_position_aux := 52 + player_2_width;
                        else
                            player_2_position_aux := player_2_position_aux + 10;
                        end if;

                        player_2_position <= player_2_position_aux;

                    when others =>
                end case;
            end if;
        end if;
    end process;

    keyboard : entity work.ps2_keyboard(logic) port map(
        clk => clock,
        ps2_clk => PS2_CLOCK,
        ps2_data => PS2_DATA,
        ps2_code_new => read_code,
        ps2_code => code
    );

    name : entity work.font_16x16_bold(v1) port map(
        clock => clock,
        char_0 => id_char, 
        row_0 => char_row, 
        column_0 => char_col, 
        data_1 => draw_char_px
    );

    process(vga_clk, score_player_1, score_player_2) -- Process to convert scores to font
        variable score_player_1_temp   : INTEGER;
        variable score_player_1_d_hund : INTEGER;
        variable score_player_1_d_tens : INTEGER;
        variable score_player_1_d_ones : INTEGER;

        variable score_player_2_temp   : INTEGER;
        variable score_player_2_d_hund : INTEGER;
        variable score_player_2_d_tens : INTEGER;
        variable score_player_2_d_ones : INTEGER;

        variable player_1_ones, player_1_tens, player_1_hund : STD_LOGIC_VECTOR(3 downto 0);
        variable player_2_ones, player_2_tens, player_2_hund : STD_LOGIC_VECTOR(3 downto 0);
    begin
        if (rising_edge(vga_clk)) then
            score_player_1_temp   := score_player_1;
            score_player_1_temp   := score_player_1_temp mod 1000;
            score_player_1_d_hund := score_player_1_temp / 100;
            score_player_1_temp   := score_player_1_temp mod 100;
            score_player_1_d_tens := score_player_1_temp / 10;
            score_player_1_d_ones := score_player_1_temp mod 10;

            player_1_hund := std_logic_vector(to_unsigned(score_player_1_d_hund, 4));
            player_1_tens := std_logic_vector(to_unsigned(score_player_1_d_tens, 4));
            player_1_ones := std_logic_vector(to_unsigned(score_player_1_d_ones, 4));

            bcd_conv_font(player_1_ones, id_char_ones_player_1);
            bcd_conv_font(player_1_tens, id_char_tens_player_1);
            bcd_conv_font(player_1_hund, id_char_hund_player_1);

            score_player_2_temp   := score_player_2;

            score_player_2_temp   := score_player_2_temp mod 1000;
            score_player_2_d_hund := score_player_2_temp / 100;
            score_player_2_temp   := score_player_2_temp mod 100;
            score_player_2_d_tens := score_player_2_temp / 10;
            score_player_2_d_ones := score_player_2_temp mod 10;
            
            player_2_hund := std_logic_vector(to_unsigned(score_player_2_d_hund, 4));
            player_2_tens := std_logic_vector(to_unsigned(score_player_2_d_tens, 4));
            player_2_ones := std_logic_vector(to_unsigned(score_player_2_d_ones, 4));

            bcd_conv_font(player_2_ones, id_char_ones_player_2);
            bcd_conv_font(player_2_tens, id_char_tens_player_2);
            bcd_conv_font(player_2_hund, id_char_hund_player_2);
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Clock divider: Toggle vga_clk on every rising edge of clock.
    ----------------------------------------------------------------------------
    clk_divider : process(clock, reset)
    begin
        if reset = '0' then
            vga_clk <= '0';
        elsif rising_edge(clock) then
            vga_clk <= not vga_clk;
        end if;
    end process clk_divider;

    ----------------------------------------------------------------------------
    -- Horizontal counter (using vga_clk)
    ----------------------------------------------------------------------------
    h_counter_proc : process(vga_clk, reset)
    begin
        if reset = '0' then
            hcount <= (others => '0');
        elsif rising_edge(vga_clk) then
            if hcount = hpixel_end then
                hcount <= (others => '0');
            else
                hcount <= hcount + 1;
            end if;
        end if;
    end process h_counter_proc;

    ----------------------------------------------------------------------------
    -- Vertical counter, incremented at end of each horizontal line.
    ----------------------------------------------------------------------------
    v_counter_proc : process(vga_clk, reset)
    begin
        if reset = '0' then
            vcount <= (others => '0');
        elsif rising_edge(vga_clk) then
            if hcount = hpixel_end then
                if vcount = vline_end then
                    vcount <= (others => '0');
                else
                    vcount <= vcount + 1;
                end if;
            end if;
        end if;
    end process v_counter_proc;

    ----------------------------------------------------------------------------
    -- Determine active display area.
    ----------------------------------------------------------------------------
    dat_act <= '1' when ((hcount >= hdat_begin and hcount < hdat_end) and
                          (vcount >= vdat_begin and vcount < vdat_end))
                       else '0';

    ----------------------------------------------------------------------------
    -- Generate sync signals.
    ----------------------------------------------------------------------------
    hsync <= '1' when (hcount > hsync_end) else '0';
    vsync <= '1' when (vcount > vsync_end) else '0';

    ----------------------------------------------------------------------------
    -- Calculate active pixel coordinates.
    -- active_x and active_y are the pixel coordinates within the active region.
    ----------------------------------------------------------------------------
    active_x <= hcount - hdat_begin;
    active_y <= vcount - vdat_begin;

    ----------------------------------------------------------------------------
    -- Convert active x and y to integer for arithmetic operations.
    ----------------------------------------------------------------------------
    active_coord_conv: process(vga_clk)
    begin
        if rising_edge(vga_clk) then
            active_x_int <= to_integer(active_x);
            active_y_int <= to_integer(active_y);
        end if;
    end process active_coord_conv;

    ----------------------------------------------------------------------------
    -- Pixel generation process
    --
    -- Note: All arithmetic here is on integers.
    ----------------------------------------------------------------------------
    pixel_gen_proc : process(vga_clk, reset) begin
        if reset = '0' then
            draw_border <= '0';
        elsif rising_edge(vga_clk) then
            draw_border <= '0';
            draw_player <= '0';

            if dat_act = '1' then
                if (active_x_int >= 176 and active_x_int <= 464 and active_y_int >= 10 and active_y_int <= 42) then
                    -- ESCOMPong se imprimira copn un margen de 10 sobre 'y'

                    char_row <= std_logic_vector(to_unsigned((active_y_int - 10) / 2, 4));

                    -- E
                    if (active_x_int >= 176 and active_x_int <= 208) then
                        id_char <= "1000101";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 176) / 2, 4));

                    -- S
                    elsif (active_x_int >= 208 and active_x_int <= 240) then
                        id_char <= "1010011";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 208) / 2, 4));

                    -- C
                    elsif (active_x_int >= 240 and active_x_int <= 272) then
                        id_char <= "1000011";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 240) / 2, 4));

                    -- O
                    elsif (active_x_int >= 272 and active_x_int <= 304) then
                        id_char <= "1001111";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 272) / 2, 4));

                    -- M
                    elsif (active_x_int >= 304 and active_x_int <= 336) then
                        id_char <= "1001101";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 304) / 2, 4));

                    -- P
                    elsif (active_x_int >= 336 and active_x_int <= 368) then
                        id_char <= "1010000";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 336) / 2, 4));

                    -- o
                    elsif (active_x_int >= 368 and active_x_int <= 400) then
                        id_char <= "1101111";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 368) / 2, 4));

                    -- n
                    elsif (active_x_int >= 400 and active_x_int <= 432) then
                        id_char <= "1101110";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 400) / 2, 4));

                    -- g
                    elsif (active_x_int >= 432 and active_x_int <= 464) then
                        id_char <= "1100111";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 432) / 2, 4));
                    end if;

                elsif (((active_x_int >= 10 and active_x_int <= 106) or (active_x_int >= ACTIVE_WIDTH - 106 and active_x_int <= ACTIVE_WIDTH - 10)) and active_y_int >= 10 and active_y_int <= 42) then
                    char_row <= std_logic_vector(to_unsigned((active_y_int - 10) / 2, 4));

                    -- Centenas de score player 1
                    if (active_x_int >= 10 and active_x_int <= 42) then
                        id_char <= id_char_hund_player_1;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 10) / 2, 4));

                    -- Decimos de score player 1
                    elsif (active_x_int >= 42 and active_x_int <= 74) then
                        id_char <= id_char_tens_player_1;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 42) / 2, 4));

                    -- Unidades de score player 1
                    elsif (active_x_int >= 74 and active_x_int <= 106) then
                        id_char <= id_char_ones_player_1;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 74) / 2, 4));



                    -- Centenas de score player 2
                    elsif (active_x_int >= ACTIVE_WIDTH - 106 and active_x_int <= ACTIVE_WIDTH - 74) then
                        id_char <= id_char_hund_player_2;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - (ACTIVE_WIDTH - 106)) / 2, 4));

                    -- Decimos de score player 2
                    elsif (active_x_int >= ACTIVE_WIDTH - 74 and active_x_int <= ACTIVE_WIDTH - 42) then
                        id_char <= id_char_tens_player_2;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - (ACTIVE_WIDTH - 74)) / 2, 4));

                    -- Unidades de score player 2
                    elsif (active_x_int >= ACTIVE_WIDTH - 42 and active_x_int <= ACTIVE_WIDTH - 10) then
                        id_char <= id_char_ones_player_2;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - (ACTIVE_WIDTH - 42)) / 2, 4));
                    end if;
                
                elsif ((active_x_int >= 10 and active_x_int <= ACTIVE_WIDTH - 10 and ((active_y_int >= 52 and active_y_int <= 53) or (active_y_int >= ACTIVE_HEIGHT - 11 and active_y_int <= ACTIVE_HEIGHT - 10))) or (active_y_int >= 52 and active_y_int <= ACTIVE_HEIGHT - 10 and ((active_x_int >= 10 and active_x_int <= 11) or (active_x_int >= ACTIVE_WIDTH - 11 and active_x_int <= ACTIVE_WIDTH - 10)))) then
                    draw_border <= '1';
                elsif (active_x_int >= 12 and active_x_int <= 16 and active_y_int >= player_1_position - player_1_width and active_y_int <= player_1_position + player_1_width) then
                    draw_player <= '1';
                elsif (active_x_int >= ACTIVE_WIDTH - 16 and active_x_int <= ACTIVE_WIDTH - 12 and active_y_int >= player_2_position - player_2_width and active_y_int <= player_2_position + player_2_width) then
                    draw_player <= '1';
                end if;
            end if;
        end if;
    end process pixel_gen_proc;

    ----------------------------------------------------------------------------
    -- Output assignment for disp_RGB.
    ----------------------------------------------------------------------------
    disp_RGB <= "111" when draw_char_px = '1' else
                "111" when draw_border = '1' else 
                "010" when draw_player = '1' else "000";

end architecture Behavioral;