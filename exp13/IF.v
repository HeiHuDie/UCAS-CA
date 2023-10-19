module IF_stage(
    input wire clk,
    input wire reset,
    input wire ID_allow,
    input wire [32:0] branch_bus,
    input wire [31:0] inst_sram_rdata,
    
    input wire WB_exception,
    input wire ertn_flush,
    input wire [31:0] ertn_entry,
    input wire [31:0] ex_entry,
    
    output wire IF_to_ID_valid,
    output wire [64:0] IF_to_ID_bus,
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata
);

    wire [31:0] pc_4;
    wire [31:0] branch_pc;
    wire [31:0] next_pc;
    wire branch_valid;

    wire [31:0] IF_inst;
    reg [31:0] IF_pc;

    reg IF_valid;
    wire IF_go;
    wire IF_allow;
    wire preIF_to_IF_valid;

//pre-IF
    assign preIF_to_IF_valid = ~reset;
    assign pc_4 = IF_pc + 3'd4;
    assign next_pc = WB_exception ? ex_entry:
                      ertn_flush ? ertn_entry:
                      branch_valid ? branch_pc : pc_4;

//IF
    assign IF_go = 1'd1;
    assign IF_allow = ~IF_valid || IF_go && ID_allow || ertn_flush || WB_exception;
    assign IF_to_ID_valid = IF_valid && IF_go && ~branch_valid;
    always @(posedge clk) begin
        if(reset) begin
            IF_valid <= 1'd0;
        end else if(IF_allow) begin
            IF_valid <= preIF_to_IF_valid;
        end
        if(reset) begin
            IF_pc <= 32'h1bfffffc;
        end else if(preIF_to_IF_valid && IF_allow) begin
            IF_pc <= next_pc;
        end
    end
    
    wire IF_pc_except;
    assign IF_pc_adef = (|IF_pc[1:0]) & IF_valid;
    
    assign IF_inst = inst_sram_rdata;
    assign {branch_valid,branch_pc} = branch_bus;
    assign IF_to_ID_bus = {IF_inst,IF_pc,IF_pc_adef};
    
    assign inst_sram_en = preIF_to_IF_valid & IF_allow;
    assign inst_sram_we = 4'd0;
    assign inst_sram_addr = next_pc;
    assign inst_sram_wdata = 32'd0;
endmodule
