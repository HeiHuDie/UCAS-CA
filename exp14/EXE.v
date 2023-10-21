//完成sram的赋值，并且EXE阶段访存指令要拿到addr_ok才可以流向下级
module EXE_stage(
    input wire clk,
    input wire reset,
    input wire MEM_allow,
    input wire ID_to_EXE_valid,
    input wire [250:0] ID_to_EXE_bus,
    
    input wire MEM_exception,
    input wire WB_exception,
    
    output wire EXE_allow,
    output wire [165:0] EXE_to_MEM_bus,
    output wire EXE_to_MEM_valid,
    /**
    output wire data_sram_en,
    output wire [3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    **/
    output wire       data_sram_req,
    output wire       data_sram_wr,
    output wire [1:0] data_sram_size,
    output wire [3:0] data_sram_wstrb,
    output wire [31:0]data_sram_addr,
    output wire [31:0]data_sram_wdata,
    input  wire        data_sram_addr_ok,
     
    output wire [4:0] EXE_dest_bus,
    output wire [31:0] EXE_value_bus,
    output wire EXE_load_bus,
    output wire EXE_res_from_mul_bus,
    
    output wire EXE_csr_re_bus
    
);

    wire alu_complete;
    reg [250:0] ID_to_EXE_bus_r; 
    reg EXE_valid;
    wire EXE_go;
    assign EXE_go = alu_complete && (~data_sram_req || data_sram_req && data_sram_addr_ok);
    assign EXE_allow = ~EXE_valid || EXE_go && MEM_allow;
    assign EXE_to_MEM_valid = EXE_valid && EXE_go;
    always @(posedge clk) begin
        if(reset) begin
            EXE_valid <= 1'd0;
        end else if(WB_exception) begin
            EXE_valid <= 1'd0;
        end else if(EXE_allow) begin
            EXE_valid <= ID_to_EXE_valid;
        end
        if(reset) begin
            ID_to_EXE_bus_r <= 251'd0;
        end else if(ID_to_EXE_valid && EXE_allow) begin
            ID_to_EXE_bus_r <= ID_to_EXE_bus;
        end
    end
    wire [18:0] EXE_alu_op;
    wire EXE_res_from_mem;
    wire EXE_gr_we;
    wire EXE_mem_we;
    wire [4:0] EXE_dest;
    wire [31:0] EXE_alu_src1;
    wire [31:0] EXE_alu_src2;
    wire [31:0] EXE_rkd_value;
    wire [31:0] EXE_alu_result;
    wire [31:0] EXE_pc;
    wire EXE_st_b;
    wire EXE_st_h;
    wire EXE_st_w;
    wire EXE_ld_b;
    wire EXE_ld_bu;
    wire EXE_ld_h;
    wire EXE_ld_hu;
    wire EXE_ld_w;
    
     wire EXE_csr_re;
     wire EXE_csr_we;  //1
     wire [31:0] EXE_csr_wmask;//32
     wire [31:0] EXE_csr_wvalue;//32
     wire [13:0] EXE_csr_num;//14
     wire EXE_inst_syscall;//1
     wire EXE_inst_ertn;//1
     
     wire EXE_inst_rdcntvh;//1
     wire EXE_inst_rdcntvl;//1
     wire EXE_inst_break;//1
     wire EXE_except_ine;//1
     wire EXE_except_int;//1
     wire EXE_pc_adef;
     
    assign{EXE_alu_op,          //19   
           EXE_res_from_mem,    //1
           EXE_gr_we,           //1
           EXE_mem_we,          //1
           EXE_dest,            //5
           EXE_alu_src1,        //32
           EXE_alu_src2,        //32
           EXE_rkd_value,       //32
           EXE_pc,              //32
           EXE_st_b,
           EXE_st_h,
           EXE_st_w,
           EXE_ld_b,
           EXE_ld_bu,
           EXE_ld_h,
           EXE_ld_hu,
           EXE_ld_w,
           EXE_csr_re,  //1
           EXE_csr_we,  //1
           EXE_csr_wmask,//32
           EXE_csr_wvalue,//32
           EXE_csr_num,//14
           EXE_inst_syscall,//1
           EXE_inst_ertn,//1
           
           EXE_inst_rdcntvh,//1
           EXE_inst_rdcntvl,//1
           EXE_inst_break,//1
           EXE_except_ine,//1
           EXE_except_int,//1
           EXE_pc_adef//1
           } = ID_to_EXE_bus_r;
    assign EXE_csr_re_bus = EXE_csr_re & EXE_valid;//
    assign EXE_res_from_mul_bus = EXE_res_from_mul;
    wire EXE_res_from_mul;
    wire EXE_exception;
    assign EXE_exception = EXE_inst_syscall | EXE_inst_ertn | EXE_inst_break | EXE_pc_adef | EXE_except_ine | EXE_except_int | EXE_except_ale;
    assign EXE_dest_bus = EXE_valid ? (EXE_gr_we ? EXE_dest : 5'd0) : 5'd0;
    assign EXE_value_bus = EXE_alu_result;
    assign EXE_load_bus = EXE_res_from_mem;
    wire [31:0] EXE_alu_result_merge;
    wire [31:0] EXE_mul_res;
    assign EXE_alu_result_merge = EXE_res_from_mul ?  EXE_mul_res : EXE_alu_result;      
    alu u_alu(
        .clk        (clk),
        .reset      (reset | WB_exception),//
        .alu_op     (EXE_alu_op),
        .alu_src1   (EXE_alu_src1),
        .alu_src2   (EXE_alu_src2),
        .alu_result (EXE_alu_result),
        .alu_complete(alu_complete),
        .res_from_mul(EXE_res_from_mul),
        .mul_res     (EXE_mul_res)
     );
     assign EXE_to_MEM_bus = {EXE_res_from_mem, //1
                              EXE_gr_we,        //1
                              EXE_dest,         //5
                              EXE_wdata,   //32
                              EXE_pc,           //32
                              EXE_ld_b,
                              EXE_ld_bu,
                              EXE_ld_h,
                              EXE_ld_hu,
                              EXE_ld_w,
                              EXE_csr_re,  //1
                              EXE_csr_we,  //1
                              EXE_csr_wmask,//32
                              EXE_csr_wvalue,//32
                              EXE_csr_num,//14
                              EXE_inst_syscall,//1
                              EXE_inst_ertn,//1
                              
                              EXE_inst_rdcntvh,//1
                              EXE_inst_rdcntvl,//1
                              EXE_inst_break,//1
                              EXE_except_ine,//1
                              EXE_except_int,//1
                              EXE_pc_adef,//1
                              EXE_except_ale,//1
                              
                              data_sram_req
                              };
     
     reg [63:0] EXE_time_cnt;
     always @(posedge clk) begin
        if(reset) begin
            EXE_time_cnt <= 64'd0;
        end else begin
            EXE_time_cnt <= EXE_time_cnt + 64'd1;
        end
     end
     
     wire EXE_except_ale;
     assign EXE_except_ale = ((|EXE_alu_result[1:0]) & (EXE_st_w | EXE_ld_w)|
                                 EXE_alu_result[0] & (EXE_st_h | EXE_ld_hu | EXE_ld_h)) & EXE_valid;
     wire [31:0] EXE_wdata;
     assign EXE_wdata = EXE_inst_rdcntvh ? EXE_time_cnt[63:32] :
                         EXE_inst_rdcntvl ? EXE_time_cnt[31: 0] :
                         EXE_alu_result_merge;
     
     assign data_sram_req = (EXE_res_from_mem | (|data_sram_wstrb)) && EXE_valid && MEM_allow; //写或读时才发送请求且非阻塞
     assign data_sram_wr = (|data_sram_wstrb) && EXE_valid && ~EXE_exception && ~MEM_exception && ~WB_exception;
     assign data_sram_size = {2{EXE_st_b}} & 2'd0 |
                              {2{EXE_st_h}} & 2'd1 |
                              {2{EXE_st_w}} & 2'd2;
     assign data_sram_wstrb[0] = (EXE_st_w | EXE_st_h & ~EXE_alu_result[1] | EXE_st_b & ~EXE_alu_result[0] & ~EXE_alu_result[1]);
     assign data_sram_wstrb[1] = (EXE_st_w | EXE_st_h & ~EXE_alu_result[1] | EXE_st_b &  EXE_alu_result[0] & ~EXE_alu_result[1]);
     assign data_sram_wstrb[2] = (EXE_st_w | EXE_st_h &  EXE_alu_result[1] | EXE_st_b & ~EXE_alu_result[0] &  EXE_alu_result[1]);
     assign data_sram_wstrb[3] = (EXE_st_w | EXE_st_h &  EXE_alu_result[1] | EXE_st_b &  EXE_alu_result[0] &  EXE_alu_result[1]);
     assign data_sram_addr = {EXE_alu_result[31:2],2'd0};
     assign data_sram_wdata[7:0] = EXE_rkd_value[7:0];
     assign data_sram_wdata[15:8] = EXE_st_b ? EXE_rkd_value[7:0] : EXE_rkd_value[15:8];
     assign data_sram_wdata[23:16] = EXE_st_w ? EXE_rkd_value[23:16] : EXE_rkd_value[7:0];
     assign data_sram_wdata[31:24] = EXE_st_w ? EXE_rkd_value[31:24] :
                                      EXE_st_h ? EXE_rkd_value[15:8] : EXE_rkd_value[7:0];
endmodule    
    