module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    reg reset;
    always @(posedge clk) reset <= ~resetn;
    wire ID_allow;
    wire EXE_allow;
    wire MEM_allow;
    wire WB_allow;
    wire IF_to_ID_valid;
    wire ID_to_EXE_valid;
    wire EXE_to_MEM_valid;
    wire MEM_to_WB_valid;
    wire [63:0] IF_to_ID_bus;
    wire [162:0] ID_to_EXE_bus;
    wire [75:0] EXE_to_MEM_bus;
    wire [69:0] MEM_to_WB_bus;
    wire [37:0] write_back_bus;
    wire [32:0] branch_bus;
    
    wire [4:0] EXE_dest_bus;
    wire [4:0] MEM_dest_bus;
    wire [4:0] WB_dest_bus;
    wire [31:0] EXE_value_bus;
    wire [31:0] MEM_value_bus;
    wire [31:0] WB_value_bus;
    wire EXE_load_bus;
    
    //IF
    IF_stage IF_stage(
        .clk (clk),
        .reset (reset),
        .ID_allow (ID_allow),
        .branch_bus (branch_bus),
        .IF_to_ID_valid (IF_to_ID_valid),
        .IF_to_ID_bus (IF_to_ID_bus),
        .inst_sram_en (inst_sram_en),
        .inst_sram_we (inst_sram_we),
        .inst_sram_addr (inst_sram_addr),
        .inst_sram_wdata (inst_sram_wdata),
        .inst_sram_rdata (inst_sram_rdata)

    );
    //ID
    ID_stage ID_stage(
        .clk (clk),
        .reset (reset),
        .EXE_allow (EXE_allow),
        .ID_allow (ID_allow),
        .IF_to_ID_valid (IF_to_ID_valid),
        .IF_to_ID_bus (IF_to_ID_bus),
        .ID_to_EXE_valid (ID_to_EXE_valid),
        .ID_to_EXE_bus (ID_to_EXE_bus),
        .branch_bus (branch_bus),
        .write_back_bus (write_back_bus),
        .EXE_dest_bus (EXE_dest_bus),
        .MEM_dest_bus (MEM_dest_bus),
        .WB_dest_bus (WB_dest_bus),
        .EXE_value_bus (EXE_value_bus),
        .MEM_value_bus (MEM_value_bus),
        .WB_value_bus (WB_value_bus),
        .EXE_load_bus (EXE_load_bus) 
    ); 
    //EXE
    EXE_stage EXE_stage(
        .clk (clk),
        .reset (reset),
        .MEM_allow (MEM_allow),
        .EXE_allow (EXE_allow),
        .ID_to_EXE_valid (ID_to_EXE_valid),
        .ID_to_EXE_bus (ID_to_EXE_bus),
        .EXE_to_MEM_valid (EXE_to_MEM_valid),
        .EXE_to_MEM_bus (EXE_to_MEM_bus),
        .data_sram_en (data_sram_en),
        .data_sram_we (data_sram_we),
        .data_sram_addr (data_sram_addr),
        .data_sram_wdata (data_sram_wdata),
        .EXE_dest_bus (EXE_dest_bus),
        .EXE_value_bus (EXE_value_bus),
        .EXE_load_bus (EXE_load_bus)
    );
    //MEM
    MEM_stage MEM_stage(
        .clk (clk),
        .reset (reset),
        .WB_allow (WB_allow),
        .MEM_allow (MEM_allow),
        .EXE_to_MEM_valid (EXE_to_MEM_valid),
        .EXE_to_MEM_bus (EXE_to_MEM_bus),
        .MEM_to_WB_valid (MEM_to_WB_valid),
        .MEM_to_WB_bus (MEM_to_WB_bus),
        .data_sram_rdata (data_sram_rdata),
        .MEM_dest_bus (MEM_dest_bus),
        .MEM_value_bus (MEM_value_bus)
    );
    //WB
    WB_stage WB_stage(
        .clk (clk),
        .reset (reset),
        .WB_allow (WB_allow),
        .MEM_to_WB_valid (MEM_to_WB_valid),
        .MEM_to_WB_bus (MEM_to_WB_bus),
        .write_back_bus (write_back_bus),
        .debug_wb_pc (debug_wb_pc),
        .debug_wb_rf_we (debug_wb_rf_we),
        .debug_wb_rf_wnum (debug_wb_rf_wnum),
        .debug_wb_rf_wdata (debug_wb_rf_wdata),
        .WB_dest_bus (WB_dest_bus),
        .WB_value_bus (WB_value_bus)
    );
endmodule
