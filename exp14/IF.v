//设置了next_pc与inst的缓存
module IF_stage(
    input wire clk,
    input wire reset,
    input wire ID_allow,
    input wire [32:0] branch_bus,
    
    input wire WB_exception,
    input wire ertn_flush,
    input wire [31:0] ertn_entry,
    input wire [31:0] ex_entry,
    
    output wire IF_to_ID_valid,
    output wire [64:0] IF_to_ID_bus,
    /**
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata
    **/
    output wire       inst_sram_req,
    output wire       inst_sram_wr,
    output wire [1:0] inst_sram_size,
    output wire [3:0] inst_sram_wstrb,
    output wire [31:0]inst_sram_addr,
    output wire [31:0]inst_sram_wdata,
    input  wire       inst_sram_addr_ok,
    input  wire       inst_sram_data_ok,
    input  wire [31:0]inst_sram_rdata,
    
    input  wire       ID_br_stall
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
    wire preIF_go;
    assign preIF_go = inst_sram_req & inst_sram_addr_ok;//握手成功
    assign preIF_to_IF_valid = preIF_go;
    assign pc_4 = IF_pc + 3'd4;
    assign next_pc = WB_exception ? ex_entry:
                      ertn_flush ? ertn_entry:
                      branch_valid ? branch_pc : pc_4;
//exp14 reg
    reg [31:0] next_pc_r;
    reg next_pc_has_r;
    always @(posedge clk) begin
        if(reset) begin
            next_pc_r <= 32'd0;
            next_pc_has_r <= 1'd0;
        end else if(WB_exception | ertn_flush | branch_valid | preIF_go) begin
            next_pc_r <= next_pc;
            next_pc_has_r <= 1'd1;
        end else if(preIF_go) begin
            next_pc_r <= 32'd0;
            next_pc_has_r <= 1'd0;
        end
    end   
    reg [1:0] cancel_cnt_r;
    reg [31:0] IF_inst_r;
    reg IF_inst_has_r;
    always @(posedge clk) begin
        if(reset) begin
            cancel_cnt_r <= 2'd0;
        end 
        if((WB_exception | ertn_flush | branch_valid) && preIF_go && ~inst_sram_data_ok)begin//
            cancel_cnt_r <= cancel_cnt_r + 2'd2;
        end else if((WB_exception | ertn_flush | branch_valid) && ~inst_sram_data_ok)begin
            cancel_cnt_r <= cancel_cnt_r + 2'd1;
        end else if((WB_exception | ertn_flush | branch_valid) && preIF_go) begin
            cancel_cnt_r <= cancel_cnt_r + 2'd1;
        end
        if(reset) begin
            IF_inst_r <= 32'd0;
            IF_inst_has_r <= 1'd0;
        end else if(inst_sram_data_ok && ~ID_allow && cancel_cnt_r == 2'd0) begin
            IF_inst_r <= inst_sram_rdata;
            IF_inst_has_r <= 1'd1;
        end else if(inst_sram_data_ok && ~ID_allow && cancel_cnt_r != 2'd0) begin
            IF_inst_r <= 32'd0;
            IF_inst_has_r <= 1'd0;
            cancel_cnt_r <= cancel_cnt_r - 1;
        end else if(IF_inst_has_r && ID_allow) begin
            IF_inst_r <= 32'd0;
            IF_inst_has_r <= 1'd0;
        end
    end
//IF
    assign IF_go = 1'd1;
    assign IF_allow = ~IF_valid || IF_go && ID_allow || ertn_flush || WB_exception;
    //assign IF_to_ID_valid = IF_valid && IF_go && ~branch_valid;
    assign IF_to_ID_valid = IF_valid && IF_go && ~(branch_valid || ertn_flush || WB_exception);
    always @(posedge clk) begin
        if(reset) begin
            IF_valid <= 1'd0;
        end else if(IF_allow) begin
            IF_valid <= preIF_to_IF_valid;
        end
        if(reset) begin
            IF_pc <= 32'h1bfffffc;
        end else if(preIF_to_IF_valid && IF_allow && next_pc_has_r) begin
            IF_pc <= next_pc_r;
        end else if(preIF_to_IF_valid && IF_allow && !next_pc_has_r) begin
            IF_pc <= next_pc;
        end
    end
    
    wire IF_pc_except;
    assign IF_pc_adef = (|IF_pc[1:0]) & IF_valid;
    
    assign IF_inst = IF_inst_has_r ? IF_inst_r : inst_sram_rdata;//
    assign {branch_valid,branch_pc} = branch_bus;
    assign IF_to_ID_bus = {IF_inst,IF_pc,IF_pc_adef};
    
    assign inst_sram_req = IF_allow & ~reset & ~ID_br_stall;
    assign inst_sram_wr = 1'd0;
    assign inst_sram_wstrb = 4'd0;
    assign inst_sram_addr = next_pc_r;
    assign inst_sram_wdata = 32'd0;
endmodule
