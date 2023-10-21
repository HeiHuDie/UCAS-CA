//ID级的修改在于要生成br_stall信号，其作用在在于告知pre_IF不要生成错误的next_pc,修改处在29 458 459 482
module ID_stage(
    input wire clk,
    input wire reset,
    input wire EXE_allow,
    input wire IF_to_ID_valid,
    input wire [64:0] IF_to_ID_bus,
    input wire [37:0] write_back_bus,
    
    input wire [4:0] EXE_dest_bus,
    input wire [4:0] MEM_dest_bus,
    input wire [4:0] WB_dest_bus,
    input wire [31:0] EXE_value_bus,
    input wire [31:0] MEM_value_bus,
    input wire [31:0] WB_value_bus,
    input wire EXE_load_bus,
    input wire EXE_res_from_mul_bus,
    
    input wire MEM_csr_re_bus,
    input wire EXE_csr_re_bus,
    input wire WB_exception,
    input wire has_int,
    
    output wire ID_allow,
    output wire ID_to_EXE_valid,
    output wire [250:0] ID_to_EXE_bus,
    output wire [32:0] branch_bus,
    
    output wire ID_br_stall

);
    
    reg [64:0] IF_to_ID_bus_r;
    wire ID_pc_adef;
    wire ID_except_ine;
    wire ID_except_int;
    
    
    wire [31:0] ID_inst;
    wire [31:0] ID_pc;
    assign {ID_inst,ID_pc,ID_pc_adef} = IF_to_ID_bus_r;
    
    //block
    wire rj_block;
    wire rk_block;
    wire rd_block;
    assign rj_block = inst_add_w | inst_addi_w | inst_sub_w | inst_ld_w | inst_st_w | inst_bne | inst_beq | inst_jirl | inst_slt | inst_sltu | inst_slli_w | inst_srli_w | inst_srai_w | inst_and | inst_or | inst_nor | inst_nor | inst_xor |
                       inst_slti  | inst_sltui  | inst_andi  | inst_ori  | inst_xori | inst_sll_w | inst_srl_w | inst_sra_w | inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu |
                       inst_blt | inst_bltu | inst_bge | inst_bgeu | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h | inst_csrxchg;
    assign rk_block = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | inst_or | inst_nor | inst_xor | inst_sll_w | inst_srl_w | inst_sra_w | inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu;
    assign rd_block = inst_bne | inst_beq | inst_st_w |inst_blt | inst_bltu | inst_bge | inst_bgeu | inst_st_b | inst_st_h | inst_csrwr | inst_csrxchg;
    
    
    reg ID_valid;
    wire ID_go;
    /**assign ID_go = ~((rj_block && (rj != 5'd0) && ((rj == EXE_dest_bus) || (rj == MEM_dest_bus) || (rj == WB_dest_bus))) 
                  || (rd_block && (rd != 5'd0) && ((rd == EXE_dest_bus) || (rd == MEM_dest_bus) || (rd == WB_dest_bus)))
                  || (rk_block && (rk != 5'd0) && ((rk == EXE_dest_bus) || (rk == MEM_dest_bus) || (rk == WB_dest_bus))));
    **/
    /**assign ID_go = ~((rj_block && (|rj) && (rj == EXE_dest_bus) && (EXE_load_bus | EXE_csr_re_bus))
                    ||(rd_block && (|rd) && (rd == EXE_dest_bus) && (EXE_load_bus | EXE_csr_re_bus))
                    ||(rk_block && (|rk) && (rk == EXE_dest_bus) && (EXE_load_bus | EXE_csr_re_bus))
                    ||(rj_block && (|rj) && (rj == MEM_dest_bus) && MEM_csr_re_bus)
                    ||(rd_block && (|rd) && (rd == MEM_dest_bus) && MEM_csr_re_bus)
                    ||(rk_block && (|rk) && (rk == MEM_dest_bus) && MEM_csr_re_bus));
                    **/
     assign ID_go = ~((rj_block && (|rj) && (rj == EXE_dest_bus) && (EXE_load_bus | EXE_res_from_mul_bus | EXE_csr_re_bus))
                     ||(rd_block && (|rd) && (rd == EXE_dest_bus) && (EXE_load_bus | EXE_res_from_mul_bus | EXE_csr_re_bus))
                     ||(rk_block && (|rk) && (rk == EXE_dest_bus) && (EXE_load_bus | EXE_res_from_mul_bus | EXE_csr_re_bus))
                     ||(rj_block && (|rj) && (rj == MEM_dest_bus) && MEM_csr_re_bus)
                     ||(rd_block && (|rd) && (rd == MEM_dest_bus) && MEM_csr_re_bus)
                     ||(rk_block && (|rk) && (rk == MEM_dest_bus) && MEM_csr_re_bus));               
    
    assign ID_allow = ~ID_valid || ID_go && EXE_allow;
    assign ID_to_EXE_valid = ID_valid && ID_go;
    always@(posedge clk) begin
        if(reset) begin
            ID_valid <= 1'd0;
        end else if(WB_exception) begin
            ID_valid <= 1'd0;
        end else if(ID_allow) begin
            ID_valid <= IF_to_ID_valid;
        end
        
        if(reset) begin
            IF_to_ID_bus_r <= 65'd0;
        end else if(IF_to_ID_valid && ID_allow) begin
            IF_to_ID_bus_r <= IF_to_ID_bus;
        end
    end
    
    wire [ 5:0] op_31_26;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;
    
    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;
    
    wire        inst_add_w;
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_lu12i_w;
    //exp10
    wire        inst_slti;
    wire        inst_sltui;
    wire        inst_andi;
    wire        inst_ori;
    wire        inst_xori;
    wire        inst_sll_w;
    wire        inst_srl_w;
    wire        inst_sra_w;
    wire        inst_pcaddu12i;
    wire        inst_mul_w;
    wire        inst_mulh_w;
    wire        inst_mulh_wu;
    wire        inst_div_w;
    wire        inst_mod_w;
    wire        inst_div_wu;
    wire        inst_mod_wu;
    //exp11
    wire        inst_blt;
    wire        inst_bge;
    wire        inst_bltu;
    wire        inst_bgeu;
    wire        inst_ld_b;
    wire        inst_ld_h;
    wire        inst_ld_bu;
    wire        inst_ld_hu;
    wire        inst_st_b;
    wire        inst_st_h;
    //exp12
    wire        inst_csrrd;
    wire        inst_csrwr;
    wire        inst_csrxchg;
    wire        inst_ertn;
    wire        inst_syscall;
    //exp13
    wire        inst_rdcntid;
    wire        inst_rdcntvl;
    wire        inst_rdcntvh;
    wire        inst_break;
    //alu_op
    wire [18:0] alu_op;
    //wire        load_op;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        res_from_mem;
    wire        dst_is_r1;
    wire        dst_is_rj;
    wire        gr_we;
    wire        mem_we;
    wire        src_reg_is_rd;
    wire [4: 0] dest;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;
    
    //ID csr
    wire        ID_csr_re;
    wire [13:0] ID_csr_num;
    wire        ID_csr_we;
    wire [31:0] ID_csr_wmask;
    wire [31:0] ID_csr_wvalue;


    assign ID_csr_re = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid;
    assign ID_csr_num = {14{~inst_rdcntid}} & ID_inst[23:10]
                        |{14{inst_rdcntid}} & 14'h40;
    assign ID_csr_we = inst_csrwr | inst_csrxchg;
    assign ID_csr_wmask = {32{inst_csrxchg}} & rj_value_by | {32{inst_csrwr}};
    assign ID_csr_wvalue = rkd_value_by;

    
    assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;
    assign src_reg_is_rd = inst_beq | inst_bne  | inst_blt | inst_bltu | 
                           inst_bge | inst_bgeu | inst_st_w| inst_st_h |
                           inst_st_b| inst_csrwr| inst_csrxchg;
    assign mem_we        = inst_st_w;
    assign src2_is_imm   = inst_slli_w |
                           inst_srli_w |
                           inst_srai_w |
                           inst_addi_w |
                           inst_ld_w   |
                           inst_st_w   |
                           inst_lu12i_w|
                           inst_jirl   |
                           inst_bl     |
                           inst_andi   |
                           inst_ori    |
                           inst_xori   |
                           inst_slti   |
                           inst_sltui  |
                           inst_pcaddu12i|
                           inst_ld_b   |
                           inst_ld_bu  |
                           inst_ld_h   |
                           inst_ld_hu  |
                           inst_st_b   |
                           inst_st_h;
    assign imm = src2_is_4 ? 32'h4                      :
                 need_si20 ? {i20[19:0], 12'b0}         :
                 (need_ui5 | need_si12) ? {{20{i12[11]}}, i12[11:0]} :
                 {20'b0,i12[11:0]};


    
    wire        need_ui5;
    wire        need_ui12;
    wire        need_si12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        src2_is_4;
    
    assign i12  = ID_inst[21:10];
    assign i20  = ID_inst[24: 5];
    assign i16  = ID_inst[25:10];
    assign i26  = {ID_inst[ 9: 0], ID_inst[25:10]};
    
    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;
    wire        rf_we   ;
    wire [ 4:0] rf_waddr;
    wire [31:0] rf_wdata;
    
    //分解
    assign op_31_26  = ID_inst[31:26];
    assign op_25_22  = ID_inst[25:22];
    assign op_21_20  = ID_inst[21:20];
    assign op_19_15  = ID_inst[19:15];
    assign rd   = ID_inst[ 4: 0];
    assign rj   = ID_inst[ 9: 5];
    assign rk   = ID_inst[14:10];
    
    //decode
    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

    assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_jirl   = op_31_26_d[6'h13];
    assign inst_b      = op_31_26_d[6'h14];
    assign inst_bl     = op_31_26_d[6'h15];
    assign inst_beq    = op_31_26_d[6'h16];
    assign inst_bne    = op_31_26_d[6'h17];
    assign inst_lu12i_w= op_31_26_d[6'h05] & ~ID_inst[25];
    //exp10
    assign inst_slti = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    assign inst_andi = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    assign inst_sll_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
    assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ID_inst[25];
    assign inst_mul_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    assign inst_mulh_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
    assign inst_div_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    assign inst_mod_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
    //exp11
    assign inst_blt = op_31_26_d[6'h18];
    assign inst_bge = op_31_26_d[6'h19];
    assign inst_bltu = op_31_26_d[6'h1a];
    assign inst_bgeu = op_31_26_d[6'h1b];
    assign inst_ld_b = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
    assign inst_ld_h = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
    assign inst_ld_w = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_b = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    assign inst_st_h = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
    assign inst_st_w = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_ld_bu = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    assign inst_ld_hu = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
    //exp12
    assign inst_csrrd   = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h00);
    assign inst_csrwr   = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h01);
    assign inst_csrxchg = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & ~inst_csrrd & ~inst_csrwr;
    assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0e) & (~|rj) & (~|rd);
    assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
    //exp13
    assign inst_rdcntid = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rd == 5'h00);
    assign inst_rdcntvl = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rj == 5'h00);
    assign inst_rdcntvh = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h19) & (rj == 5'h00);
    assign inst_break   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
    //load_op
    //assign load_op = inst_ld_w;
    //alu_op
    assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl | inst_pcaddu12i | inst_ld_b | inst_ld_bu
                    | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h;
    assign alu_op[ 1] = inst_sub_w;
    assign alu_op[ 2] = inst_slt | inst_slti | inst_blt | inst_bge;
    assign alu_op[ 3] = inst_sltu | inst_sltui | inst_bltu | inst_bgeu;
    assign alu_op[ 4] = inst_and | inst_andi;
    assign alu_op[ 5] = inst_nor;
    assign alu_op[ 6] = inst_or | inst_ori;
    assign alu_op[ 7] = inst_xor | inst_xori;
    assign alu_op[ 8] = inst_slli_w | inst_sll_w;
    assign alu_op[ 9] = inst_srli_w | inst_srl_w;
    assign alu_op[10] = inst_srai_w | inst_sra_w;
    assign alu_op[11] = inst_lu12i_w;
    assign alu_op[12] = inst_mul_w;
    assign alu_op[13] = inst_mulh_w;
    assign alu_op[14] = inst_mulh_wu;
    assign alu_op[15] = inst_div_w;
    assign alu_op[16] = inst_div_wu;
    assign alu_op[17] = inst_mod_w;
    assign alu_op[18] = inst_mod_wu;
    
    //
    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui
                         |inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne;
    assign need_ui12  =  inst_andi | inst_ori | inst_xori;
    assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
    assign need_si26  =  inst_b | inst_bl;
    assign src2_is_4  =  inst_jirl | inst_bl;
    
    assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;
    assign dst_is_r1     = inst_bl;
    assign dst_is_rj     = inst_rdcntid;
    assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b &
                            ~inst_st_b & ~inst_st_h & ~inst_bge & ~inst_bgeu & 
                            ~inst_blt & ~inst_bltu & ~inst_syscall;
    assign mem_we        = inst_st_w;
    assign dest          = dst_is_r1 ? 5'd1 :
                            dst_is_rj ? rj   : rd;
                            

    assign rf_raddr1 = rj;
    assign rf_raddr2 = src_reg_is_rd ? rd :rk;
    assign {rf_we,rf_waddr,rf_wdata} = write_back_bus;
    regfile u_regfile(
        .clk    (clk      ),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2),
        .we     (rf_we    ),
        .waddr  (rf_waddr ),
        .wdata  (rf_wdata )
    );
    assign rj_value  = rf_rdata1;
    assign rkd_value = rf_rdata2;

    
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0] rj_value_by;
    wire [31:0] rkd_value_by;
    assign rj_value_by = ((EXE_dest_bus == rj) && (|EXE_dest_bus)) ? EXE_value_bus :
                          ((MEM_dest_bus == rj) && (|MEM_dest_bus)) ? MEM_value_bus :
                          ((WB_dest_bus == rj) && (|WB_dest_bus)) ? WB_value_bus : rj_value;
                          
    /**assign rj_value_by = ((MEM_dest_bus == rj) && (|MEM_dest_bus)) ? MEM_value_bus :
                          ((WB_dest_bus == rj) && (|WB_dest_bus)) ? WB_value_bus : rj_value;**/
    assign rkd_value_by = ((EXE_dest_bus == rf_raddr2) && (|EXE_dest_bus)) ? EXE_value_bus :
                          ((MEM_dest_bus == rf_raddr2) && (|MEM_dest_bus)) ? MEM_value_bus :
                          ((WB_dest_bus == rf_raddr2) && (|WB_dest_bus)) ? WB_value_bus : rkd_value;
                          
    /**assign rkd_value_by = ((MEM_dest_bus == rf_raddr2) && (|MEM_dest_bus)) ? MEM_value_bus :
                          ((WB_dest_bus == rf_raddr2) && (|WB_dest_bus)) ? WB_value_bus : rkd_value;**/
    //assign alu_src1 = src1_is_pc  ? ID_pc[31:0] : rj_value;
    assign alu_src1 = src1_is_pc  ? ID_pc[31:0] : rj_value_by; 
    assign alu_src2 = src2_is_imm ? imm : rkd_value_by; 
    //BUS
    /**assign ID_to_EXE_bus = {alu_op, // 12
                            res_from_mem,//1
                            gr_we,  //1
                            mem_we, //1
                            dest,   //5
                            alu_src1,//32
                            alu_src2,//32
                            rkd_value,//32
                            ID_pc    //32
    };**/
    assign ID_to_EXE_bus = {alu_op, // 19
                            res_from_mem,//1
                            gr_we,  //1
                            mem_we, //1
                            dest,   //5
                            alu_src1,//32
                            alu_src2,//32
                            rkd_value_by,//32
                            ID_pc,    //32
                            inst_st_b,
                            inst_st_h,
                            inst_st_w,
                            inst_ld_b,
                            inst_ld_bu,
                            inst_ld_h,
                            inst_ld_hu,
                            inst_ld_w,
                            ID_csr_re,  //1
                            ID_csr_we,  //1
                            ID_csr_wmask,//32
                            ID_csr_wvalue,//32
                            ID_csr_num,//14
                            inst_syscall,//1
                            inst_ertn,//1
                            
                            inst_rdcntvh,//1
                            inst_rdcntvl,//1
                            inst_break,//1
                            ID_except_ine,//1
                            ID_except_int,//1
                            ID_pc_adef
    };
    //branch
    assign ID_br_stall = (inst_jirl   | inst_b      | inst_bl     | inst_blt   | inst_bge    | inst_bltu  |
                           inst_bgeu   | inst_beq    | inst_bne) & ~ID_go;
    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                 {{14{i16[15]}}, i16[15:0], 2'b0} ;

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
    wire rj_eq_rd;
    wire rj_ge_rd;
    wire rj_ge_rd_u;
    wire branch_valid;
    wire [31:0] branch_pc;
    //assign rj_eq_rd = (rj_value == rkd_value);
    assign rj_eq_rd = rj_value_by == rkd_value_by;
    assign rj_ge_rd = $signed(rj_value_by) >= $signed(rkd_value_by);
    assign rj_ge_rd_u = rj_value_by >= rkd_value_by;
    assign branch_valid = (inst_beq  &  rj_eq_rd
                    | inst_bne   & !rj_eq_rd
                    | inst_bge   &  rj_ge_rd
                    | inst_blt   & !rj_ge_rd
                    | inst_bgeu  &  rj_ge_rd_u
                    | inst_bltu  & !rj_ge_rd_u
                    | inst_jirl
                    | inst_bl
                    | inst_b
                    ) && ID_valid && ~ID_br_stall;
    /**assign branch_pc = (inst_beq || inst_bne || inst_bl || inst_b) ? (ID_pc + br_offs) :
                                                                     (rj_value + jirl_offs);**/
     assign branch_pc = (inst_beq || inst_bne || inst_bl || inst_b || inst_bge || inst_bgeu || inst_blt || inst_bltu) ? (ID_pc + br_offs) :
                                                                     (rj_value_by + jirl_offs);                                                                
     assign branch_bus = {branch_valid,branch_pc};
     

     assign ID_except_ine = ~(inst_add_w  | inst_sub_w  | inst_slti   | inst_slt   | inst_sltui  | inst_sltu  |
                               inst_nor    | inst_and    | inst_andi   | inst_or    | inst_ori    | inst_xor   |
                               inst_xori   | inst_sll_w  | inst_slli_w | inst_srl_w | inst_srli_w | inst_sra_w | inst_srai_w | inst_addi_w|
                               inst_mul_w  | inst_mulh_w | inst_mulh_wu| inst_div_w | inst_div_wu | inst_mod_w |
                               inst_mod_wu | inst_ld_b   | inst_ld_h   | inst_ld_w  | inst_ld_bu  | inst_ld_hu | inst_st_b   |
                               inst_st_h   | inst_st_w   | inst_jirl   | inst_b     | inst_bl     | inst_blt   | inst_bge    | inst_bltu  |
                               inst_bgeu   | inst_beq    | inst_bne    | inst_csrrd | inst_csrwr  | inst_csrxchg| inst_ertn  | inst_syscall| inst_break |
                               inst_rdcntid| inst_rdcntvh| inst_rdcntvl| inst_lu12i_w| inst_pcaddu12i);
     assign ID_except_int = has_int;
endmodule
