//设置的MEM的缓存，访存指令要拿到data_ok才可以流入下级
module MEM_stage(
    input wire clk,
    input wire reset,
    input wire WB_allow,
    input wire EXE_to_MEM_valid,
    input wire [165:0] EXE_to_MEM_bus,
    
    input wire        data_sram_data_ok,
    input wire [31:0] data_sram_rdata,
    
    input wire WB_exception,
    
    output wire MEM_allow,
    output wire MEM_to_WB_valid,
    output wire [190:0] MEM_to_WB_bus,
    
    output wire [4:0] MEM_dest_bus,
    output wire [31:0] MEM_value_bus,
    
    output wire MEM_csr_re_bus,
    output wire MEM_exception
);
    reg [165:0] EXE_to_MEM_bus_r;
    reg MEM_valid;
    wire MEM_go;
    assign MEM_go = ~MEM_mem_req || (MEM_mem_req && data_sram_data_ok);
    assign MEM_allow = ~MEM_valid || MEM_go && WB_allow;
    assign MEM_to_WB_valid = MEM_valid && MEM_go;
    always @(posedge clk) begin
        if(reset) begin
            MEM_valid <= 1'd0;
        end else if(WB_exception) begin
            MEM_valid <= 1'd0;
        end else if(MEM_allow) begin
            MEM_valid <= EXE_to_MEM_valid;
        end
        if(reset) begin
            EXE_to_MEM_bus_r <= 166'd0;
        end else if(EXE_to_MEM_valid && MEM_allow) begin
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
    
    wire MEM_csr_we;  //1
    wire [31:0] MEM_csr_wmask;//32
    wire [31:0] MEM_csr_wvalue;//32
    wire [13:0] MEM_csr_num;//14
    wire MEM_inst_syscall;//1
    wire MEM_inst_ertn;//1
    
    wire MEM_inst_rdcntvh;//1
    wire MEM_inst_rdcntvl;//1
    wire MEM_inst_break;//1
    wire MEM_except_ine;//1
    wire MEM_except_int;//1
    wire MEM_pc_adef;//1
    wire MEM_except_ale;
    wire MEM_mem_req;
    assign MEM_exception = MEM_inst_syscall | MEM_inst_ertn | MEM_inst_break | MEM_except_ine | MEM_except_int | MEM_pc_adef | MEM_except_ale;
    assign {MEM_res_from_mem, //1
            MEM_gr_we,        //1
            MEM_dest,         //5
            MEM_alu_result,   //32
            MEM_pc,            //32
            MEM_ld_b,
            MEM_ld_bu,
            MEM_ld_h,
            MEM_ld_hu,
            MEM_ld_w,
            MEM_csr_re,  //1
            MEM_csr_we,  //1
            MEM_csr_wmask,//32
            MEM_csr_wvalue,//32
            MEM_csr_num,//14
            MEM_inst_syscall,//1
            MEM_inst_ertn,//1
            
            MEM_inst_rdcntvh,//1
            MEM_inst_rdcntvl,//1
            MEM_inst_break,//1
            MEM_except_ine,//1
            MEM_except_int,//1
            MEM_pc_adef,//1
            MEM_except_ale,//1
            
            MEM_mem_req
            } = EXE_to_MEM_bus_r;
    assign MEM_csr_re_bus = MEM_csr_re & MEM_valid;
    assign MEM_dest_bus = MEM_valid ? (MEM_gr_we ? MEM_dest : 5'd0) : 5'd0;
    assign MEM_value_bus = MEM_final_result;
    
    assign MEM_to_WB_bus = {MEM_gr_we,
                            MEM_dest,
                            MEM_final_result,
                            MEM_pc,
                            MEM_csr_re,  //1
                            MEM_csr_we,  //1
                            MEM_csr_wmask,//32
                            MEM_csr_wvalue,//32
                            MEM_csr_num,//14
                            MEM_inst_syscall,//1
                            MEM_inst_ertn,//1
                            
                            MEM_alu_result,//32
                            MEM_inst_rdcntvh,//1
                            MEM_inst_rdcntvl,//1
                            MEM_inst_break,//1
                            MEM_except_ine,//1
                            MEM_except_int,//1
                            MEM_pc_adef,//1
                            MEM_except_ale//1
                            };
    
    wire [31:0] load_res;
    wire [7:0] load_data_b;
    wire [15:0] load_data_h;
    wire load_signed;
    //data reg
    reg [31:0] mem_result_r;
    reg data_ok_r;
    always @(posedge clk) begin
        if (reset) begin
            data_ok_r   <= 1'b0;
            mem_result_r  <= 32'b0;
        end else if (WB_exception) begin
            data_ok_r   <= 1'b0;
            mem_result_r  <= 32'b0;
        end else if (data_sram_data_ok && !(MEM_to_WB_valid && WB_allow)) begin
            data_ok_r   <= 1'b1;
            mem_result_r  <= data_sram_rdata;
        end else if (MEM_to_WB_valid && WB_allow) begin
            data_ok_r   <= 1'b0;
            mem_result_r  <= 32'b0;
        end
    end
    
    assign load_signed = MEM_ld_b | MEM_ld_h;
    assign mem_result = {32{ data_sram_data_ok             }} & data_sram_rdata
                       | {32{~data_sram_data_ok && data_ok_r}} & mem_result_r;
    assign load_data_b = mem_result[{MEM_alu_result[1:0],3'b0}+:8];
    assign load_data_h = mem_result[{MEM_alu_result[1],4'b0}+:16];
    assign load_res = {32{MEM_ld_b | MEM_ld_bu}} & {{24{load_data_b[7] & load_signed}},load_data_b} |
                       {32{MEM_ld_h | MEM_ld_hu}} & {{16{load_data_h[15] & load_signed}},load_data_h}|
                       {32{MEM_ld_w}} & mem_result;
    assign MEM_final_result = MEM_res_from_mem ? load_res : MEM_alu_result;
endmodule