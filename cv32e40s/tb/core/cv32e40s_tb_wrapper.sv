// Copyright 2018 Robert Balas <balasr@student.ethz.ch>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Wrapper for a CV32E40S testbench, containing CV32E40S, Memory and stdout peripheral
// Contributor: Robert Balas <balasr@student.ethz.ch>
// Module renamed from riscv_wrapper to cv32e40s_tb_wrapper because (1) the
// name of the core changed, and (2) the design has a cv32e40s_wrapper module.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-0.51

module cv32e40s_tb_wrapper
    #(parameter // Parameters used by TB
                INSTR_RDATA_WIDTH = 32,
                RAM_ADDR_WIDTH    = 20,
                BOOT_ADDR         = 'h80,
                DM_HALTADDRESS    = 32'h1A11_0800,
                HART_ID           = 32'h0000_0000,
                IMP_PATCH_ID      = 4'h0
    )
    (input logic         clk_i,
     input logic         rst_ni,

     input logic         fetch_enable_i,
     output logic        tests_passed_o,
     output logic        tests_failed_o,
     output logic [31:0] exit_value_o,
     output logic        exit_valid_o);

    // signals connecting core to memory
    logic                         instr_req;
    logic                         instr_gnt;
    logic                         instr_rvalid;
    logic [31:0]                  instr_addr;
    logic [INSTR_RDATA_WIDTH-1:0] instr_rdata;

    logic                         instr_gntpar;
    logic                         instr_rvalidpar;
    logic [4:0]                   instr_rchk;

    logic                         data_req;
    logic                         data_gnt;
    logic                         data_rvalid;
    logic [31:0]                  data_addr;
    logic                         data_we;
    logic [3:0]                   data_be;
    logic [31:0]                  data_rdata;
    logic [31:0]                  data_wdata;

    logic                         data_gntpar;
    logic                         data_rvalidpar;
    logic [4:0]                   data_rchk;

    // signals to debug unit
    logic                         debug_req;

    // irq signals (not used)
    logic [0:31]                  irq;
    logic [0:4]                   irq_id_in;
    logic                         irq_ack;
    logic [0:4]                   irq_id_out;
    logic                         irq_sec;


    // interrupts (only timer for now)
    assign irq_sec     = '0;

    assign instr_gntpar    = ~instr_gnt;
    assign instr_rvalidpar = ~instr_rvalid;
    assign instr_rchk      = { ^instr_rdata[ 7: 0],
                               ^instr_rdata[15: 8],
                               ^instr_rdata[23:16],
                               ^instr_rdata[31:24],
                               ^{1'b0, 1'b0} }; // {instr_err, exokay}

    assign data_gntpar    = ~data_gnt;
    assign data_rvalidpar = ~data_rvalid;
    assign data_rchk      = { ^data_rdata[ 7: 0],
                              ^data_rdata[15: 8],
                              ^data_rdata[23:16],
                              ^data_rdata[31:24],
                              ^{1'b0, 1'b0} }; // {data_err, exokay}

    //    // core log reports parameter usage and illegal instructions to the logfile
    //    // MIKET: commenting out as the cv32e40s RTL wrapper does this as well.
    //    cv32e40s_core_log
    //     #(
    //          .PULP_XPULP            ( PULP_XPULP            ),
    //          .PULP_CLUSTER          ( PULP_CLUSTER          ),
    //          .FPU                   ( FPU                   ),
    //          .PULP_ZFINX            ( PULP_ZFINX            ),
    //          .NUM_MHPMCOUNTERS      ( NUM_MHPMCOUNTERS      ))
    //    core_log_i(
    //          .clk_i              ( cv32e40s_core_i.id_stage_i.clk              ),
    //          .is_decoding_i      ( cv32e40s_core_i.id_stage_i.is_decoding_o    ),
    //          .illegal_insn_dec_i ( cv32e40s_core_i.id_stage_i.illegal_insn_dec ),
    //          .mhartid_i          ( cv32e40s_core_i.mhartid_i                   ),
    //          .pc_id_i            ( cv32e40s_core_i.pc_id                       )
    //      );

    // instantiate the core
    cv32e40s_core cv32e40s_core_i
        (
         .clk_i                  ( clk_i                 ),
         .rst_ni                 ( rst_ni                ),
         
         .scan_cg_en_i           ( '0                    ),

         // Static configuration
         .boot_addr_i            ( 32'h80                ),
         .dm_exception_addr_i    ( '0                    ),
         .dm_halt_addr_i         ( DM_HALTADDRESS        ),
         .mhartid_i              ( HART_ID               ),
         .mimpid_patch_i         ( IMP_PATCH_ID          ),
         .mtvec_addr_i           ( '0                    ), 

         // Instruction memory interface
         .instr_req_o            ( instr_req             ),        
         .instr_gnt_i            ( instr_gnt             ),      
         .instr_rvalid_i         ( instr_rvalid          ),     
         .instr_addr_o           ( instr_addr            ),    
         .instr_memtype_o        (                       ),
         .instr_prot_o           (                       ),
         .instr_dbg_o            (                       ),
         .instr_rdata_i          ( instr_rdata           ),
         .instr_err_i            ( 1'b0                  ),

         .instr_reqpar_o         (                       ),
         .instr_gntpar_i         ( instr_gntpar          ),
         .instr_rvalidpar_i      ( instr_rvalidpar       ),
         .instr_achk_o           (                       ),
         .instr_rchk_i           ( instr_rchk            ),
         
         // Data memory interface
         .data_req_o             ( data_req              ),        
         .data_gnt_i             ( data_gnt              ),   
         .data_rvalid_i          ( data_rvalid           ),    
         .data_we_o              ( data_we               ),
         .data_be_o              ( data_be               ),
         .data_addr_o            ( data_addr             ),    
         .data_memtype_o         (                       ),
         .data_prot_o            (                       ),
         .data_dbg_o             (                       ),
         .data_wdata_o           ( data_wdata            ),
         .data_rdata_i           ( data_rdata            ),
         .data_err_i             ( 1'b0                  ),

         .data_reqpar_o          (                       ),
         .data_gntpar_i          ( data_gntpar           ),
         .data_rvalidpar_i       ( data_rvalidpar        ),
         .data_achk_o            (                       ),
         .data_rchk_i            ( data_rchk             ),

         // Cycle Count
         .mcycle_o               (                       ),

         // Interrupts verified in UVM environment
         .irq_i                  ( {32{1'b0}}            ),

           // Event wakeup signals
         .wu_wfe_i               ( 1'b0                  ),

         // CLIC Interface
         .clic_irq_i             ( '0                    ),
         .clic_irq_id_i          ( '0                    ),
         .clic_irq_level_i       ( '0                    ),
         .clic_irq_priv_i        ( '0                    ),
         .clic_irq_shv_i         ( '0                    ),

         // Fencei flush handshake
         .fencei_flush_req_o     (                       ),
         .fencei_flush_ack_i     ( 1'b0                  ),

         // Security Alerts
         .alert_major_o          (                       ),
         .alert_minor_o          (                       ),

         // Debug interface
         .debug_req_i            ( 1'b0                  ),
         .debug_havereset_o      (                       ),
         .debug_running_o        (                       ),
         .debug_halted_o         (                       ),
         .debug_pc_valid_o       (                       ),
         .debug_pc_o             (                       ),

         // CPU Control Signals
         .fetch_enable_i         ( fetch_enable_i        ),
         .core_sleep_o           (                       )
      );

    // this handles read to RAM and memory mapped pseudo peripherals
    mm_ram
        #(.RAM_ADDR_WIDTH (RAM_ADDR_WIDTH),
          .INSTR_RDATA_WIDTH (INSTR_RDATA_WIDTH))
    ram_i
        (.clk_i          ( clk_i                                     ),
         .rst_ni         ( rst_ni                                    ),
         .dm_halt_addr_i ( DM_HALTADDRESS                            ),

         .instr_req_i    ( instr_req                                 ),
         .instr_addr_i   ( { {10{1'b0}},
                             instr_addr[RAM_ADDR_WIDTH-1:0]
                           }                                         ),
         .instr_rdata_o  ( instr_rdata                               ),
         .instr_rvalid_o ( instr_rvalid                              ),
         .instr_gnt_o    ( instr_gnt                                 ),

         .data_req_i     ( data_req                                  ),
         .data_addr_i    ( data_addr                                 ),
         .data_we_i      ( data_we                                   ),
         .data_be_i      ( data_be                                   ),
         .data_wdata_i   ( data_wdata                                ),
         .data_rdata_o   ( data_rdata                                ),
         .data_rvalid_o  ( data_rvalid                               ),
         .data_gnt_o     ( data_gnt                                  ),

         .irq_id_i       ( irq_id_out                                ),
         .irq_ack_i      ( irq_ack                                   ),
         .irq_o          ( irq                                       ),

         .debug_req_o    ( debug_req                                 ),

         .pc_core_id_i   ( cv32e40s_core_i.if_id_pipe.pc             ),

         .tests_passed_o ( tests_passed_o                            ),
         .tests_failed_o ( tests_failed_o                            ),
         .exit_valid_o   ( exit_valid_o                              ),
         .exit_value_o   ( exit_value_o                              ));

endmodule // cv32e40s_tb_wrapper
