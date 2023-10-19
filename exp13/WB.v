module WB_stage(
    input wire clk,
    input wire reset,
    input wire MEM_to_WB_valid,
    input wire [190:0] MEM_to_WB_bus,
    
    input wire [31:0] csr_rvalue,
    
    output wire WB_allow,
    output wire [37:0] write_back_bus,
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    
    output wire [4:0] WB_dest_bus,
    output wire [31:0] WB_value_bus,
    
    output wire csr_re,
    output wire [13:0] csr_num,
    output wire csr_we,
    output wire [31:0] csr_wmask,
    output wire [31:0] csr_wvalue,
    output wire ertn_flush,
    output wire WB_exception,
    output wire [5:0] wb_ecode,
    output wire [8:0] wb_esubcode,
    output wire [31:0] WB_pc,
    output wire [31:0] WB_vaddr
);
    reg [190:0] MEM_to_WB_bus_r;
    reg WB_valid;
    wire WB_go;
    assign WB_go = 1'd1;
    assign WB_allow = ~WB_valid || WB_go;
    always @(posedge clk) begin
        if(reset) begin
            WB_valid <= 1'd0;
        end else if(WB_exception | ertn_flush) begin
            WB_valid <= 1'd0;
        end else if(WB_allow) begin
            WB_valid <= MEM_to_WB_valid;
        end
        if(reset) begin
            MEM_to_WB_bus_r <= 191'd0;
        end else if(MEM_to_WB_valid && WB_allow) begin
            MEM_to_WB_bus_r <= MEM_to_WB_bus;
        end
    end
    
    wire WB_csr_re;
    wire WB_csr_we;  //1
    wire [31:0] WB_csr_wmask;//32
    wire [31:0] WB_csr_wvalue;//32
    wire [13:0] WB_csr_num;//14
    wire WB_inst_syscall;//1
    wire WB_inst_ertn;//1
    
    wire WB_inst_rdcntvh;//1
    wire WB_inst_rdcntvl;//1
    wire WB_inst_break;//1
    wire WB_except_ine;//1
    wire WB_except_int;//1
    wire WB_pc_adef;//1
    wire WB_except_ale;
    
    wire WB_gr_we;
    wire [4:0] WB_dest;
    wire [31:0] WB_final_result;
    //wire [31:0] WB_pc;
    assign {WB_gr_we,
            WB_dest,
            WB_final_result,
            WB_pc,
            WB_csr_re,  //1
            WB_csr_we,  //1
            WB_csr_wmask,//32
            WB_csr_wvalue,//32
            WB_csr_num,//14
            WB_inst_syscall,//1
            WB_inst_ertn,//1
            
            WB_vaddr,//32
            WB_inst_rdcntvh,//1
            WB_inst_rdcntvl,//1
            WB_inst_break,//1
            WB_except_ine,//1
            WB_except_int,//1
            WB_pc_adef,//1
            WB_except_ale//1
            } = MEM_to_WB_bus_r;
    
    assign WB_dest_bus = WB_valid ? (WB_gr_we ? WB_dest : 5'd0) : 5'd0 ;
    assign WB_value_bus = rf_wdata;
    
    assign csr_re = WB_csr_re & WB_valid;
    assign csr_num = WB_csr_num & {14{WB_valid}};
    assign csr_we = WB_csr_we & WB_valid;
    assign csr_wmask = WB_csr_wmask & {32{WB_valid}};
    assign csr_wvalue = WB_csr_wvalue & {32{WB_valid}};
    assign ertn_flush = WB_inst_ertn;
    assign WB_exception = (WB_inst_syscall | WB_inst_break | WB_except_ine | WB_except_int | WB_pc_adef | WB_except_ale) & WB_valid;
    assign wb_ecode =  WB_except_int  ? 6'h00 :
                       WB_pc_adef     ? 6'h08 :
                       WB_except_ale  ? 6'h09 :
                       WB_inst_syscall? 6'h0b :
                       WB_inst_break  ? 6'h0c :
                       WB_except_ine  ? 6'h0d :
                       6'd0;
    assign wb_esubcode = 9'd0;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] rf_wdata_r;
    assign rf_we = WB_gr_we && WB_valid && !WB_exception;
    assign rf_waddr = WB_dest;
    assign rf_wdata = csr_re? csr_rvalue:WB_final_result;
    assign write_back_bus = {rf_we,
                             rf_waddr,
                             rf_wdata
                             };
    assign debug_wb_pc       = WB_pc;
    assign debug_wb_rf_we   = {4{rf_we}};
    assign debug_wb_rf_wnum  = WB_dest;
    assign debug_wb_rf_wdata = rf_wdata;
    
endmodule