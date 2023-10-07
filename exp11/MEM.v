module MEM_stage(
    input wire clk,
    input wire reset,
    input wire WB_allow,
    input wire EXE_to_MEM_valid,
    input wire [75:0] EXE_to_MEM_bus,
    input wire [31:0] data_sram_rdata,
    
    output wire MEM_allow,
    output wire MEM_to_WB_valid,
    output wire [69:0] MEM_to_WB_bus,
    
    output wire [4:0] MEM_dest_bus,
    output wire [31:0] MEM_value_bus
);
    reg [75:0] EXE_to_MEM_bus_r;
    reg MEM_valid;
    wire MEM_go;
    assign MEM_go = 1'd1;
    assign MEM_allow = ~MEM_valid || MEM_go && WB_allow;
    assign MEM_to_WB_valid = MEM_valid && MEM_go;
    always @(posedge clk) begin
        if(reset) begin
            MEM_valid <= 1'd0;
        end else if(MEM_allow) begin
            MEM_valid <= EXE_to_MEM_valid;
        end
        
        if(EXE_to_MEM_valid && MEM_allow) begin
            EXE_to_MEM_bus_r <= EXE_to_MEM_bus;
        end
    end
    wire [31:0] MEM_final_result;
    wire [31:0] mem_result;
    wire MEM_res_from_mem;
    wire MEM_gr_we;
    wire [4:0] MEM_dest;
    wire [31:0] MEM_alu_result;
    wire [31:0] MEM_pc;
    wire MEM_ld_b;
    wire MEM_ld_bu;
    wire MEM_ld_h;
    wire MEM_ld_hu;
    wire MEM_ld_w;
    assign {MEM_res_from_mem, //1
            MEM_gr_we,        //1
            MEM_dest,         //5
            MEM_alu_result,   //32
            MEM_pc,            //32
            MEM_ld_b,
            MEM_ld_bu,
            MEM_ld_h,
            MEM_ld_hu,
            MEM_ld_w
            } = EXE_to_MEM_bus_r;
    
    assign MEM_dest_bus = MEM_valid ? (MEM_gr_we ? MEM_dest : 5'd0) : 5'd0;
    assign MEM_value_bus = MEM_final_result;
    
    assign MEM_to_WB_bus = {MEM_gr_we,
                            MEM_dest,
                            MEM_final_result,
                            MEM_pc
                            };
    
    wire [31:0] load_res;
    wire [7:0] load_data_b;
    wire [15:0] load_data_h;
    wire load_signed;
    assign load_signed = MEM_ld_b | MEM_ld_h;
    assign mem_result = data_sram_rdata;
    assign load_data_b = mem_result[{MEM_alu_result[1:0],3'b0}+:8];
    assign load_data_h = mem_result[{MEM_alu_result[1],4'b0}+:16];
    assign load_res = {32{MEM_ld_b | MEM_ld_bu}} & {{24{load_data_b[7] & load_signed}},load_data_b} |
                       {32{MEM_ld_h | MEM_ld_hu}} & {{16{load_data_h[15] & load_signed}},load_data_h}|
                       {32{MEM_ld_w}} & mem_result;
    assign MEM_final_result = MEM_res_from_mem ? load_res : MEM_alu_result;
endmodule