module EXE_stage(
    input wire clk,
    input wire reset,
    input wire MEM_allow,
    input wire ID_to_EXE_valid,
    input wire [162:0] ID_to_EXE_bus,
    
    output wire EXE_allow,
    output wire [75:0] EXE_to_MEM_bus,
    output wire EXE_to_MEM_valid,
    output wire data_sram_en,
    output wire [3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    
    output wire [4:0] EXE_dest_bus,
    output wire [31:0] EXE_value_bus,
    output wire EXE_load_bus
);
    wire alu_complete;
    reg [162:0] ID_to_EXE_bus_r; 
    reg EXE_valid;
    wire EXE_go;
    assign EXE_go = alu_complete;
    assign EXE_allow = ~EXE_valid || EXE_go && MEM_allow;
    assign EXE_to_MEM_valid = EXE_valid && EXE_go;
    always @(posedge clk) begin
        if(reset) begin
            EXE_valid <= 1'd0;
        end else if(EXE_allow) begin
            EXE_valid <= ID_to_EXE_valid;
        end
        
        if(ID_to_EXE_valid && EXE_allow) begin
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
           EXE_ld_w
           } = ID_to_EXE_bus_r;
    
    assign EXE_dest_bus = EXE_valid ? (EXE_gr_we ? EXE_dest : 5'd0) : 5'd0;
    assign EXE_value_bus = EXE_alu_result;
    assign EXE_load_bus = EXE_res_from_mem;
           
    alu u_alu(
        .clk        (clk),
        .reset      (reset),
        .alu_op     (EXE_alu_op),
        .alu_src1   (EXE_alu_src1),
        .alu_src2   (EXE_alu_src2),
        .alu_result (EXE_alu_result),
        .alu_complete(alu_complete)
     );
     
     assign EXE_to_MEM_bus = {EXE_res_from_mem, //1
                              EXE_gr_we,        //1
                              EXE_dest,         //5
                              EXE_alu_result,   //32
                              EXE_pc,           //32
                              EXE_ld_b,
                              EXE_ld_bu,
                              EXE_ld_h,
                              EXE_ld_hu,
                              EXE_ld_w
                              };
     
     assign data_sram_we[0] = (EXE_st_w | EXE_st_h & ~EXE_alu_result[1] | EXE_st_b & ~EXE_alu_result[0] & ~EXE_alu_result[1]) & EXE_valid;
     assign data_sram_we[1] = (EXE_st_w | EXE_st_h & ~EXE_alu_result[1] | EXE_st_b &  EXE_alu_result[0] & ~EXE_alu_result[1]) & EXE_valid;
     assign data_sram_we[2] = (EXE_st_w | EXE_st_h &  EXE_alu_result[1] | EXE_st_b & ~EXE_alu_result[0] &  EXE_alu_result[1]) & EXE_valid;
     assign data_sram_we[3] = (EXE_st_w | EXE_st_h &  EXE_alu_result[1] | EXE_st_b &  EXE_alu_result[0] &  EXE_alu_result[1]) & EXE_valid;
     //assign data_sram_en = (EXE_res_from_mem || (|data_sram_we)) && EXE_valid ;
     assign data_sram_en = 1'd1;
     assign data_sram_addr = {EXE_alu_result[31:2],2'd0};
     assign data_sram_wdata[7:0] = EXE_rkd_value[7:0];
     assign data_sram_wdata[15:8] = EXE_st_b ? EXE_rkd_value[7:0] : EXE_rkd_value[15:8];
     assign data_sram_wdata[23:16] = EXE_st_w ? EXE_rkd_value[23:16] : EXE_rkd_value[7:0];
     assign data_sram_wdata[31:24] = EXE_st_w ? EXE_rkd_value[31:24] :
                                      EXE_st_h ? EXE_rkd_value[15:8] : EXE_rkd_value[7:0];
endmodule    
    