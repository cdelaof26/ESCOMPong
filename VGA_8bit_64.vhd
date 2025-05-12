library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
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
    signal id_char      : std_logic_vector(6 downto 0);  -- Direccion del caracter
    signal char_row     : std_logic_vector(3 downto 0);  -- Fila del caracter
    signal char_col     : std_logic_vector(3 downto 0);  -- Columna del caracter
    signal draw_char_px : std_logic;  -- Señal de control que indica si debe pintarse el caracter o no


    -- Signals para las coordenadas, direcciones de caracteres
    signal id_char_thou_x : std_logic_vector(6 downto 0);
    signal id_char_hund_x : std_logic_vector(6 downto 0);
    signal id_char_tens_x : std_logic_vector(6 downto 0);
    signal id_char_ones_x : std_logic_vector(6 downto 0);

    signal id_char_thou_y : std_logic_vector(6 downto 0);
    signal id_char_hund_y : std_logic_vector(6 downto 0);
    signal id_char_tens_y : std_logic_vector(6 downto 0);
    signal id_char_ones_y : std_logic_vector(6 downto 0);


    -- Geo params
    signal radius : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(50, 32)); -- radius in pixels.
    signal cx     : integer range 0 to ACTIVE_WIDTH  := ACTIVE_WIDTH / 2;
    signal cy     : integer range 0 to ACTIVE_HEIGHT := ACTIVE_HEIGHT / 2;

    signal radiusA : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(50, 32));
    signal radiusB : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(100, 32));
    signal parameterA : integer range 1 to 10 := 1;


    signal figure : integer range 1 to 4 := 1;
    signal draw_fig : std_logic;

    signal read_code : std_logic;
	signal code : std_logic_vector(7 downto 0);
	signal previous_code : std_logic_vector(7 downto 0) := (others => '0');
begin

	process(clock, read_code, code) begin
		if rising_edge(clock) then
			if read_code = '1' then
				if previous_code /= code then
					previous_code <= code;
					case code is
						when x"16" => -- 1
							figure <= 1;
						when x"1E" => -- 2
							figure <= 2;
						when x"26" => -- 3
							figure <= 3;
						when x"25" => -- 4
							figure <= 4;
						
						when x"15" => -- Q
							case figure is
								when 1 =>
									radius <= radius + 10;
								when 2 =>
									radiusA <= radiusA + 10;
								when 4 =>
									radiusA <= radiusA + 10;
								when others =>
									parameterA <= parameterA + 1;
							end case;

						when x"1D" => -- W
							case figure is
								when 1 =>
									radius <= radius - 10;
								when 2 =>
									radiusA <= radiusA - 10;
								when 4 =>
									radiusA <= radiusA - 10;
								when others =>
									parameterA <= parameterA - 1;
							end case;
						
						when x"24" => -- E
							case figure is
								when 2 =>
									radiusB <= radiusB + 10;
								when 4 =>
									radiusB <= radiusB + 10;
								when others =>
							end case;

						when x"2D" => -- 1 R
							case figure is
								when 2 =>
									radiusB <= radiusB - 10;
								when 4 =>
									radiusB <= radiusB - 10;
								when others =>
							end case;

						when x"43" => -- I -> UP
							cy <= cy - 10;

						when x"42" => -- K -> DOWN
							cy <= cy + 10;

						when x"3B" => -- J -> LEFT
							cx <= cx - 10;

						when x"4B" => -- L -> RIGHT
							cx <= cx + 10;

						when others =>
				    end case;
				end if;
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

    process(vga_clk, cx, cy) -- Proceso para convertir un integer a 7 segmentos y a caracteres
        variable x_temp   : INTEGER;
        variable x_d_thou : INTEGER;
        variable x_d_hund : INTEGER;
        variable x_d_tens : INTEGER;
        variable x_d_ones : INTEGER;

        variable y_temp   : INTEGER;
        variable y_d_thou : INTEGER;
        variable y_d_hund : INTEGER;
        variable y_d_tens : INTEGER;
        variable y_d_ones : INTEGER;

        variable xbcd0, xbcd1, xbcd2, xbcd3 : STD_LOGIC_VECTOR(3 downto 0);
    	variable ybcd0, ybcd1, ybcd2, ybcd3 : STD_LOGIC_VECTOR(3 downto 0);
    begin
        if (rising_edge(vga_clk)) then
            x_temp   := cx;
            x_d_thou := x_temp / 1000;
            x_temp   := x_temp mod 1000;
            x_d_hund := x_temp / 100;
            x_temp   := x_temp mod 100;
            x_d_tens := x_temp / 10;
            x_d_ones := x_temp mod 10;

            -- Convierte los digitos del entero a un vector de 4-bits
            xbcd3 := std_logic_vector(to_unsigned(x_d_thou, 4));
            xbcd2 := std_logic_vector(to_unsigned(x_d_hund, 4));
            xbcd1 := std_logic_vector(to_unsigned(x_d_tens, 4));
            xbcd0 := std_logic_vector(to_unsigned(x_d_ones, 4));

            -- Convierte el BCD a la direccion del caracter en font 16x16 bold
            bcd_conv_font(xbcd0, id_char_ones_x);
            bcd_conv_font(xbcd1, id_char_tens_x);
            bcd_conv_font(xbcd2, id_char_hund_x);
            bcd_conv_font(xbcd3, id_char_thou_x);

            y_temp   := cy;
            y_d_thou := y_temp / 1000;
            y_temp   := y_temp mod 1000;
            y_d_hund := y_temp / 100;
            y_temp   := y_temp mod 100;
            y_d_tens := y_temp / 10;
            y_d_ones := y_temp mod 10;

            ybcd3 := std_logic_vector(to_unsigned(y_d_thou, 4));
            ybcd2 := std_logic_vector(to_unsigned(y_d_hund, 4));
            ybcd1 := std_logic_vector(to_unsigned(y_d_tens, 4));
            ybcd0 := std_logic_vector(to_unsigned(y_d_ones, 4));

            bcd_conv_font(ybcd0, id_char_ones_y);
            bcd_conv_font(ybcd1, id_char_tens_y);
            bcd_conv_font(ybcd2, id_char_hund_y);
            bcd_conv_font(ybcd3, id_char_thou_y);
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
    -- Pixel generation process: Draw a white circle in the middle.
    --
    -- For each pixel inside the active area, compute the squared distance from
    -- the center of the active area. If the value is less than or equal to the
    -- square of the circle's radius, set the pixel white ("111"); otherwise, black.
    --
    -- Note: All arithmetic here is on integers.
    ----------------------------------------------------------------------------
    pixel_gen_proc : process(vga_clk, reset)
        variable dx, dy      : std_logic_vector(31 downto 0);
        variable dx64, dy64      : std_logic_vector(63 downto 0);
        variable dist_sq     : std_logic_vector(63 downto 0);
        variable dist_sq128     : std_logic_vector(127 downto 0);
        variable radius_sq   : std_logic_vector(63 downto 0);
        variable radius_sq_a : std_logic_vector(63 downto 0);
        variable radius_sq_b : std_logic_vector(63 downto 0);
        variable radius_ab_sq : std_logic_vector(127 downto 0);
    begin
        if reset = '0' then
            draw_fig <= '0';
        elsif rising_edge(vga_clk) then
        	draw_fig <= '0';

            if dat_act = '1' then
            	if (active_x_int >= 100 and active_x_int <= 388 and active_y_int >= ACTIVE_HEIGHT - 164 and active_y_int <= ACTIVE_HEIGHT - 132) then
                    -- Las letras para las figuras se imprimiran con un margen aproximado de 132 pixeles en 'y'

                    -- to_unsigned recibe dos parametros, el primero es el dato a convertir y el segundo
                    -- es el tamaño en bits del resultado

                    char_row <= std_logic_vector(to_unsigned((active_y_int - (ACTIVE_HEIGHT - 164)) / 2, 4));

                    case figure is
                        when 1 =>  -- CIRCULO
                            -- C
                            if (active_x_int >= 100 and active_x_int <= 132) then
                                id_char <= "1000011";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 100) / 2, 4));

                            -- I
                            elsif (active_x_int >= 132 and active_x_int <= 164) then
                                id_char <= "1001001";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 132) / 2, 4));

                            -- R
                            elsif (active_x_int >= 164 and active_x_int <= 196) then
                                id_char <= "1010010";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 164) / 2, 4));

                            -- C
                            elsif (active_x_int >= 196 and active_x_int <= 228) then
                                id_char <= "1000011";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 196) / 2, 4));

                            -- U
                            elsif (active_x_int >= 228 and active_x_int <= 260) then
                                id_char <= "1010101";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 228) / 2, 4));

                            -- L
                            elsif (active_x_int >= 260 and active_x_int <= 292) then
                                id_char <= "1001100";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 260) / 2, 4));

                            -- O
                            elsif (active_x_int >= 292 and active_x_int <= 324) then
                                id_char <= "1001111";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 292) / 2, 4));
                            end if;

                        when 2 =>  -- ELIPSE
                            -- E
                            if (active_x_int >= 100 and active_x_int <= 132) then
                                id_char <= "1000101";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 100) / 2, 4));

                            -- L
                            elsif (active_x_int >= 132 and active_x_int <= 164) then
                                id_char <= "1001100";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 132) / 2, 4));

                            -- I
                            elsif (active_x_int >= 164 and active_x_int <= 196) then
                                id_char <= "1001001";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 164) / 2, 4));

                            -- P
                            elsif (active_x_int >= 196 and active_x_int <= 228) then
                                id_char <= "1010000";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 196) / 2, 4));

                            -- S
                            elsif (active_x_int >= 228 and active_x_int <= 260) then
                                id_char <= "1010011";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 228) / 2, 4));

                            -- E
                            elsif (active_x_int >= 260 and active_x_int <= 292) then
                                id_char <= "1000101";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 260) / 2, 4));
                            end if;

                        when 3 =>  -- PARABOLA
                            -- P
                            if (active_x_int >= 100 and active_x_int <= 132) then
                                id_char <= "1010000";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 100) / 2, 4));

                            -- A
                            elsif (active_x_int >= 132 and active_x_int <= 164) then
                                id_char <= "1000001";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 132) / 2, 4));

                            -- R
                            elsif (active_x_int >= 164 and active_x_int <= 196) then
                                id_char <= "1010010";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 164) / 2, 4));

                            -- A
                            elsif (active_x_int >= 196 and active_x_int <= 228) then
                                id_char <= "1000001";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 196) / 2, 4));

                            -- B
                            elsif (active_x_int >= 228 and active_x_int <= 260) then
                                id_char <= "1000010";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 228) / 2, 4));

                            -- O
                            elsif (active_x_int >= 260 and active_x_int <= 292) then
                                id_char <= "1001111";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 260) / 2, 4));

                            -- L
                            elsif (active_x_int >= 292 and active_x_int <= 324) then
                                id_char <= "1001100";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 292) / 2, 4));

                            -- A
                            elsif (active_x_int >= 324 and active_x_int <= 356) then
                                id_char <= "1000001";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 324) / 2, 4));
                            end if;

                        when others =>  -- HIPERBOLA
                            -- H
                            if (active_x_int >= 100 and active_x_int <= 132) then
                                id_char <= "1001000";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 100) / 2, 4));

                            -- I
                            elsif (active_x_int >= 132 and active_x_int <= 164) then
                                id_char <= "1001001";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 132) / 2, 4));

                            -- P
                            elsif (active_x_int >= 164 and active_x_int <= 196) then
                                id_char <= "1010000";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 164) / 2, 4));

                            -- E
                            elsif (active_x_int >= 196 and active_x_int <= 228) then
                                id_char <= "1000101";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 196) / 2, 4));

                            -- R
                            elsif (active_x_int >= 228 and active_x_int <= 260) then
                                id_char <= "1010010";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 228) / 2, 4));

                            -- B
                            elsif (active_x_int >= 260 and active_x_int <= 292) then
                                id_char <= "1000010";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 260) / 2, 4));

                            -- O
                            elsif (active_x_int >= 292 and active_x_int <= 324) then
                                id_char <= "1001111";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 292) / 2, 4));

                            -- L
                            elsif (active_x_int >= 324 and active_x_int <= 356) then
                                id_char <= "1001100";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 324) / 2, 4));

                            -- A
                            elsif (active_x_int >= 356 and active_x_int <= 388) then
                                id_char <= "1000001";
                                char_col <= std_logic_vector(to_unsigned((active_x_int - 356) / 2, 4));
                            end if;
                    end case;

                elsif (active_x_int >= 100 and active_x_int <= 388 and active_y_int >= ACTIVE_HEIGHT - 132 and active_y_int <= ACTIVE_HEIGHT - 100) then
                    -- Las coordenadas para las figuras se imprimiran con un margen aproximado de 100 pixeles en 'y'

                    char_row <= std_logic_vector(to_unsigned((active_y_int - (ACTIVE_HEIGHT - 132)) / 2, 4));

                    -- Miles de x
                    if (active_x_int >= 100 and active_x_int <= 132) then
                        id_char <= id_char_thou_x;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 100) / 2, 4));

                    -- Centenas de x
                    elsif (active_x_int >= 132 and active_x_int <= 164) then
                        id_char <= id_char_hund_x;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 132) / 2, 4));

                    -- Decimos de x
                    elsif (active_x_int >= 164 and active_x_int <= 196) then
                        id_char <= id_char_tens_x;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 164) / 2, 4));

                    -- Unidades de x
                    elsif (active_x_int >= 196 and active_x_int <= 228) then
                        id_char <= id_char_ones_x;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 196) / 2, 4));

                    -- Coma
                    elsif (active_x_int >= 228 and active_x_int <= 260) then
                        id_char <= "0101100";
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 228) / 2, 4));

                    -- Miles de y
                    elsif (active_x_int >= 260 and active_x_int <= 292) then
                        id_char <= id_char_thou_y;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 260) / 2, 4));

                    -- Centenas de y
                    elsif (active_x_int >= 292 and active_x_int <= 324) then
                        id_char <= id_char_hund_y;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 292) / 2, 4));

                    -- Decimos de y
                    elsif (active_x_int >= 324 and active_x_int <= 356) then
                        id_char <= id_char_tens_y;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 324) / 2, 4));

                    -- Unidades de y
                    elsif (active_x_int >= 356 and active_x_int <= 388) then
                        id_char <= id_char_ones_y;
                        char_col <= std_logic_vector(to_unsigned((active_x_int - 356) / 2, 4));
                    end if;
                else
                	case figure is
		                when 1 =>
		                	-- Calculate difference in X and Y from circle center.
			                dx := std_logic_vector(to_unsigned(active_x_int, 32)) - std_logic_vector(to_unsigned(cx, 32));
			                dy := std_logic_vector(to_unsigned(active_y_int, 32)) - std_logic_vector(to_unsigned(cy, 32));
			                dist_sq := dx*dx + dy*dy;
			                radius_sq := radius * radius;

			                if dist_sq <= radius_sq then
			                    draw_fig <= '1';
			                else
			                    draw_fig <= '0';
			                end if;

			            when 2 =>
			            	--
		                    --     ELIPSE: (x-h)^2/a^2 + (y-k)^2/b^2 <= 1
		                    --             Simplificando un poco para hacer menos operaciones queda
		                    --             (b(x-h))^2 + (a(y-k))^2 <= (ab)^2
		                    --
		                    
		                    dx64 := radiusB * std_logic_vector(to_unsigned(active_x_int, 32)) - std_logic_vector(to_unsigned(cx, 32));
		                    dy64 := radiusA * std_logic_vector(to_unsigned(active_y_int, 32)) - std_logic_vector(to_unsigned(cy, 32));
		                    
		                    dist_sq128 := dx64*dx64 + dy64*dy64;

		                    radius_sq_a := radiusA * radiusA;
		                    radius_sq_b := radiusB * radiusB;
		                    radius_ab_sq := radius_sq_a * radius_sq_b;

		                    if dist_sq128 <= radius_ab_sq then
		                        draw_fig <= '1';
			                else
			                    draw_fig <= '0';
			                end if;

			            when 3 =>
			            	--
		                    --     PARABOLA: y = a(x-h)^2 + k  -- Vertical
		                    --     Suponemos un a = 1/100 para que de forma inicial 
		                    --     se vea mas abierta, a esto se le agregan unos movimientos
		                    --     para evitar la division.
		                    --     y - k = (1/100)(x-h)^2 -> 100(y - k) = a(x-h)^2
		                    --
		                    dx := std_logic_vector(to_unsigned(active_x_int, 32)) - std_logic_vector(to_unsigned(cx, 32));
		                    dy64 := std_logic_vector(to_unsigned(100, 32)) * std_logic_vector(to_unsigned(active_y_int, 32)) - std_logic_vector(to_unsigned(cy, 32));
		                    dist_sq128 := std_logic_vector(to_unsigned(parameterA, 64)) * dx * dx;

		                    if dy64 >= dist_sq128 then
		                        draw_fig <= '1';
		                    else
		                        draw_fig <= '0';
		                    end if;

			            when others =>
			            	--
                            --     HIPERBOLA: (x-h)^2/a^2 - (y-k)^2/b^2 = 1
                            --             Simplificando un poco para hacer menos operaciones queda
                            --             (b(x-h))^2 - (a(y-k))^2 <= (ab)^2
                            --
		                    
		                    dx64 := radiusB * std_logic_vector(to_unsigned(active_x_int, 32)) - std_logic_vector(to_unsigned(cx, 32));
		                    dy64 := radiusA * std_logic_vector(to_unsigned(active_y_int, 32)) - std_logic_vector(to_unsigned(cy, 32));
		                    
		                    dist_sq128 := dx64*dx64 - dy64*dy64;

		                    radius_sq_a := radiusA * radiusA;
		                    radius_sq_b := radiusB * radiusB;
		                    radius_ab_sq := radius_sq_a * radius_sq_b;

		                    if dist_sq128 <= radius_ab_sq then
		                        draw_fig <= '1';
			                else
			                    draw_fig <= '0';
			                end if;
	                end case;
                end if;
            end if;
        end if;
    end process pixel_gen_proc;

    ----------------------------------------------------------------------------
    -- Output assignment for disp_RGB.
    ----------------------------------------------------------------------------
    disp_RGB <= "111" when draw_char_px = '1' else
    			"010" when draw_fig = '1' else "000";

end architecture Behavioral;