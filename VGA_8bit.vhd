library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bcd2font.all;

entity VGA_8bit is
    port (
        clock : in  std_logic;
        reset : in  std_logic;

        ps2_clock, ps2_data : in std_logic;

        beep : out std_logic;
        
        display_rgb : out std_logic_vector(2 downto 0);
        hsync       : out std_logic;
        vsync       : out std_logic
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
    constant WIDTH  : natural := 640;
    constant HEIGHT : natural := 480;

    ----------------------------------------------------------------------------
    -- Signals for counters and clock division.
    ----------------------------------------------------------------------------
    signal hcount  : unsigned(9 downto 0) := (others => '0');
    signal vcount  : unsigned(9 downto 0) := (others => '0');
    signal vga_clk : std_logic := '0';

    ----------------------------------------------------------------------------
    -- Active video indicator.
    ----------------------------------------------------------------------------
    signal dat_act : std_logic;

    ----------------------------------------------------------------------------
    -- Active pixel coordinates (relative to the active area) as unsigned and as integer.
    ----------------------------------------------------------------------------
    signal active_x, active_y : unsigned(9 downto 0);
    signal x, y : integer;


    ----------------------------------------------------------------------------
    -- Signals for text rendering
    ----------------------------------------------------------------------------
    signal char_num  : std_logic_vector(6 downto 0);
    signal char_row  : std_logic_vector(3 downto 0);
    signal char_col  : std_logic_vector(3 downto 0);
    signal draw_text : std_logic;

    signal char_hund_player_1 : std_logic_vector(6 downto 0);
    signal char_tens_player_1 : std_logic_vector(6 downto 0);
    signal char_ones_player_1 : std_logic_vector(6 downto 0);

    signal char_hund_player_2 : std_logic_vector(6 downto 0);
    signal char_tens_player_2 : std_logic_vector(6 downto 0);
    signal char_ones_player_2 : std_logic_vector(6 downto 0);

    signal draw_border : std_logic;


    ----------------------------------------------------------------------------
    -- Players properties
    ----------------------------------------------------------------------------
    signal score_player_1, score_player_2       : integer range 0 to 127 := 0;
    signal player_1_position, player_2_position : integer range 0 to HEIGHT;
    signal player_1_speed, player_2_speed       : integer range 0 to 127 := 10;
    signal player_1_width, player_2_width       : integer range 0 to HEIGHT / 2 - 62 := 50;
    signal start_game, game_over                : std_logic := '0';
    signal draw_player                          : std_logic;

    ----------------------------------------------------------------------------
    -- Ball 1 properties
    ----------------------------------------------------------------------------
    constant ball_radius                          : integer := 5;
    signal xball_1                                : integer := WIDTH / 2 - ball_radius * 2;
    signal yball_1                                : integer := 52 + (HEIGHT - 56) / 2;
    signal ball_speed_1                           : integer := 5;
    signal positive_x_speed_1, positive_y_speed_1 : std_logic := '1';
    signal draw_ball_1                            : std_logic;

    ----------------------------------------------------------------------------
    -- Ball 2 properties
    ----------------------------------------------------------------------------
    signal xball_2                                : integer := WIDTH / 2 + ball_radius * 2;
    signal yball_2                                : integer := 52 + (HEIGHT - 56) / 2;
    signal ball_speed_2                           : integer := 5;
    signal positive_x_speed_2, positive_y_speed_2 : std_logic := '0';
    signal draw_ball_2                            : std_logic;
    signal enable_ball_2                          : std_logic := '1';

    ----------------------------------------------------------------------------
    -- Signals for keyboard input
    ----------------------------------------------------------------------------
    signal new_code_avail : std_logic;
    signal code           : std_logic_vector(7 downto 0);
    signal next_read_code : std_logic;
begin

    keyboard_driver : entity work.ps2_keyboard(logic) port map(
        clk          => clock,
        ps2_clk      => ps2_clock,
        ps2_data     => ps2_data,
        ps2_code_new => new_code_avail,
        ps2_code     => code
    );

    ----------------------------------------------------------------------------
    -- Process to move players.
    ----------------------------------------------------------------------------
    process(reset, clock, new_code_avail, code)
        variable player_1_position_aux, player_2_position_aux : integer := 0;
    begin
        if reset = '0' then
            player_1_position_aux := 52 + (HEIGHT - 62) / 2;
            player_2_position_aux := 52 + (HEIGHT - 62) / 2;
            player_1_position     <= player_1_position_aux;
            player_2_position     <= player_2_position_aux;
            start_game            <= '0';
        elsif rising_edge(clock) then
            next_read_code <= new_code_avail;
            if new_code_avail = '1' and next_read_code <= '0' then
                case code is
                    when x"15" => -- Q player 1 -> UP
                        if player_1_position_aux - player_1_speed - player_1_width < 52 then
                            player_1_position_aux := HEIGHT - 10 - player_1_width;
                        else
                            player_1_position_aux := player_1_position_aux - player_1_speed;
                        end if;

                        player_1_position <= player_1_position_aux;

                    when x"1C" => -- A player 1 -> DOWN
                        if player_1_position_aux + player_1_speed + player_1_width > HEIGHT - 10 then
                            player_1_position_aux := 52 + player_1_width;
                        else
                            player_1_position_aux := player_1_position_aux + player_1_speed;
                        end if;

                        player_1_position <= player_1_position_aux;

                    when x"44" => -- O player 2 -> UP
                        if player_2_position_aux - player_2_speed - player_2_width < 52 then
                            player_2_position_aux := HEIGHT - 10 - player_2_width;
                        else
                            player_2_position_aux := player_2_position_aux - player_2_speed;
                        end if;

                        player_2_position <= player_2_position_aux;

                    when x"4B" => -- L player 2 -> DOWN
                        if player_2_position_aux + player_2_speed + player_2_width > HEIGHT - 10 then
                            player_2_position_aux := 52 + player_2_width;
                        else
                            player_2_position_aux := player_2_position_aux + player_2_speed;
                        end if;

                        player_2_position <= player_2_position_aux;

                    when x"16" => -- 1 -> Disable second ball
                        if start_game = '0' then
                            enable_ball_2 <= '0';
                        end if;

                    when x"1E" => -- 2 -> Enable second ball
                        if start_game = '0' then
                            enable_ball_2 <= '1';
                        end if;

                    when x"29" => -- SPACE -> START
                        start_game <= '1';

                    when others =>
                end case;
            end if;
        end if;
    end process;

    font_decoder : entity work.font_16x16_bold(v1) port map(
        clock    => clock,
        char_0   => char_num, 
        row_0    => char_row, 
        column_0 => char_col, 
        data_1   => draw_text
    );

    ----------------------------------------------------------------------------
    -- Process to convert scores to single font memory directions.
    ----------------------------------------------------------------------------
    process(vga_clk, score_player_1, score_player_2)
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

            bcd_conv_font(player_1_ones, char_ones_player_1);
            bcd_conv_font(player_1_tens, char_tens_player_1);
            bcd_conv_font(player_1_hund, char_hund_player_1);

            score_player_2_temp   := score_player_2;

            score_player_2_temp   := score_player_2_temp mod 1000;
            score_player_2_d_hund := score_player_2_temp / 100;
            score_player_2_temp   := score_player_2_temp mod 100;
            score_player_2_d_tens := score_player_2_temp / 10;
            score_player_2_d_ones := score_player_2_temp mod 10;
            
            player_2_hund := std_logic_vector(to_unsigned(score_player_2_d_hund, 4));
            player_2_tens := std_logic_vector(to_unsigned(score_player_2_d_tens, 4));
            player_2_ones := std_logic_vector(to_unsigned(score_player_2_d_ones, 4));

            bcd_conv_font(player_2_ones, char_ones_player_2);
            bcd_conv_font(player_2_tens, char_tens_player_2);
            bcd_conv_font(player_2_hund, char_hund_player_2);
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Process to move the ball
    ----------------------------------------------------------------------------
    process(reset, vga_clk, start_game, game_over)
        constant max_count : integer := 400_000;
        variable count : integer range 0 to max_count := 0;

        variable int_score_player_1, int_score_player_2 : integer range 0 to 127 := 0;
        variable int_player_1_speed, int_player_2_speed : integer range 0 to 127 := 10;
        variable int_player_1_width, int_player_2_width : integer range 0 to HEIGHT / 2 - 62 := 50;
    begin
        if reset = '0' then
            count            := 0;

            xball_1            <= WIDTH / 2 - ball_radius * 2;
            yball_1            <= 52 + (HEIGHT - 56) / 2;
            ball_speed_1       <= 5;
            positive_x_speed_1 <= '1';
            positive_y_speed_1 <= '1';

            xball_2            <= WIDTH / 2 + ball_radius * 2;
            yball_2            <= 52 + (HEIGHT - 56) / 2;
            ball_speed_2       <= 5;
            positive_x_speed_2 <= '0';
            positive_y_speed_2 <= '0';
            

            int_score_player_1 := 0;
            int_score_player_2 := 0;
            int_player_1_width := 50;
            int_player_2_width := 50;
            int_player_1_speed := 10;
            int_player_2_speed := 10;

            score_player_1 <= 0;
            score_player_2 <= 0;
            player_1_width <= 50;
            player_2_width <= 50;
            player_1_speed <= 10;
            player_2_speed <= 10;

            game_over        <= '0';
        elsif (rising_edge(vga_clk) and start_game = '1' and game_over = '0') then
            count := count + 1;

            if (count = 0) then
                beep <= '0';

                if (xball_1 + ball_speed_1 + ball_radius < WIDTH - 10 and positive_x_speed_1 = '1') then
                    xball_1 <= xball_1 + ball_speed_1;
                elsif (xball_1 - ball_speed_1 - ball_radius > 10) then
                    -- Ball has reached right side
                    if (xball_1 + ball_radius + ball_speed_1 >= WIDTH - 10) then
                        if ((yball_1 > player_2_position + player_2_width) or (yball_1 < player_2_position - player_2_width)) then
                            beep <= '1';
                            ball_speed_1 <= 5;
                            int_score_player_1 := int_score_player_1 + 1;
                            int_player_1_speed := int_player_1_speed - 1;
                            int_player_2_speed := int_player_2_speed + 1;
                            int_player_1_width := int_player_1_width + 5;
                            int_player_2_width := int_player_2_width - 5;
                            if (int_player_2_width < 10) then
                                game_over <= '1';
                            end if;
                        else
                            ball_speed_1 <= ball_speed_1 + 1;
                        end if;
                    end if;
                    
                    positive_x_speed_1 <= '0';
                    xball_1 <= xball_1 - ball_speed_1;
                else
                    -- Ball has reached left side
                    if (xball_1 - ball_radius - ball_speed_1 <= 10) then
                        if ((yball_1 > player_1_position + player_1_width) or (yball_1 < player_1_position - player_1_width)) then
                            beep <= '1';
                            ball_speed_1 <= 5;
                            int_score_player_2 := int_score_player_2 + 1;
                            int_player_1_speed := int_player_1_speed + 1;
                            int_player_2_speed := int_player_2_speed - 1;
                            int_player_1_width := int_player_1_width - 5;
                            int_player_2_width := int_player_2_width + 5;
                            if (int_player_1_width < 10) then
                                game_over <= '1';
                            end if;
                        else
                            ball_speed_1 <= ball_speed_1 + 1;
                        end if;
                    end if;
                    
                    positive_x_speed_1 <= '1';
                    xball_1 <= xball_1 + ball_speed_1;
                end if;

                if (yball_1 + ball_speed_1 + ball_radius < HEIGHT - 10 and positive_y_speed_1 = '1') then
                    yball_1 <= yball_1 + ball_speed_1;
                elsif (yball_1 - ball_speed_1 - ball_radius > 52) then
                    positive_y_speed_1 <= '0';
                    yball_1 <= yball_1 - ball_speed_1;
                else
                    positive_y_speed_1 <= '1';
                    yball_1 <= yball_1 + ball_speed_1;
                end if;


                if (enable_ball_2 = '1') then 
                    if (xball_2 + ball_speed_2 + ball_radius < WIDTH - 10 and positive_x_speed_2 = '1') then
                        xball_2 <= xball_2 + ball_speed_2;
                    elsif (xball_2 - ball_speed_2 - ball_radius > 10) then
                        -- Ball has reached right side
                        if (xball_2 + ball_radius + ball_speed_2 >= WIDTH - 10) then
                            if ((yball_2 > player_2_position + player_2_width) or (yball_2 < player_2_position - player_2_width)) then
                                beep <= '1';
                                ball_speed_2 <= 5;
                                int_score_player_1 := int_score_player_1 + 1;
                                int_player_1_speed := int_player_1_speed - 1;
                                int_player_2_speed := int_player_2_speed + 1;
                                int_player_1_width := int_player_1_width + 5;
                                int_player_2_width := int_player_2_width - 5;
                                if (int_player_2_width < 10) then
                                    game_over <= '1';
                                end if;
                            else
                                ball_speed_2 <= ball_speed_2 + 1;
                            end if;
                        end if;
                        
                        positive_x_speed_2 <= '0';
                        xball_2 <= xball_2 - ball_speed_2;
                    else
                        -- Ball has reached left side
                        if (xball_2 - ball_radius - ball_speed_2 <= 10) then
                            if ((yball_2 > player_1_position + player_1_width) or (yball_2 < player_1_position - player_1_width)) then
                                beep <= '1';
                                ball_speed_2 <= 5;
                                int_score_player_2 := int_score_player_2 + 1;
                                int_player_1_speed := int_player_1_speed + 1;
                                int_player_2_speed := int_player_2_speed - 1;
                                int_player_1_width := int_player_1_width - 5;
                                int_player_2_width := int_player_2_width + 5;
                                if (int_player_1_width < 10) then
                                    game_over <= '1';
                                end if;
                            else
                                ball_speed_2 <= ball_speed_2 + 1;
                            end if;
                        end if;
                        
                        positive_x_speed_2 <= '1';
                        xball_2 <= xball_2 + ball_speed_2;
                    end if;

                    if (yball_2 + ball_speed_2 + ball_radius < HEIGHT - 10 and positive_y_speed_2 = '1') then
                        yball_2 <= yball_2 + ball_speed_2;
                    elsif (yball_2 - ball_speed_2 - ball_radius > 52) then
                        positive_y_speed_2 <= '0';
                        yball_2 <= yball_2 - ball_speed_2;
                    else
                        positive_y_speed_2 <= '1';
                        yball_2 <= yball_2 + ball_speed_2;
                    end if;
                end if;

                score_player_1 <= int_score_player_1;
                score_player_2 <= int_score_player_2;
                player_1_width <= int_player_1_width;
                player_2_width <= int_player_2_width;
                player_1_speed <= int_player_1_speed;
                player_2_speed <= int_player_2_speed;
            end if;
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
            x <= to_integer(active_x);
            y <= to_integer(active_y);
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
            draw_ball_1 <= '0';
            draw_ball_2 <= '0';

            if dat_act = '1' then
                if (x >= 176 and x <= 464 and y >= 10 and y <= 42) then
                    -- ESCOMPong se imprimira copn un margen de 10 sobre 'y'

                    char_row <= std_logic_vector(to_unsigned((y - 10) / 2, 4));

                    -- E
                    if (x >= 176 and x <= 208) then
                        char_num <= "1000101";
                        char_col <= std_logic_vector(to_unsigned((x - 176) / 2, 4));

                    -- S
                    elsif (x >= 208 and x <= 240) then
                        char_num <= "1010011";
                        char_col <= std_logic_vector(to_unsigned((x - 208) / 2, 4));

                    -- C
                    elsif (x >= 240 and x <= 272) then
                        char_num <= "1000011";
                        char_col <= std_logic_vector(to_unsigned((x - 240) / 2, 4));

                    -- O
                    elsif (x >= 272 and x <= 304) then
                        char_num <= "1001111";
                        char_col <= std_logic_vector(to_unsigned((x - 272) / 2, 4));

                    -- M
                    elsif (x >= 304 and x <= 336) then
                        char_num <= "1001101";
                        char_col <= std_logic_vector(to_unsigned((x - 304) / 2, 4));

                    -- P
                    elsif (x >= 336 and x <= 368) then
                        char_num <= "1010000";
                        char_col <= std_logic_vector(to_unsigned((x - 336) / 2, 4));

                    -- o
                    elsif (x >= 368 and x <= 400) then
                        char_num <= "1101111";
                        char_col <= std_logic_vector(to_unsigned((x - 368) / 2, 4));

                    -- n
                    elsif (x >= 400 and x <= 432) then
                        char_num <= "1101110";
                        char_col <= std_logic_vector(to_unsigned((x - 400) / 2, 4));

                    -- g
                    elsif (x >= 432 and x <= 464) then
                        char_num <= "1100111";
                        char_col <= std_logic_vector(to_unsigned((x - 432) / 2, 4));

                    end if;

                elsif (((x >= 10 and x <= 106) or (x >= WIDTH - 106 and x <= WIDTH - 10)) and y >= 10 and y <= 42) then
                    char_row <= std_logic_vector(to_unsigned((y - 10) / 2, 4));

                    -- Hundreds - score player 1
                    if (x >= 10 and x <= 42) then
                        char_num <= char_hund_player_1;
                        char_col <= std_logic_vector(to_unsigned((x - 10) / 2, 4));

                    -- Tens - score player 1
                    elsif (x >= 42 and x <= 74) then
                        char_num <= char_tens_player_1;
                        char_col <= std_logic_vector(to_unsigned((x - 42) / 2, 4));

                    -- Ones - score player 1
                    elsif (x >= 74 and x <= 106) then
                        char_num <= char_ones_player_1;
                        char_col <= std_logic_vector(to_unsigned((x - 74) / 2, 4));



                    -- Hundreds - score player 2
                    elsif (x >= WIDTH - 106 and x <= WIDTH - 74) then
                        char_num <= char_hund_player_2;
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH - 106)) / 2, 4));

                    -- Tens - score player 2
                    elsif (x >= WIDTH - 74 and x <= WIDTH - 42) then
                        char_num <= char_tens_player_2;
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH - 74)) / 2, 4));

                    -- Ones - score player 2
                    elsif (x >= WIDTH - 42 and x <= WIDTH - 10) then
                        char_num <= char_ones_player_2;
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH - 42)) / 2, 4));
                    end if;
                
                elsif ((x >= 10 and x <= WIDTH - 10 and ((y >= 52 and y <= 53) or (y >= HEIGHT - 11 and y <= HEIGHT - 10))) or (y >= 52 and y <= HEIGHT - 10 and ((x >= 10 and x <= 11) or (x >= WIDTH - 11 and x <= WIDTH - 10)))) then
                    draw_border <= '1';

                elsif (x >= 12 and x <= 16 and y >= player_1_position - player_1_width and y <= player_1_position + player_1_width) then
                    draw_player <= '1';

                elsif (x >= WIDTH - 16 and x <= WIDTH - 12 and y >= player_2_position - player_2_width and y <= player_2_position + player_2_width) then
                    draw_player <= '1';
                elsif ((x - xball_1) * (x - xball_1) + (y - yball_1) * (y - yball_1) <= ball_radius * ball_radius) then
                    draw_ball_1 <= '1';

                elsif (enable_ball_2 = '1' and (x - xball_2) * (x - xball_2) + (y - yball_2) * (y - yball_2) <= ball_radius * ball_radius) then
                    draw_ball_2 <= '1';

                elsif (game_over = '1' and x >= WIDTH / 2 - 208 and x <= WIDTH / 2 + 208 and y >= 52 - 16 + (HEIGHT - 62) / 2 and y <= 52 + 16 + (HEIGHT - 62) / 2) then
                    -- "Fin del juego" will be printed in the middle

                    char_row <= std_logic_vector(to_unsigned((y - (52 - 16 + (HEIGHT - 62) / 2)) / 2, 4));

                    -- F
                    if (x >= WIDTH / 2 - 208 and x <= WIDTH / 2 - 176) then
                        char_num <= "1000110";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 - 208)) / 2, 4));

                    -- i
                    elsif (x >= WIDTH / 2 - 176 and x <= WIDTH / 2 - 144) then
                        char_num <= "1101001";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 - 176)) / 2, 4));

                    -- n
                    elsif (x >= WIDTH / 2 - 144 and x <= WIDTH / 2 - 112) then
                        char_num <= "1101110";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 - 144)) / 2, 4));

                    -- _

                    -- d
                    elsif (x >= WIDTH / 2 - 80 and x <= WIDTH / 2 - 48) then
                        char_num <= "1100100";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 - 80)) / 2, 4));

                    -- e
                    elsif (x >= WIDTH / 2 - 48 and x <= WIDTH / 2 - 16) then
                        char_num <= "1100101";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 - 48)) / 2, 4));

                    -- l
                    elsif (x >= WIDTH / 2 - 16 and x <= WIDTH / 2 + 16) then
                        char_num <= "1101100";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 - 16)) / 2, 4));

                    -- _

                    -- j
                    elsif (x >= WIDTH / 2 + 48 and x <= WIDTH / 2 + 80) then
                        char_num <= "1101010";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 + 48)) / 2, 4));
                    
                    -- u
                    elsif (x >= WIDTH / 2 + 80 and x <= WIDTH / 2 + 112) then
                        char_num <= "1110101";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 + 80)) / 2, 4));
                                            
                    -- e
                    elsif (x >= WIDTH / 2 + 112 and x <= WIDTH / 2 + 144) then
                        char_num <= "1100101";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 + 112)) / 2, 4));
                                            
                    -- g
                    elsif (x >= WIDTH / 2 + 144 and x <= WIDTH / 2 + 176) then
                        char_num <= "1100111";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 + 144)) / 2, 4));
                                            
                    -- o
                    elsif (x >= WIDTH / 2 + 176 and x <= WIDTH / 2 + 208) then
                        char_num <= "1101111";
                        char_col <= std_logic_vector(to_unsigned((x - (WIDTH / 2 + 176)) / 2, 4));
                    end if;
                end if;
            end if;
        end if;
    end process pixel_gen_proc;

    ----------------------------------------------------------------------------
    -- Output assignment for display_rgb.
    ----------------------------------------------------------------------------
    display_rgb <= "111" when draw_text = '1' or draw_ball_1 = '1' or draw_ball_2 = '1' or draw_border = '1' else
                   "010" when draw_player = '1' else "000";

end architecture Behavioral;
