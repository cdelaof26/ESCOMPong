Library ieee;
use ieee.std_logic_1164.all;

package bcd2font is
    constant font_0 : std_logic_vector(6 downto 0) := "0110000";
    constant font_1 : std_logic_vector(6 downto 0) := "0110001";
    constant font_2 : std_logic_vector(6 downto 0) := "0110010";
    constant font_3 : std_logic_vector(6 downto 0) := "0110011";
    constant font_4 : std_logic_vector(6 downto 0) := "0110100";
    constant font_5 : std_logic_vector(6 downto 0) := "0110101";
    constant font_6 : std_logic_vector(6 downto 0) := "0110110";
    constant font_7 : std_logic_vector(6 downto 0) := "0110111";
    constant font_8 : std_logic_vector(6 downto 0) := "0111000";
    constant font_9 : std_logic_vector(6 downto 0) := "0111001";
    constant font_E : std_logic_vector(6 downto 0) := "1000101";

  	procedure bcd_conv_font (variable bcd   : in std_logic_vector (3 downto 0);
                             signal char_id : out std_logic_vector (6 downto 0));
end bcd2font;

package body bcd2font is
    procedure bcd_conv_font (variable bcd   : in std_logic_vector (3 downto 0);
                             signal char_id : out std_logic_vector (6 downto 0))
    is begin
        case bcd is
            when "0000" => char_id <= font_0;
            when "0001" => char_id <= font_1;
            when "0010" => char_id <= font_2;
            when "0011" => char_id <= font_3;
            when "0100" => char_id <= font_4;
            when "0101" => char_id <= font_5;
            when "0110" => char_id <= font_6;
            when "0111" => char_id <= font_7;
            when "1000" => char_id <= font_8;
            when "1001" => char_id <= font_9;
            when others => char_id <= font_E;
        end case;
    end bcd_conv_font;
end bcd2font;
