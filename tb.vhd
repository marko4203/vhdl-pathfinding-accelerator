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

    constant CLK_PERIOD : time    := 10 ns;   -- 100 MHz
    constant BRAM_DEPTH : integer := 10000;
    constant BRAM_INIT  : string  := "C:/bram_init.txt";

    constant START_X : integer := 5;
    constant START_Y : integer := 5;
    constant END_X   : integer := 99;
    constant END_Y   : integer := 99;

    constant START_COORD : std_logic_vector(13 downto 0) :=
        std_logic_vector(to_unsigned(START_X, 7)) & std_logic_vector(to_unsigned(START_Y, 7));
    constant END_COORD   : std_logic_vector(13 downto 0) :=
        std_logic_vector(to_unsigned(END_X, 7))   & std_logic_vector(to_unsigned(END_Y, 7));

    signal clka  : std_logic := '0';
    signal ena   : std_logic := '1';
    signal wea   : std_logic := '0';
    signal addra : std_logic_vector(13 downto 0) := (others => '0');
    signal dina  : std_logic_vector(23 downto 0) := (others => '0');
    signal douta : std_logic_vector(23 downto 0);

    signal enb   : std_logic := '0';
    signal web   : std_logic := '0';
    signal addrb : std_logic_vector(13 downto 0) := (others => '0');
    signal dinb  : std_logic_vector(23 downto 0) := (others => '0');
    signal doutb : std_logic_vector(23 downto 0);

    signal load_done : std_logic := '0';

    signal rst_ip       : std_logic := '0';

    signal cpu_we_ip    : std_logic := '0';
    signal cpu_addr_ip  : std_logic_vector(1 downto 0) := (others => '0');
    signal cpu_wdata_ip : std_logic_vector(13 downto 0) := (others => '0');

    signal bram_en_ip   : std_logic;
    signal bram_we_ip   : std_logic;
    signal bram_addr_ip : std_logic_vector(13 downto 0);
    signal bram_din_ip  : std_logic_vector(23 downto 0);
    signal bram_dout_ip : std_logic_vector(23 downto 0);

    signal irq_ip : std_logic;

begin

    bramTB : entity work.bram
        port map (
            clka  => clka,
            
            ena   => ena,
            wea   => wea,
            addra => addra,
            dina  => dina,
            douta => douta,
            
            enb   => bram_en_ip,
            web   => bram_we_ip,
            addrb => bram_addr_ip,
            dinb  => bram_din_ip,
            doutb => bram_dout_ip
        );

    uut : entity work.pathfinder_ip
        generic map (
            GRID_SIZE => 100,
            ADDR_BITS => 14,
            DATA_BITS => 24
        )
        port map (
            clk       => clka,
            rst       => rst_ip,

            cpu_we    => cpu_we_ip,
            cpu_addr  => cpu_addr_ip,
            cpu_wdata => cpu_wdata_ip,

            bram_en   => bram_en_ip,
            bram_we   => bram_we_ip,
            bram_addr => bram_addr_ip,
            bram_din  => bram_din_ip,
            bram_dout => bram_dout_ip,

            irq       => irq_ip
        );

    clk_proc : process
    begin
        clka <= '0';
        wait for CLK_PERIOD / 2;
        clka <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    irq_monitor : process
    begin
        wait until rst_ip = '1';

        wait until rising_edge(irq_ip) or irq_ip = '1';

        report "============================================================"
            severity note;
        report "[IRQ] IP digao irq_ip at " &
               time'image(now) severity note;
        report "============================================================"
            severity note;
        wait until rising_edge(clka);

        report "Simulation ended normally after IRQ." severity failure;
    end process;

    load_proc : process
        file     init_file : text;
        variable row       : line;
        variable data_slv  : std_logic_vector(23 downto 0);
        variable addr_int  : integer := 0;
        variable open_ok   : file_open_status;
    begin
        rst_ip <= '0';
        wea    <= '0';

        wait until rising_edge(clka);
        wait until rising_edge(clka);

        file_open(open_ok, init_file, BRAM_INIT, read_mode);

        if open_ok /= open_ok then
            report "GRESKA: Nije moguce otvoriti fajl: " & BRAM_INIT severity failure;
        end if;

        report "------------------------------------------------------------"
            severity note;
        report "[LOAD] Pocetak ucitavanja fajla: " & BRAM_INIT severity note;

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

        report "[LOAD] Ucitavanje zavrseno. Upisano " &
               integer'image(addr_int) & " lokacija u BRAM." severity note;

        load_done <= '1';

        report "------------------------------------------------------------"
            severity note;
        report "[RESET] Dizanje reseta na 1, IP se pokrece."
            severity note;

        rst_ip <= '1';
        wait until rising_edge(clka);   -- IP registruje rst='1'

        report "[RESET] IP is now active." severity note;

        report "------------------------------------------------------------"
            severity note;
        report "[CPU] Writing START register: (" &
               integer'image(START_X) & "," & integer'image(START_Y) &
               ") -> cpu_wdata = " & slv_to_str(START_COORD)
            severity note;

        cpu_addr_ip  <= "00";
        cpu_wdata_ip <= START_COORD;
        cpu_we_ip    <= '1';
        wait until rising_edge(clka);
        cpu_we_ip    <= '0';

        wait until rising_edge(clka);

        report "[CPU] Writing END register: (" &
               integer'image(END_X) & "," & integer'image(END_Y) &
               ") -> cpu_wdata = " & slv_to_str(END_COORD)
            severity note;

        cpu_addr_ip  <= "01";
        cpu_wdata_ip <= END_COORD;
        cpu_we_ip    <= '1';
        wait until rising_edge(clka);
        cpu_we_ip    <= '0';

        wait until rising_edge(clka);

        report "[CPU] Sending START pulse (cpu_addr = ""10"")";
        report "------------------------------------------------------------";
        report "[RUN] Pathfinder running. Waiting for IRQ...";
        report "------------------------------------------------------------";

        cpu_addr_ip  <= "10";
        cpu_wdata_ip <= (others => '0');
        cpu_we_ip    <= '1';
        wait until rising_edge(clka);
        cpu_we_ip    <= '0';

        cpu_addr_ip  <= (others => '0');
        cpu_wdata_ip <= (others => '0');

        wait;
    end process;

end Behavioral;