library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity tb is
end tb;

architecture Behavioral of tb is

    function slv_to_str(slv : std_logic_vector) return string is
        variable result : string(1 to slv'length);
        variable idx    : integer := 1;
    begin
        for i in slv'range loop
            case slv(i) is
                when '0'    => result(idx) := '0';
                when '1'    => result(idx) := '1';
                when 'X'    => result(idx) := 'X';
                when 'Z'    => result(idx) := 'Z';
                when 'U'    => result(idx) := 'U';
                when others => result(idx) := '?';
            end case;
            idx := idx + 1;
        end loop;
        return result;
    end function;

    -- Konstante
    constant CLK_PERIOD   : time    := 10 ns;   -- 100 MHz
    constant BRAM_DEPTH   : integer := 10000;
    constant BRAM_INIT    : string  := "C:/bram_init.txt";

    -- Signali ka BRAM portu A
    signal clka  : std_logic := '0';
    signal ena   : std_logic := '1';
    signal wea   : std_logic := '0';
    signal addra : std_logic_vector(13 downto 0) := (others => '0');
    signal dina  : std_logic_vector(23 downto 0) := (others => '0');
    signal douta : std_logic_vector(23 downto 0);

    -- Signali ka BRAM portu B
    signal enb   : std_logic := '0';
    signal web   : std_logic := '0';
    signal addrb : std_logic_vector(13 downto 0) := (others => '0');
    signal dinb  : std_logic_vector(23 downto 0) := (others => '0');
    signal doutb : std_logic_vector(23 downto 0);

    -- Statusni signali
    signal load_done : std_logic := '0';

begin

    -- Instanciranje BRAM-a
    uut : entity work.bram
        port map (
            clka  => clka,
            ena   => ena,
            wea   => wea,
            addra => addra,
            dina  => dina,
            douta => douta,
            enb   => enb,
            web   => web,
            addrb => addrb,
            dinb  => dinb,
            doutb => doutb
        );

    -- Generisanje takta
    clk_proc : process
    begin
        clka <= '0';
        wait for CLK_PERIOD / 2;
        clka <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Ucitavanje inicijalizacionog fajla i upisivanje u BRAM
    load_proc : process
        file     init_file : text;
        variable row       : line;
        variable data_slv  : std_logic_vector(23 downto 0);
        variable addr_int  : integer := 0;
        variable open_ok   : file_open_status;
    begin
        wea <= '0';

        wait until rising_edge(clka);
        wait until rising_edge(clka);

        -- Otvori inicijalizacioni fajl
        file_open(open_ok, init_file, BRAM_INIT, read_mode);

        if open_ok /= open_ok then
        report "GRESKA: Ne mogu otvoriti fajl: " & BRAM_INIT severity failure;
        end if;

        report "Pocetak ucitavanja fajla: " & BRAM_INIT severity note;

        addr_int := 0;
        wea <= '1';
        ena <= '1';

        while (not endfile(init_file)) and (addr_int < BRAM_DEPTH) loop
            readline(init_file, row);

            if row'length > 0 then
                read(row, data_slv);

                addra <= std_logic_vector(to_unsigned(addr_int, 14));
                dina  <= data_slv;

                wait until rising_edge(clka);

                addr_int := addr_int + 1;
            end if;
        end loop;

        file_close(init_file);

        wea <= '0';

        report "Ucitavanje zavrseno. Upisano " & integer'image(addr_int) & " lokacija u BRAM." severity note;

        load_done <= '1';

        -- Verifikacija:
        wait until rising_edge(clka);

        -- Provera lokacije 0
        addra <= std_logic_vector(to_unsigned(0, 14));
        wait until rising_edge(clka);
        report "Provera - adresa 0 => douta = " & slv_to_str(douta) severity note;

        -- Provera lokacije 505
        addra <= std_logic_vector(to_unsigned(505, 14));
        wait until rising_edge(clka);
        report "Provera - adresa 505 => douta = " & slv_to_str(douta) severity note;

        -- Provera lokacije 9999
        addra <= std_logic_vector(to_unsigned(9999, 14));
        wait until rising_edge(clka);
        report "Provera - adresa 9999 => douta = " & slv_to_str(douta) severity note;

        report "Testbench zavrsen." severity note;

        wait;
    end process;

end Behavioral;
