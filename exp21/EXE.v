//完成sram的赋值，并且EXE阶段访存指令要拿到addr_ok才可以流向下级
module EXE_stage(
    input wire clk,
    input wire reset,

    //流水级控制及bus
    input wire MEM_allow,
    input wire ID_to_EXE_valid,
    input wire [264:0] ID_to_EXE_bus,
    
    output wire EXE_allow,
    output wire [185:0] EXE_to_MEM_bus,
    output wire EXE_to_MEM_valid,
    //流水级控制及bus
    
    //访存
    output wire       data_sram_req,
    output wire       data_sram_wr,
    output wire [1:0] data_sram_size,
    output wire [3:0] data_sram_wstrb,
    output wire [31:0]data_sram_addr,
    output wire [31:0]data_sram_wdata,
    input  wire       data_sram_addr_ok,
    //访存

    //对ID级进行阻塞
    output wire [4:0] EXE_dest_bus,
    output wire [31:0] EXE_value_bus,
    output wire EXE_load_bus,
    output wire EXE_res_from_mul_bus,
    
    output wire EXE_csr_re_bus,
    output wire [13:0] EXE_csr_num,//14
    output wire EXE_csr_we,//1
    //对ID级进行阻塞 
    
    input  wire MEM_exception,
    input  wire WB_exception,
    //异常及中断

    output wire EXE_inst_tlbsrch,
    output wire EXE_inst_invtlb,
    output wire [4:0]  EXE_invtlb_op,
    output wire [31:0] rj_asid,
    output wire [31:0] rk_vppn,
    output wire [31:0] mem_vaddr,

    input  wire [3:0]  s1_index,
    input  wire        s1_found,
    input  wire [31:0] mem_paddr,
    // output wire [31:0] inst_vppn
    //给出查询端口以及用法(虚实地址转换或者srch等)
    input  wire        to_EXE_ex_ade,
    input  wire        to_EXE_ex_tlbr,
    input  wire        to_EXE_ex_pil,
    input  wire        to_EXE_ex_pis,
    input  wire        to_EXE_ex_ppi,
    input  wire        to_EXE_ex_pme
    //返回异常
);
    //流水级控制及bus
    wire alu_complete;
    reg [264:0] ID_to_EXE_bus_r; 
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
            ID_to_EXE_bus_r <= 265'd0;
        end else if(ID_to_EXE_valid && EXE_allow) begin
            ID_to_EXE_bus_r <= ID_to_EXE_bus;
        end
    end
    //流水级控制及bus


    //由于流水级阻塞需要前递的一些bus
    assign EXE_csr_re_bus = EXE_csr_re & EXE_valid;//
    assign EXE_dest_bus = EXE_valid ? (EXE_gr_we ? EXE_dest : 5'd0) : 5'd0;
    assign EXE_value_bus = EXE_alu_result;
    assign EXE_load_bus = EXE_res_from_mem;
    assign EXE_res_from_mul_bus = EXE_res_from_mul;//这个是在alu内部给出的
    assign EXE_csr_we = EXE_csr_we_not_valid && EXE_valid;
    //由于流水级阻塞需要前递的一些bus   


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
    wire EXE_inst_tlbrd;
    wire EXE_inst_tlbwr;   
    wire EXE_inst_tlbfill; 
    wire EXE_inst_invtlb_not_ex;
    wire EXE_st_b;
    wire EXE_st_h;
    wire EXE_st_w;
    wire EXE_ld_b;
    wire EXE_ld_bu;
    wire EXE_ld_h;
    wire EXE_ld_hu;
    wire EXE_ld_w;
    
    wire EXE_csr_re;
    wire EXE_csr_we_not_valid;
    wire [31:0] EXE_csr_wmask;//32
    wire [31:0] EXE_csr_wvalue;//32
    wire EXE_inst_syscall;//1
    wire EXE_inst_ertn;//1
     
    wire EXE_inst_rdcntvh;//1
    wire EXE_inst_rdcntvl;//1
    wire EXE_inst_break;//1
    wire EXE_except_ine;//1
    wire EXE_except_int;//1
    wire EXE_pc_adef;

    wire EXE_PreIF_ex_ade;
    wire EXE_PreIF_ex_tlbr;
    wire EXE_PreIF_ex_pif;
    wire EXE_PreIF_ex_ppi;
     
    assign{EXE_alu_op,          //19   
           EXE_res_from_mem,    //1
           EXE_gr_we,           //1
           EXE_mem_we,          //1
           EXE_dest,            //5
           EXE_alu_src1,        //32
           EXE_alu_src2,        //32
           EXE_rkd_value,       //32
           EXE_pc,              //32
           EXE_inst_tlbsrch,
           EXE_inst_tlbrd,
           EXE_inst_tlbwr,   
           EXE_inst_tlbfill, 
           EXE_inst_invtlb_not_ex,
           EXE_invtlb_op,
           EXE_st_b,
           EXE_st_h,
           EXE_st_w,
           EXE_ld_b,
           EXE_ld_bu,
           EXE_ld_h,
           EXE_ld_hu,
           EXE_ld_w,
           EXE_csr_re,  //1
           EXE_csr_we_not_valid,  //1
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

           EXE_PreIF_ex_ade,
           EXE_PreIF_ex_tlbr,
           EXE_PreIF_ex_pif,
           EXE_PreIF_ex_ppi
           } = ID_to_EXE_bus_r;

    assign rj_asid = EXE_alu_src1;
    assign rk_vppn = EXE_alu_src2;

    //EXE级报出的异常
    wire EXE_except_ale;
    wire EXE_exception;

    wire EXE_EXE_ex_ade;
    wire EXE_EXE_ex_tlbr;
    wire EXE_EXE_ex_pil;
    wire EXE_EXE_ex_pis;
    wire EXE_EXE_ex_ppi;
    wire EXE_EXE_ex_pme;

    assign EXE_EXE_ex_ade  = to_EXE_ex_ade  && (EXE_res_from_mem | (|data_sram_wstrb));
    assign EXE_EXE_ex_tlbr = to_EXE_ex_tlbr && (EXE_res_from_mem | (|data_sram_wstrb));
    assign EXE_EXE_ex_pil  = to_EXE_ex_pil  && (EXE_res_from_mem | (|data_sram_wstrb));
    assign EXE_EXE_ex_pis  = to_EXE_ex_pis  && (EXE_res_from_mem | (|data_sram_wstrb));
    assign EXE_EXE_ex_ppi  = to_EXE_ex_ppi  && (EXE_res_from_mem | (|data_sram_wstrb));
    assign EXE_EXE_ex_pme  = to_EXE_ex_pme  && (EXE_res_from_mem | (|data_sram_wstrb));//需要满足这是一条访存操作才能报异常

    assign EXE_exception =  (EXE_inst_syscall | EXE_inst_ertn  | EXE_inst_break | EXE_pc_adef | 
                            EXE_except_ine | EXE_except_int   | EXE_except_ale | EXE_PreIF_ex_ade|
                            EXE_PreIF_ex_tlbr | EXE_PreIF_ex_pif | EXE_PreIF_ex_ppi | EXE_EXE_ex_ade|
                            EXE_EXE_ex_tlbr | EXE_EXE_ex_pil | EXE_EXE_ex_pis | EXE_EXE_ex_ppi | EXE_EXE_ex_pme) && EXE_valid;//EXE级异常，包含了所有的异常。如果有异常则不能发取指请求
    
    //EXE级关于异常处理
    wire EXE_ex;//由于invtlb不能被本级传回的tlb异常影响，故加了一个异常信号，MEM与WB的异常删除只是为了时序好，但有bug
    assign EXE_ex = (EXE_inst_syscall | EXE_inst_ertn  | EXE_inst_break | EXE_pc_adef | 
                     EXE_except_ine | EXE_except_int   | EXE_PreIF_ex_ade|
                     EXE_PreIF_ex_tlbr | EXE_PreIF_ex_pif | EXE_PreIF_ex_ppi) && EXE_valid;
    
    assign EXE_except_ale = ((|EXE_alu_result[1:0]) & (EXE_st_w | EXE_ld_w)|
                                 EXE_alu_result[0] & (EXE_st_h | EXE_ld_hu | EXE_ld_h)) & EXE_valid;
    assign EXE_inst_invtlb = EXE_inst_invtlb_not_ex && EXE_valid && ~EXE_ex; //&& ~MEM_exception && ~WB_exception; 
    //访存地址异常 
    //EXE级关于异常处理

    
    //alu中集成了除法器和乘法器，是否可以将结果取舍判断集成在alu内？
    wire [31:0] EXE_alu_result_merge;
    wire [31:0] EXE_mul_res;
    wire        EXE_res_from_mul;
    alu u_alu(
        .clk        (clk),
        .reset      (reset | WB_exception | ~EXE_valid),//
        .alu_op     (EXE_alu_op),
        .alu_src1   (EXE_alu_src1),
        .alu_src2   (EXE_alu_src2),
        .alu_result (EXE_alu_result),
        .alu_complete(alu_complete),
        .res_from_mul(EXE_res_from_mul),
        .mul_res     (EXE_mul_res)
     );
    reg [63:0] EXE_time_cnt;
    always @(posedge clk) begin
        if(reset) begin
            EXE_time_cnt <= 64'd0;
        end else begin
            EXE_time_cnt <= EXE_time_cnt + 64'd1;
        end
    end
    wire [31:0] EXE_wdata;
    assign EXE_alu_result_merge = EXE_res_from_mul ?  EXE_mul_res : EXE_alu_result;   
    assign EXE_wdata =  EXE_inst_rdcntvh ? EXE_time_cnt[63:32] :
                        EXE_inst_rdcntvl ? EXE_time_cnt[31: 0] :
                        EXE_alu_result_merge;
    //alu中集成了除法器和乘法器，是否可以将结果取舍判断集成在alu内？
    


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
                              EXE_inst_tlbsrch,
                              EXE_inst_tlbrd,
                              EXE_inst_tlbwr,   
                              EXE_inst_tlbfill, 
                              EXE_inst_invtlb,
                              s1_index,
                              s1_found,
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

                              EXE_PreIF_ex_ade,
                              EXE_PreIF_ex_tlbr,
                              EXE_PreIF_ex_pif,
                              EXE_PreIF_ex_ppi,
                              EXE_EXE_ex_ade,
                              EXE_EXE_ex_tlbr,
                              EXE_EXE_ex_pil,
                              EXE_EXE_ex_pis,
                              EXE_EXE_ex_ppi,
                              EXE_EXE_ex_pme,
                              
                              data_sram_req
                              };

     

    assign mem_vaddr = EXE_alu_src1 + EXE_alu_src2;//锟斤拷锟斤拷锟斤拷alu锟斤拷锟叫诧拷锟斤拷
    //访存操作 
    assign data_sram_req = (EXE_res_from_mem | (|data_sram_wstrb)) && EXE_valid && MEM_allow && ~EXE_exception && ~MEM_exception && ~WB_exception; //写锟斤拷锟绞憋拷欧锟斤拷锟斤拷锟斤拷锟斤拷曳锟斤拷锟斤拷锟?
    assign data_sram_wr = (|data_sram_wstrb) && EXE_valid && ~EXE_exception && ~MEM_exception && ~WB_exception;
    assign data_sram_size = {2{EXE_st_b}} & 2'd0 |
                              {2{EXE_st_h}} & 2'd1 |
                              {2{EXE_st_w}} & 2'd2;
    assign data_sram_wstrb[0] = (EXE_st_w | EXE_st_h & ~EXE_alu_result[1] | EXE_st_b & ~EXE_alu_result[0] & ~EXE_alu_result[1]);
    assign data_sram_wstrb[1] = (EXE_st_w | EXE_st_h & ~EXE_alu_result[1] | EXE_st_b &  EXE_alu_result[0] & ~EXE_alu_result[1]);
    assign data_sram_wstrb[2] = (EXE_st_w | EXE_st_h &  EXE_alu_result[1] | EXE_st_b & ~EXE_alu_result[0] &  EXE_alu_result[1]);
    assign data_sram_wstrb[3] = (EXE_st_w | EXE_st_h &  EXE_alu_result[1] | EXE_st_b &  EXE_alu_result[0] &  EXE_alu_result[1]);
    assign data_sram_addr = mem_paddr;
    assign data_sram_wdata[7:0] = EXE_rkd_value[7:0];
    assign data_sram_wdata[15:8] = EXE_st_b ? EXE_rkd_value[7:0] : EXE_rkd_value[15:8];
    assign data_sram_wdata[23:16] = EXE_st_w ? EXE_rkd_value[23:16] : EXE_rkd_value[7:0];
    assign data_sram_wdata[31:24] = EXE_st_w ? EXE_rkd_value[31:24] :
                                      EXE_st_h ? EXE_rkd_value[15:8] : EXE_rkd_value[7:0];
    //访存操作 

endmodule    
    