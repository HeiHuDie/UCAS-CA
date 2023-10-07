module WB_stage(
    input wire clk,
    input wire reset,
    input wire MEM_to_WB_valid,
    input wire [69:0] MEM_to_WB_bus,
    
    output wire WB_allow,
    output wire [37:0] write_back_bus,
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    
    output wire [4:0] WB_dest_bus,
    output wire [31:0] WB_value_bus
);
    reg [69:0] MEM_to_WB_bus_r;
    reg WB_valid;
    wire WB_go;
    assign WB_go = 1'd1;
    assign WB_allow = ~WB_valid || WB_go;
    always @(posedge clk) begin
        if(reset) begin
            WB_valid <= 1'd0;
        end else if(WB_allow) begin
            WB_valid <= MEM_to_WB_valid;
        end
        
        if(MEM_to_WB_valid && WB_allow) begin
            MEM_to_WB_bus_r <= MEM_to_WB_bus;
        end
    end
    wire WB_gr_we;
    wire [4:0] WB_dest;
    wire [31:0] WB_final_result;
    wire [31:0] WB_pc;
    assign {WB_gr_we,
            WB_dest,
            WB_final_result,
            WB_pc
            } = MEM_to_WB_bus_r;
    
    assign WB_dest_bus = WB_valid ? (WB_gr_we ? WB_dest : 5'd0) : 5'd0 ;
    assign WB_value_bus = WB_final_result;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    assign rf_we = WB_gr_we && WB_valid;
    assign rf_waddr = WB_dest;
    assign rf_wdata = WB_final_result;
    assign write_back_bus = {rf_we,
                             rf_waddr,
                             rf_wdata
                             };
    assign debug_wb_pc       = WB_pc;
    assign debug_wb_rf_we   = {4{rf_we}};
    assign debug_wb_rf_wnum  = WB_dest;
    assign debug_wb_rf_wdata = WB_final_result;
    
endmodule