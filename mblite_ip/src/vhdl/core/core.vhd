----------------------------------------------------------------------------------------------
-- This file is part of mblite_ip.
--
-- mblite_ip is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- mblite_ip is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with mblite_ip.  If not, see <http://www.gnu.org/licenses/>.

-- Input file         : core.vhd
-- Design name        : core
-- Author             : Muhammad Bin Rosli
-- Company            : 
--                    : 
--                    : 
--
-- Description        : Top level entity of the processor modified
--                    : for Vivado IP Packager
--
-- Date               : 01 November 2015
--
----------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library mblite;
use mblite.config_pkg.all;
use mblite.core_pkg.all;

entity core is generic
(
    CFG_IMEM_WIDTH : integer := 32;
    CFG_IMEM_SIZE : integer := 16;
    
    CFG_DMEM_WIDTH : integer := 32;
    CFG_DMEM_SIZE : integer := 32;

    G_INTERRUPT  : boolean := true;
    G_USE_HW_MUL : boolean := true;
    G_USE_BARREL : boolean := true;
    G_DEBUG      : boolean := true
);
port
(
    -- instruction memory interface
    imem_dat_i : in std_logic_vector(CFG_IMEM_WIDTH - 1 downto 0);
    imem_adr_o : out std_logic_vector(CFG_IMEM_SIZE - 1 downto 0);
    imem_ena_o : out std_logic;
    
    -- data memory interfa
    dmem_dat_i : in std_logic_vector(CFG_DMEM_WIDTH - 1 downto 0);
    dmem_ena_i : in std_logic;
        
    dmem_dat_o : out std_logic_vector(CFG_DMEM_WIDTH - 1 downto 0);
    dmem_adr_o : out std_logic_vector(CFG_DMEM_SIZE - 1 downto 0);
    dmem_sel_o : out std_logic_vector(3 downto 0);
    dmem_we_o  : out std_logic;
    dmem_ena_o : out std_logic;
        
    int_i  : in std_logic;
    rst_i  : in std_logic;
    clk_i  : in std_logic
);
end core;

architecture arch of core is

    signal imem_o : imem_out_type;
    signal dmem_o : dmem_out_type;
    signal imem_i : imem_in_type;
    signal dmem_i : dmem_in_type;

    signal fetch_i : fetch_in_type;
    signal fetch_o : fetch_out_type;

    signal decode_i : decode_in_type;
    signal decode_o : decode_out_type;

    signal gprf_o : gprf_out_type;

    signal exec_i : execute_in_type;
    signal exec_o : execute_out_type;

    signal mem_i : mem_in_type;
    signal mem_o : mem_out_type;

    signal ena_i : std_logic;

begin
    
    -- connecting the entity port
    imem_i.dat_i <= imem_dat_i;
    imem_adr_o <= imem_o.adr_o;
    imem_ena_o <= imem_o.ena_o;
    
    dmem_i.dat_i <= dmem_dat_i;
    dmem_i.ena_i <= dmem_ena_i;
    
    dmem_dat_o <= dmem_o.dat_o;
    dmem_adr_o <= dmem_o.adr_o;
    dmem_sel_o <= dmem_o.sel_o;
    dmem_we_o  <= dmem_o.we_o;
    dmem_ena_o <= dmem_o.ena_o;

    ena_i <= dmem_i.ena_i;

    fetch_i.hazard        <= decode_o.hazard;
    fetch_i.branch        <= exec_o.branch;
    fetch_i.branch_target <= exec_o.alu_result(CFG_IMEM_SIZE - 1 downto 0);

    fetch0 : fetch port map
    (
        fetch_o => fetch_o,
        imem_o  => imem_o,
        fetch_i => fetch_i,
        rst_i   => rst_i,
        ena_i   => ena_i,
        clk_i   => clk_i
    );

    decode_i.program_counter   <= fetch_o.program_counter;
    decode_i.instruction       <= imem_i.dat_i;
    decode_i.ctrl_wrb          <= mem_o.ctrl_wrb;
    decode_i.ctrl_mem_wrb      <= mem_o.ctrl_mem_wrb;
    decode_i.mem_result        <= dmem_i.dat_i;
    decode_i.alu_result        <= mem_o.alu_result;
    decode_i.interrupt         <= int_i;
    decode_i.flush_id          <= exec_o.flush_id;

    decode0: decode generic map
    (
        G_INTERRUPT  => G_INTERRUPT,
        G_USE_HW_MUL => G_USE_HW_MUL,
        G_USE_BARREL => G_USE_BARREL,
        G_DEBUG      => G_DEBUG
    )
    port map
    (
        decode_o => decode_o,
        decode_i => decode_i,
        gprf_o   => gprf_o,
        ena_i    => ena_i,
        rst_i    => rst_i,
        clk_i    => clk_i
    );

    exec_i.fwd_dec              <= decode_o.fwd_dec;
    exec_i.fwd_dec_result       <= decode_o.fwd_dec_result;

    exec_i.dat_a                <= gprf_o.dat_a_o;
    exec_i.dat_b                <= gprf_o.dat_b_o;
    exec_i.dat_d                <= gprf_o.dat_d_o;
    exec_i.reg_a                <= decode_o.reg_a;
    exec_i.reg_b                <= decode_o.reg_b;

    exec_i.imm                  <= decode_o.imm;
    exec_i.program_counter      <= decode_o.program_counter;
    exec_i.ctrl_wrb             <= decode_o.ctrl_wrb;
    exec_i.ctrl_mem             <= decode_o.ctrl_mem;
    exec_i.ctrl_ex              <= decode_o.ctrl_ex;

    exec_i.fwd_mem              <= mem_o.ctrl_wrb;
    exec_i.mem_result           <= dmem_i.dat_i;
    exec_i.alu_result           <= mem_o.alu_result;
    exec_i.ctrl_mem_wrb         <= mem_o.ctrl_mem_wrb;

    execute0 : execute generic map
    (
        G_USE_HW_MUL => G_USE_HW_MUL,
        G_USE_BARREL => G_USE_BARREL
    )
    port map
    (
        exec_o => exec_o,
        exec_i => exec_i,
        ena_i  => ena_i,
        rst_i  => rst_i,
        clk_i  => clk_i
    );

    mem_i.alu_result      <= exec_o.alu_result;
    mem_i.program_counter <= exec_o.program_counter;
    mem_i.branch          <= exec_o.branch;
    mem_i.dat_d           <= exec_o.dat_d;
    mem_i.ctrl_wrb        <= exec_o.ctrl_wrb;
    mem_i.ctrl_mem        <= exec_o.ctrl_mem;
    mem_i.mem_result      <= dmem_i.dat_i;

    mem0 : mem port map
    (
        mem_o  => mem_o,
        dmem_o => dmem_o,
        mem_i  => mem_i,
        ena_i  => ena_i,
        rst_i  => rst_i,
        clk_i  => clk_i
    );

end arch;
