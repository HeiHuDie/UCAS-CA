module mycpu_top(
    input  wire        clk,
    input  wire        resetn,

    output wire [ 3:0]  arid   ,
    output wire [31:0]  araddr ,
    output wire [ 7:0]  arlen  ,
    output wire [ 2:0]  arsize ,
    output wire [ 1:0]  arburst,
    output wire [ 1:0]  arlock ,
    output wire [ 3:0]  arcache,
    output wire [ 2:0]  arprot ,
    output wire         arvalid,
    input  wire         arready,
                
    input  wire [ 3:0]  rid   ,
    input  wire [31:0]  rdata ,
    input  wire [ 1:0]  rresp ,
    input  wire         rlast ,
    input  wire         rvalid,
    output wire         rready,
               
    output wire [ 3:0]  awid   ,
    output wire [31:0]  awaddr ,
    output wire [ 7:0]  awlen  ,
    output wire [ 2:0]  awsize ,
    output wire [ 1:0]  awburst,
    output wire [ 1:0]  awlock ,
    output wire [ 3:0]  awcache,
    output wire [ 2:0]  awprot ,
    output wire         awvalid,
    input  wire         awready,
    
    output wire [ 3:0]  wid   ,
    output wire [31:0]  wdata ,
    output wire [ 3:0]  wstrb ,
    output wire         wlast ,
    output wire         wvalid,
    input  wire         wready,
    
    input  wire [ 3:0]   bid   ,
    input  wire [ 1:0]   bresp ,
    input  wire         bvalid,
    output wire         bready,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    reg reset;
    always @(posedge clk) reset <= ~resetn;
    wire ID_allow;
    wire EXE_allow;
    wire MEM_allow;
    wire WB_allow;
    wire IF_to_ID_valid;
    wire ID_to_EXE_valid;
    wire EXE_to_MEM_valid;
    wire MEM_to_WB_valid;
    wire [68:0] IF_to_ID_bus;
    wire [264:0] ID_to_EXE_bus;
    wire [185:0] EXE_to_MEM_bus;
    wire [210:0] MEM_to_WB_bus;
    wire [37:0] write_back_bus;
    wire [32:0] branch_bus;
    
    wire [4:0] EXE_dest_bus;
    wire [4:0] MEM_dest_bus;
    wire [4:0] WB_dest_bus;
    wire [31:0] EXE_value_bus;
    wire [31:0] MEM_value_bus;
    wire [31:0] WB_value_bus;
    wire EXE_load_bus;
    wire EXE_res_from_mul_bus;
    
    wire [31:0] WB_pc;
    wire        csr_re;
    wire [13:0] csr_num;
    wire [31:0] csr_rvalue;
    wire        csr_we;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    wire [31:0] ex_entry;
    wire [31:0] ertn_entry;
    wire [31:0] tlbr_entry;
    wire        has_int;
    wire        ertn_flush;
    wire        MEM_exception;
    wire        WB_exception;
    wire [ 5:0] wb_ecode;
    wire [ 8:0] wb_esubcode;
    wire EXE_csr_re_bus;
    wire MEM_csr_re_bus;
    wire [32:0] WB_vaddr;
    wire ID_br_stall;
    wire MEM_mem_req;
    wire wb_ex;
    wire wb_reinst;
    wire wb_tlbr;
    //IF

     //inst sram interface
    wire         inst_sram_req;
    wire         inst_sram_wr;
    wire [ 1:0]  inst_sram_size;
    wire [ 3:0]  inst_sram_wstrb;
    wire [31:0]  inst_sram_addr;
    wire [31:0]  inst_sram_wdata;
    wire         inst_sram_addr_ok;
    wire         inst_sram_data_ok;
    wire [31:0]  inst_sram_rdata;
    //data sram interface
    wire         data_sram_req;
    wire         data_sram_wr;
    wire [ 1:0]  data_sram_size;
    wire [ 3:0]  data_sram_wstrb;
    wire [31:0]  data_sram_addr;
    wire [31:0]  data_sram_wdata;
    wire         data_sram_addr_ok;
    wire         data_sram_data_ok;
    wire [31:0]  data_sram_rdata;
    //icache
    wire        icache_addr_ok;
    wire        icache_data_ok;
    wire [31:0] icache_rdata;
    wire         icache_rd_req;
    wire [  2:0] icache_rd_type;
    wire [ 31:0] icache_rd_addr;
    wire         icache_rd_rdy;
    wire         icache_ret_valid;
    wire         icache_ret_last;
    wire [ 31:0] icache_ret_data;
    wire         icache_wr_req;
    wire [  2:0] icache_wr_type;
    wire [ 31:0] icache_wr_addr;
    wire [  3:0] icache_wr_wstrb;
    wire [127:0] icache_wr_data;
    wire         icache_wr_rdy = 1'd1;
    wire [31:0] next_pc_r;
    IF_stage IF_stage(
        .clk (clk),
        .reset (reset),
        .ID_allow (ID_allow),
        .branch_bus (branch_bus),
        .IF_to_ID_valid (IF_to_ID_valid),
        .IF_to_ID_bus (IF_to_ID_bus),
        .inst_sram_req(inst_sram_req),
        .inst_sram_wr(inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_addr_ok(icache_addr_ok),
        .inst_sram_data_ok(icache_data_ok),
        .inst_sram_rdata(icache_rdata),
        
        .WB_exception (WB_exception),
        .ertn_flush (ertn_flush),
        .wb_reinst(wb_reinst),
        .wb_tlbr(wb_tlbr),
        .ex_entry (ex_entry),
        .ertn_entry (ertn_entry),
        .tlbr_entry(tlbr_entry),
        .WB_pc(WB_pc),
        
        .ID_br_stall(ID_br_stall),

        .next_pc(next_pc),
        
        .next_pc_true_addr(next_pc_true_addr),
        .to_PreIF_ex_ade(to_PreIF_ex_ade),
        .to_PreIF_ex_tlbr(to_PreIF_ex_tlbr),
        .to_PreIF_ex_pif(to_PreIF_ex_pif),
        .to_PreIF_ex_ppi(to_PreIF_ex_ppi),
        .next_pc_r(next_pc_r)
    );
    //ID
    ID_stage ID_stage(
        .clk (clk),
        .reset (reset),

        .EXE_allow (EXE_allow),
        .ID_allow (ID_allow),
        .IF_to_ID_valid (IF_to_ID_valid),
        .IF_to_ID_bus (IF_to_ID_bus),
        .ID_to_EXE_valid (ID_to_EXE_valid),
        .ID_to_EXE_bus (ID_to_EXE_bus),
        .branch_bus (branch_bus),
        .write_back_bus (write_back_bus),
        .ID_br_stall(ID_br_stall),

        .EXE_dest_bus (EXE_dest_bus),
        .MEM_dest_bus (MEM_dest_bus),
        .WB_dest_bus (WB_dest_bus),
        .EXE_value_bus (EXE_value_bus),
        .MEM_value_bus (MEM_value_bus),
        .WB_value_bus (WB_value_bus),

        .EXE_load_bus (EXE_load_bus),
        .EXE_res_from_mul_bus (EXE_res_from_mul_bus),
        .data_sram_data_ok(data_sram_data_ok),
        .MEM_mem_req(MEM_mem_req),
        
        .EXE_csr_re_bus (EXE_csr_re_bus),
        .MEM_csr_re_bus (MEM_csr_re_bus),
        .EXE_csr_num(EXE_csr_num),
        .EXE_csr_we(EXE_csr_we),
        .MEM_csr_num(MEM_csr_num),
        .MEM_csr_we(MEM_csr_we),
        .csr_num(csr_num),
        .csr_we(csr_we),

        .WB_exception (WB_exception | ertn_flush),
        .has_int (has_int)

    ); 
    //EXE
    wire [13:0] EXE_csr_num;//14
    wire EXE_csr_we;//1
    EXE_stage EXE_stage(
        .clk (clk),
        .reset (reset),

        .MEM_allow (MEM_allow),
        .EXE_allow (EXE_allow),
        .ID_to_EXE_valid (ID_to_EXE_valid),
        .ID_to_EXE_bus (ID_to_EXE_bus),
        .EXE_to_MEM_valid (EXE_to_MEM_valid),
        .EXE_to_MEM_bus (EXE_to_MEM_bus),
        
        .data_sram_req(data_sram_req),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr(data_sram_addr),
        .data_sram_addr_ok(data_sram_addr_ok),
        
        .EXE_dest_bus (EXE_dest_bus),
        .EXE_value_bus (EXE_value_bus),
        .EXE_load_bus (EXE_load_bus),
        .EXE_res_from_mul_bus (EXE_res_from_mul_bus),
        
        .EXE_csr_re_bus (EXE_csr_re_bus),
        .EXE_csr_num(EXE_csr_num),
        .EXE_csr_we(EXE_csr_we),

        .MEM_exception (MEM_exception),
        .WB_exception (WB_exception | ertn_flush),

        .EXE_inst_tlbsrch(EXE_tlbsrch),
        .EXE_inst_invtlb(EXE_tlbinvtlb),
        .EXE_invtlb_op(invtlb_s_op),
        .rj_asid(invtlb_s_rj_asid),
        .rk_vppn(invtlb_s_rk_vppn),
        .mem_vaddr(mem_vaddr),

        .s1_index(s1_index),
        .s1_found(s1_found),//??????????tlb???????
        .mem_paddr(mem_paddr),
        // .inst_vppn()

        .to_EXE_ex_ade(to_EXE_ex_ade),
        .to_EXE_ex_tlbr(to_EXE_ex_tlbr),
        .to_EXE_ex_pil(to_EXE_ex_pil),
        .to_EXE_ex_pis(to_EXE_ex_pis),
        .to_EXE_ex_ppi(to_EXE_ex_ppi),
        .to_EXE_ex_pme(to_EXE_ex_pme)
    );

    //mmu?????????tlb??????????????mmu??????????mmu???????mmu??÷?????
    //????srch????index??found???????????????????

    wire [31:0] next_pc;//mmu s0??????

    wire [31:0] next_pc_true_addr;
    wire        to_PreIF_ex_ade;
    wire        to_PreIF_ex_tlbr;
    wire        to_PreIF_ex_pif;
    wire        to_PreIF_ex_ppi;//mmu s0??????


    wire        EXE_tlbsrch;//mmu s1??????
    wire        EXE_tlbinvtlb;
    //EXE???????tlb???index??NE????????????,????????csr?????κ????
    //?????search??????????????????????????vppn??asid???в???
    wire [4:0]  invtlb_s_op;
    wire [18:0] TLB_s_vppn;
    wire [9:0]  TLB_s_asid;
    wire [31:0] invtlb_s_rj_asid;
    wire [31:0] invtlb_s_rk_vppn;
    wire [31:0] mem_vaddr;

    wire [31:0] mem_paddr;
    wire        to_EXE_ex_ade;
    wire        to_EXE_ex_tlbr;
    wire        to_EXE_ex_pil;
    wire        to_EXE_ex_pis;
    wire        to_EXE_ex_ppi;
    wire        to_EXE_ex_pme;//mmu s1??????

    mmu u_mmu(
        .clk(clk),

        .csr_dmw0_data(csr_dmw0_data),
        .csr_dmw1_data(csr_dmw1_data), 
        .csr_crmd_da(csr_crmd_da), 
        .csr_crmd_pg(csr_crmd_pg),
        .csr_crmd_plv(csr_crmd_plv),
        .mem_wr(|data_sram_wstrb),   


        .next_pc_vaddr(next_pc),//?????????s0?????в????????????????vppn??mmu???з??????mmu????tlb

        .s0_vppn(s0_vppn),
        .s0_va_bit12(s0_va_bit12),
        .s0_asid(s0_asid),//mmu????tlb

        .s0_found(s0_found),
        .s0_index(s0_index),
        .s0_ppn(s0_ppn),
        .s0_ps(s0_ps),
        .s0_plv(s0_plv),
        .s0_mat(s0_mat),
        .s0_d(s0_d),
        .s0_v(s0_v),//tlb????????????????mmu

        .next_pc_true_addr(next_pc_true_addr),
        .to_PreIF_ex_ade(to_PreIF_ex_ade),
        .to_PreIF_ex_tlbr(to_PreIF_ex_tlbr),
        .to_PreIF_ex_pif(to_PreIF_ex_pif),
        .to_PreIF_ex_ppi(to_PreIF_ex_ppi),//mmu????tlb?????????????????????

        //EXE?????????
        .EXE_tlbsrch(EXE_tlbsrch),
        .EXE_tlbinvtlb(EXE_tlbinvtlb),

        .invtlb_s_op(invtlb_s_op),
        .TLB_s_vppn(TLB_s_vppn),
        .invtlb_s_rk_vppn(invtlb_s_rk_vppn),
        .TLB_s_asid(TLB_s_asid),
        .invtlb_s_rj_asid(invtlb_s_rj_asid),
        .mem_vaddr(mem_vaddr),//?????????s1?????в????????????????vppn??mmu???з??????mmu????tlb
        
        .s1_vppn(s1_vppn),
        .s1_va_bit12(s1_va_bit12),
        .s1_asid(s1_asid),
        .invtlb_valid(invtlb_valid),
        .invtlb_op(invtlb_op),//mmu?????tlb

        .s1_ppn(s1_ppn),
        .s1_ps(s1_ps),
        .s1_plv(s1_plv),
        .s1_mat(s1_mat),
        .s1_d(s1_d),
        .s1_v(s1_v),
        .s1_found(s1_found),//
        .s1_index(s1_index),////tlb????????????????mmu

        .mem_paddr(mem_paddr),
        .to_EXE_ex_ade(to_EXE_ex_ade),
        .to_EXE_ex_tlbr(to_EXE_ex_tlbr),
        .to_EXE_ex_pil(to_EXE_ex_pil),
        .to_EXE_ex_pis(to_EXE_ex_pis),
        .to_EXE_ex_ppi(to_EXE_ex_ppi),
        .to_EXE_ex_pme(to_EXE_ex_pme)//mmu????tlb?????????????????????
    );


    //??????tlb????
    wire [18:0] s0_vppn;
    wire        s0_va_bit12;
    wire [9:0]  s0_asid;

    wire        s0_found;
    wire [ 3:0] s0_index;
    wire [19:0] s0_ppn;
    wire [5:0]  s0_ps;
    wire [1:0]  s0_plv;
    wire [1:0]  s0_mat;
    wire        s0_d;
    wire        s0_v;

    wire [18:0] s1_vppn;
    wire        s1_va_bit12;
    wire [9:0]  s1_asid;

    wire        s1_found;
    wire [3:0]  s1_index;
    wire [19:0] s1_ppn;
    wire [5:0]  s1_ps;
    wire [1:0]  s1_plv;
    wire [1:0]  s1_mat;
    wire        s1_d;
    wire        s1_v;

    wire        invtlb_valid;
    wire [ 4:0] invtlb_op;


    //??????????д??????

    wire [3:0]  TLB_r_index;
    //??????Щ??????????????????????????
    wire [18:0] TLB_r_vppn;
    wire [9:0]  TLB_r_asid;
    wire        TLB_r_E;//rd?д?????
    wire [5:0]  TLB_r_ps;//TLB?????psλ??????????//rd?д?????
    //д??ehi??asid????????

    wire        TLB_r_g;
    wire        TLB_r_valid0;
    wire        TLB_r_dirty0;
    wire [1:0]  TLB_r_plv0;
    wire [1:0]  TLB_r_mat0;
    wire [19:0] TLB_r_ppn0;
    //???д??TLBELO0
    wire        TLB_r_valid1;
    wire        TLB_r_dirty1;
    wire [1:0]  TLB_r_plv1;
    wire [1:0]  TLB_r_mat1;
    wire [19:0] TLB_r_ppn1;
    //???д??TLBELO1


    wire [3:0]  TLB_w_index;
    wire        TLB_w_e;
    wire [5:0]  TLB_w_ps;
    //????ehi??????????
    wire [18:0] TLB_w_vppn;
    //????asid??????????
    wire [9:0]  TLB_w_asid;

    //????tlbλ?????ELO??????????
    wire        TLB_w_g;
    wire [19:0] TLB_w_ppn0;
    wire [ 1:0] TLB_w_plv0;
    wire [ 1:0] TLB_w_mat0;
    wire        TLB_w_d0;
    wire        TLB_w_v0;
    wire [19:0] TLB_w_ppn1;
    wire [ 1:0] TLB_w_plv1;
    wire [ 1:0] TLB_w_mat1;
    wire        TLB_w_d1;
    wire        TLB_w_v1;

    tlb u_tlb(
        .clk(clk),
    
        .s0_vppn(s0_vppn),
        .s0_va_bit12(s0_va_bit12),
        .s0_asid(s0_asid),
        .s0_found(s0_found),
        .s0_index(s0_index),
        .s0_ppn(s0_ppn),
        .s0_ps(s0_ps),
        .s0_plv(s0_plv),
        .s0_mat(s0_mat),
        .s0_d(s0_d),
        .s0_v(s0_v),

        .s1_vppn(s1_vppn),//
        .s1_va_bit12(s1_va_bit12),
        .s1_asid(s1_asid),//
        .s1_found(s1_found),//
        .s1_index(s1_index),//
        .s1_ppn(s1_ppn),
        .s1_ps(s1_ps),
        .s1_plv(s1_plv),
        .s1_mat(s1_mat),
        .s1_d(s1_d),
        .s1_v(s1_v),

        .invtlb_valid(invtlb_valid),
        .invtlb_op(invtlb_op),//?????????mmu?????tlb??

        //?????????д????????WB?????е????????????????mmu????????????tlb???????
        .we(tlbwr || tlbfill), //w(rite) e(nable)
        .w_index(TLB_w_index),
        .w_e(TLB_w_e),
        .w_vppn(TLB_w_vppn),
        .w_ps(TLB_w_ps),
        .w_asid(TLB_w_asid),
        .w_g(TLB_w_g),
        .w_ppn0(TLB_w_ppn0),
        .w_plv0(TLB_w_plv0),
        .w_mat0(TLB_w_mat0),
        .w_d0(TLB_w_d0),
        .w_v0(TLB_w_v0),
        .w_ppn1(TLB_w_ppn1),
        .w_plv1(TLB_w_plv1),
        .w_mat1(TLB_w_mat1),
        .w_d1(TLB_w_d1),
        .w_v1(TLB_w_v1),
        
        .r_index(TLB_r_index),
        .r_e(TLB_r_E),
        .r_vppn(TLB_r_vppn),
        .r_ps(TLB_r_ps),
        .r_asid(TLB_r_asid),
        .r_g(TLB_r_g),
        .r_ppn0(TLB_r_ppn0),
        .r_plv0(TLB_r_plv0),
        .r_mat0(TLB_r_mat0),
        .r_d0(TLB_r_dirty0),
        .r_v0(TLB_r_valid0),
        .r_ppn1(TLB_r_ppn1),
        .r_plv1(TLB_r_plv1),
        .r_mat1(TLB_r_mat1),
        .r_d1(TLB_r_dirty1),
        .r_v1(TLB_r_valid1)
    );

    wire [13:0] MEM_csr_num;//14
    wire MEM_csr_we;  //1
    //MEM
    MEM_stage MEM_stage(
        .clk (clk),
        .reset (reset),

        .WB_allow (WB_allow),
        .MEM_allow (MEM_allow),
        .EXE_to_MEM_valid (EXE_to_MEM_valid),
        .EXE_to_MEM_bus (EXE_to_MEM_bus),
        .MEM_to_WB_valid (MEM_to_WB_valid),
        .MEM_to_WB_bus (MEM_to_WB_bus),

        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata (data_sram_rdata),
        
        .MEM_dest_bus (MEM_dest_bus),
        .MEM_value_bus (MEM_value_bus),
        .MEM_mem_req(MEM_mem_req),
        
        .MEM_csr_re_bus (MEM_csr_re_bus),
        .MEM_csr_num(MEM_csr_num),
        .MEM_csr_we(MEM_csr_we),

        .MEM_exception (MEM_exception),
        .WB_exception (WB_exception | ertn_flush)
    );
    //WB
    WB_stage WB_stage(
        .clk (clk),
        .reset (reset),

        .WB_allow (WB_allow),
        .MEM_to_WB_valid (MEM_to_WB_valid),
        .MEM_to_WB_bus (MEM_to_WB_bus),

        .csr_re (csr_re),
        .csr_num (csr_num),
        .csr_rvalue (csr_rvalue),
        .csr_we (csr_we),
        .csr_wmask (csr_wmask ),
        .csr_wvalue (csr_wvalue),

        .WB_inst_tlbsrch(tlbsrch),
        .WB_inst_tlbrd(tlbrd),
        .WB_inst_tlbwr(tlbwr),   
        .WB_inst_tlbfill(tlbfill), 
        .WB_inst_invtlb(tlbinvtlb),
        .WB_s1_index(TLB_s_index),
        .WB_s1_found(TLB_s_NE),

        .debug_wb_pc (debug_wb_pc),
        .debug_wb_rf_we (debug_wb_rf_we),
        .debug_wb_rf_wnum (debug_wb_rf_wnum),
        .debug_wb_rf_wdata (debug_wb_rf_wdata),

        .write_back_bus (write_back_bus),
        .WB_dest_bus (WB_dest_bus),
        .WB_value_bus (WB_value_bus),
        
        .ertn_flush (ertn_flush),
        .WB_exception (WB_exception),
        .wb_ex(wb_ex),
        .wb_reinst(wb_reinst),
        .wb_tlbr(wb_tlbr),
        .wb_ecode (wb_ecode),
        .wb_esubcode(wb_esubcode),
        .WB_pc (WB_pc),
        .WB_vaddr (WB_vaddr)
    );

    //????????????csr??mmu_tlb???????????index??NE?srch??WB???д??csr????
    wire        tlbrd;
    wire        tlbwr;
    wire        tlbfill;
    wire        tlbsrch;
    wire        tlbinvtlb;
    //WB??????csr?????????????csr???????????????????????????

    wire [3:0]  TLB_s_index;//TLB??????????//srch?д?????
    wire        TLB_s_NE;//TLB?????NEλ?????????//s0_found||s1_found??????????????????????????//srch?д?????

    wire [31: 0] csr_dmw0_data;
    wire [31: 0] csr_dmw1_data;
    wire         csr_crmd_da;
    wire         csr_crmd_pg;
    wire [1:0]   csr_crmd_plv;
    csr_regfile u_csr(
        .clk (clk),
        .reset (reset),
        .csr_re (csr_re),
        .csr_num (csr_num),
        .csr_rvalue (csr_rvalue),
        .csr_we (csr_we),
        .csr_wmask (csr_wmask),
        .csr_wvalue (csr_wvalue),
        .has_int (has_int),
        .ex_entry (ex_entry),
        .ertn_entry (ertn_entry),
        .tlbr_entry(tlbr_entry),
        .ertn_flush (ertn_flush),
        .wb_ex (wb_ex),
        .wb_pc (WB_pc),
        .wb_ecode (wb_ecode),
        .wb_esubcode (wb_esubcode),
        .wb_vaddr (WB_vaddr),

        .tlbrd(tlbrd),
        .tlbwr(tlbwr),
        .tlbfill(tlbfill),
        .tlbsrch(tlbsrch),

        .TLB_s_index(TLB_s_index),//TLB??????????//srch?д?????
        .TLB_s_NE(TLB_s_NE),//TLB?????NEλ?????????//s0_found||s1_found??????????????????????????//srch?д?????
        //????????????WB??д????????????EXE????????????????
        .TLB_s_vppn(TLB_s_vppn),
        .TLB_s_asid(TLB_s_asid),
        //д??index????????
        //???????????????s_index??r_index?????????
        //s_index??д??csr??r_index???WB??????tlb_rd??????????r_index
        //?????????r_index????tlb?????????????WB??д????

        .TLB_r_index(TLB_r_index),
        //??????Щ??????????????????????????
        .TLB_r_vppn(TLB_r_vppn),
        .TLB_r_asid(TLB_r_asid),
        .TLB_r_E(TLB_r_E),//rd?д?????
        .TLB_r_ps(TLB_r_ps),//TLB?????psλ??????????//rd?д?????
        //д??ehi??asid????????

        .TLB_r_g(TLB_r_g),
        .TLB_r_valid0(TLB_r_valid0),
        .TLB_r_dirty0(TLB_r_dirty0),
        .TLB_r_plv0(TLB_r_plv0),
        .TLB_r_mat0(TLB_r_mat0),
        .TLB_r_ppn0(TLB_r_ppn0),
        //???д??TLBELO0
        .TLB_r_valid1(TLB_r_valid1),
        .TLB_r_dirty1(TLB_r_dirty1),
        .TLB_r_plv1(TLB_r_plv1),
        .TLB_r_mat1(TLB_r_mat1),
        .TLB_r_ppn1(TLB_r_ppn1),
        //???д??TLBELO1

        .TLB_w_index(TLB_w_index),
        .TLB_w_e(TLB_w_e),
        .TLB_w_ps(TLB_w_ps),

        //????ehi??????????
        .TLB_w_vppn(TLB_w_vppn),

        //????asid??????????
        .TLB_w_asid(TLB_w_asid),

        //????tlbλ?????ELO??????????
        .TLB_w_g(TLB_w_g),
        .TLB_w_ppn0(TLB_w_ppn0),
        .TLB_w_plv0(TLB_w_plv0),
        .TLB_w_mat0(TLB_w_mat0),
        .TLB_w_d0(TLB_w_d0),
        .TLB_w_v0(TLB_w_v0),
        .TLB_w_ppn1(TLB_w_ppn1),
        .TLB_w_plv1(TLB_w_plv1),
        .TLB_w_mat1(TLB_w_mat1),
        .TLB_w_d1(TLB_w_d1),
        .TLB_w_v1(TLB_w_v1),

        .csr_dmw0_data(csr_dmw0_data),
        .csr_dmw1_data(csr_dmw1_data),
        .csr_crmd_da(csr_crmd_da), 
        .csr_crmd_pg(csr_crmd_pg),
        .csr_crmd_plv(csr_crmd_plv)
    );

    axi_sram_bridge u_bridge(
        .clk(clk),
        .reset(reset),

        .arid(arid)   ,//
        .araddr(araddr) ,//
        .arlen(arlen)  ,//
        .arsize(arsize) ,//
        .arburst(arburst),//
        .arlock(arlock) ,//
        .arcache(arcache),//
        .arprot(arprot) ,//
        .arvalid(arvalid),//
        .arready(arready),
                
        .rid(rid)   ,
        .rdata(rdata) ,
        .rresp(rresp) ,
        .rlast(rlast) ,
        .rvalid(rvalid),
        .rready(rready),//
               
        .awid(awid)   ,//
        .awaddr(awaddr) ,//
        .awlen(awlen)  ,//
        .awsize(awsize),//
        .awburst(awburst),//
        .awlock(awlock) ,//
        .awcache(awcache),//
        .awprot(awprot) ,//
        .awvalid(awvalid),//
        .awready(awready),
    
        .wid(wid)   ,//
        .wdata(wdata) ,//
        .wstrb(wstrb) ,//
        .wlast(wlast) ,//
        .wvalid(wvalid),//
        .wready(wready),
    
        .bid(bid)   ,
        .bresp(bresp) ,
        .bvalid(bvalid),
        .bready(bready),//
        //axi_master

        //inst sram interface(??sram_slave)
        .icache_rd_req(icache_rd_req),
        .icache_rd_type(icache_rd_type),
        .icache_rd_addr(icache_rd_addr),
        .icache_rd_rdy(icache_rd_rdy),
        .icache_ret_valid(icache_ret_valid),//
        .icache_ret_last(icache_ret_last),//
        .icache_ret_data(icache_ret_data),//
        // data sram interface(??sram_slave)
        .data_sram_req(data_sram_req),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr_ok(data_sram_addr_ok),//
        .data_sram_data_ok(data_sram_data_ok),//
        .data_sram_rdata(data_sram_rdata)//
    );
    cache u_cache(
        .clk(clk),
        .resetn(resetn),
        .valid(inst_sram_req),
        .op(inst_sram_wr),
        .index(next_pc_r[11:4]),
        .tag(inst_sram_addr[31:12]),
        .offset(next_pc_r[3:0]),
        .wstrb(inst_sram_wstrb),
        .wdata(inst_sram_wdata),
        .addr_ok(icache_addr_ok),
        .data_ok(icache_data_ok),
        .rdata(icache_rdata),
        .rd_req(icache_rd_req),
        .rd_type(icache_rd_type),
        .rd_rdy(icache_rd_rdy),
        .rd_addr(icache_rd_addr),
        .ret_valid(icache_ret_valid),
        .ret_last(icache_ret_last),
        .ret_data (icache_ret_data),
        .wr_req (icache_wr_req),//output,对于icache永远是0
        .wr_type(icache_wr_type),
        .wr_addr(icache_wr_addr),
        .wr_wstrb(icache_wr_strb),
        .wr_data(icache_wr_data),
        .wr_rdy (icache_wr_rdy)//icache不会真正要写sram，置1没有关系
    );
endmodule
