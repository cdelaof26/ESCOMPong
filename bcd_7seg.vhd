-- Paquete para Decodificar el dato de RAM en display de 7 segmentos
-- Con el sistema numerico hexadecimal
-- Fecha: marzo de 2025

-- Declaracion de las bibliotecas

Library ieee;
use ieee.std_logic_1164.all;

-- Declaracion del paquete

package bcd_7seg is

        -- Declaracion de constantes para los display

    constant bcd0 : std_logic_vector(6 downto 0) := "1000000";
    constant bcd1 : std_logic_vector(6 downto 0) := "1111001";
    constant bcd2 : std_logic_vector(6 downto 0) := "0100100";
    constant bcd3 : std_logic_vector(6 downto 0) := "0110000";
    constant bcd4 : std_logic_vector(6 downto 0) := "0011001";
    constant bcd5 : std_logic_vector(6 downto 0) := "0010010";
    constant bcd6 : std_logic_vector(6 downto 0) := "0000010";
    constant bcd7 : std_logic_vector(6 downto 0) := "1111000";
    constant bcd8 : std_logic_vector(6 downto 0) := "0000000";
    constant bcd9 : std_logic_vector(6 downto 0) := "0010000";
    constant bcdA : std_logic_vector(6 downto 0) := "0001000";
    constant bcdB : std_logic_vector(6 downto 0) := "0000011";
    constant bcdC : std_logic_vector(6 downto 0) := "1000110";
    constant bcdD : std_logic_vector(6 downto 0) := "0100001";
    constant bcdE : std_logic_vector(6 downto 0) := "0000110";
    constant bcdF : std_logic_vector(6 downto 0) := "0001110";

        -- Declaracion de constantes para la fuente 16x16

    constant font0 : std_logic_vector(6 downto 0) := "0110000";
    constant font1 : std_logic_vector(6 downto 0) := "0110001";
    constant font2 : std_logic_vector(6 downto 0) := "0110010";
    constant font3 : std_logic_vector(6 downto 0) := "0110011";
    constant font4 : std_logic_vector(6 downto 0) := "0110100";
    constant font5 : std_logic_vector(6 downto 0) := "0110101";
    constant font6 : std_logic_vector(6 downto 0) := "0110110";
    constant font7 : std_logic_vector(6 downto 0) := "0110111";
    constant font8 : std_logic_vector(6 downto 0) := "0111000";
    constant font9 : std_logic_vector(6 downto 0) := "0111001";
    constant fontE : std_logic_vector(6 downto 0) := "1000101";

        
      -- Declaracion del procedimiento
             
    procedure bcd_conv (signal bcd : in std_logic_vector (3 downto 0);
    					signal D   : out std_logic_vector (6 downto 0));

  	procedure bcd_conv_font (variable bcd   : in std_logic_vector (3 downto 0);
                             signal char_id : out std_logic_vector (6 downto 0));

end bcd_7seg;

--    Declaracion del cuerpo del paquete

package body bcd_7seg is

    -- Inicio del procedimiento

    procedure bcd_conv (signal bcd : in std_logic_vector (3 downto 0);
                        signal D : out std_logic_vector(6 downto 0)) 
    is begin
        case bcd is  -- Seleccion de constante dependiendo del valor de entrada
            when "0000" => D <= bcd0;
            when "0001" => D <= bcd1;
            when "0010" => D <= bcd2;
            when "0011" => D <= bcd3;
            when "0100" => D <= bcd4;
            when "0101" => D <= bcd5;
            when "0110" => D <= bcd6;
            when "0111" => D <= bcd7;
            when "1000" => D <= bcd8;
            when "1001" => D <= bcd9;
            when "1010" => D <= bcdA;
            when "1011" => D <= bcdB;
            when "1100" => D <= bcdC;
            when "1101" => D <= bcdD;
            when "1110" => D <= bcdE;
            when others => D <= bcdF;
        end case;
    end bcd_conv;  -- Fin del procedimiento


    procedure bcd_conv_font (variable bcd   : in std_logic_vector (3 downto 0);
                             signal char_id : out std_logic_vector (6 downto 0))
    is begin
        case bcd is  -- Seleccion de constante dependiendo del valor de entrada
            when "0000" => char_id <= font0;
            when "0001" => char_id <= font1;
            when "0010" => char_id <= font2;
            when "0011" => char_id <= font3;
            when "0100" => char_id <= font4;
            when "0101" => char_id <= font5;
            when "0110" => char_id <= font6;
            when "0111" => char_id <= font7;
            when "1000" => char_id <= font8;
            when "1001" => char_id <= font9;
            when others => char_id <= fontE;
        end case;
    end bcd_conv_font;  -- Fin del procedimiento
end bcd_7seg;  --    Fin del cuerpo del paquete
