`timescale 1ns / 1ps
`define CSR_CRMD    14'h0000
`define CSR_PRMD    14'h0001
`define CSR_ECFG    14'h0004
`define CSR_ESTAT   14'h0005
`define CSR_ERA     14'h0006
`define CSR_BADV    14'h0007
`define CSR_EENTRY  14'h000c
`define CSR_SAVE0   14'h0030
`define CSR_SAVE1   14'h0031
`define CSR_SAVE2   14'h0032
`define CSR_SAVE3   14'h0033
`define CSR_TID     14'h0040
`define CSR_TCFG    14'h0041
`define CSR_TVAL    14'h0042
`define CSR_TICLR   14'h0044

`define CSR_TLBIDX      14'h0010
`define CSR_TLBEHI      14'h0011
`define CSR_TLBELO0     14'h0012
`define CSR_TLBELO1     14'h0013
`define CSR_ASID        14'h0018
`define CSR_TLBRENTRY   14'h0088
`define CSR_DMW0        14'h0180
`define CSR_DMW1        14'h0181

`define ECODE_ADE    6'h08
`define ECODE_ALE    6'h09
`define ESUBCODE_ADEF   9'h000
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/09 21:50:37
// Design Name: 
// Module Name: csr_regfile
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module csr_regfile#(
    parameter TLBNUM = 16
)
(
    input  wire          clk       ,
    input  wire          reset     ,
    // 读端口
    input  wire          csr_re    ,
    input  wire [13:0]   csr_num   ,
    output wire [31:0]   csr_rvalue,
    // 写端口
    input  wire          csr_we    ,
    input  wire [31:0]   csr_wmask ,
    input  wire [31:0]   csr_wvalue,
    // 与硬件电路交互的接口信号
    output wire [31:0]   ex_entry  , //异常入口地址
    output wire [31:0]   ertn_entry, //返回入口地址
    output wire [31:0]   tlbr_entry, //tlb重填例外入口地址
    output wire          has_int   , //中断有效信号
    input  wire          ertn_flush, //ertn指令执行有效信号
    input  wire          wb_ex     , //异常处理触发信号
    input  wire [ 5:0]   wb_ecode  , //异常类型
    input  wire [ 8:0]   wb_esubcode,//异常类型辅助码
    input  wire [31:0]   wb_vaddr   ,//访存地址
    input  wire [31:0]   wb_pc  ,     //写回的返回地址

    input  wire          tlbrd,
    input  wire          tlbwr,
    input  wire          tlbfill,
    input  wire          tlbsrch,

    input  wire [3:0]    TLB_s_index,//TLB表项的偏移量//srch时写入
    input  wire          TLB_s_NE,//TLB表项的NE位，是否命中//s0_found||s1_found，有软件保证只会有一个命中//srch时写入
    output wire [18:0]   TLB_s_vppn,
    output wire [9:0]    TLB_s_asid,
    //写入index寄存器

    output wire [$clog2(TLBNUM)-1:0] TLB_r_index,
    //以下这些都是在读的时候才会把他们给读出来
    input  wire [18:0]   TLB_r_vppn,
    input  wire [9:0]    TLB_r_asid,
    input  wire          TLB_r_E,//rd时写入
    input  wire [5:0]    TLB_r_ps,//TLB表项的ps位，奇偶页//rd时写入
    //写入ehi与asid寄存器

    input  wire          TLB_r_g,
    input  wire          TLB_r_valid0,
    input  wire          TLB_r_dirty0,
    input  wire [1:0]    TLB_r_plv0,
    input  wire [1:0]    TLB_r_mat0,
    input  wire [19:0]   TLB_r_ppn0,
    //准备写入TLBELO0
    input  wire          TLB_r_valid1,
    input  wire          TLB_r_dirty1,
    input  wire [1:0]    TLB_r_plv1,
    input  wire [1:0]    TLB_r_mat1,
    input  wire [19:0]   TLB_r_ppn1,
    //准备写入TLBELO1

    // input  wire [31:0]   TLB_eentry,

    //关于idx寄存器的输出
    output  wire [$clog2(TLBNUM)-1:0] TLB_w_index,
    output  wire                      TLB_w_e,
    output  wire [               5:0] TLB_w_ps,

    //关于ehi寄存器的输出
    output  wire [              18:0] TLB_w_vppn,

    //关于asid寄存器的输出
    output  wire [               9:0] TLB_w_asid,

    //以下tlb位为关于ELO寄存器的输出
    output  wire                      TLB_w_g,
    output  wire [              19:0] TLB_w_ppn0,
    output  wire [               1:0] TLB_w_plv0,
    output  wire [               1:0] TLB_w_mat0,
    output  wire                      TLB_w_d0,
    output  wire                      TLB_w_v0,
    output  wire [              19:0] TLB_w_ppn1,
    output  wire [               1:0] TLB_w_plv1,
    output  wire [               1:0] TLB_w_mat1,
    output  wire                      TLB_w_d1,
    output  wire                      TLB_w_v1,
    //输出的将要写入tlb模块的数据

    output  wire [31: 0]              csr_dmw0_data,
    output  wire [31: 0]              csr_dmw1_data,
    output  reg                       csr_crmd_da, 
    output  reg                       csr_crmd_pg,
    output  reg  [ 1: 0]              csr_crmd_plv
    
    //输出给mmu模块用来判断虚实地址转换模式

);
    wire [ 7: 0] hw_int_in;
    wire         ipi_int_in;
    //当前模式信息
    wire [31: 0] csr_crmd_data;      
    reg          csr_crmd_ie;
    reg  [ 6: 5] csr_crmd_datf;
    reg  [ 8: 7] csr_crmd_datm;
    //例外前模式信息
    wire [31: 0] csr_prmd_data;
    reg  [ 1: 0] csr_prmd_pplv;     //CRMD的PLV域旧值
    reg          csr_prmd_pie;      //CRMD的IE域旧值
    // 例外控制
    wire [31: 0] csr_ecfg_data;     
    reg  [12: 0] csr_ecfg_lie;      
    // 例外状态
    wire [31: 0] csr_estat_data;    
    reg  [12: 0] csr_estat_is;      //例外中断的状态位
    reg  [ 5: 0] csr_estat_ecode;   
    reg  [ 8: 0] csr_estat_esubcode;
    // 例外返回地址ERA
    reg  [31: 0] csr_era_data;  
    // 例外入口地址eentry
    wire [31: 0] csr_eentry_data;
    reg  [25: 0] csr_eentry_va;     //例外中断入口高位地址
    //保存的数据
    reg  [31: 0] csr_save0_data;
    reg  [31: 0] csr_save1_data;
    reg  [31: 0] csr_save2_data;
    reg  [31: 0] csr_save3_data;
    //出错虚地址
    wire         wb_ex_addr_err;
    reg  [31: 0] csr_badv_vaddr;
    wire [31: 0] csr_badv_data;
    //计时器编号 
    wire [31: 0] csr_tid_data;
    reg  [31: 0] csr_tid_tid;
    //计时器配置
    wire [31: 0] csr_tcfg_data;
    reg          csr_tcfg_en;
    reg          csr_tcfg_periodic;
    reg  [29: 0] csr_tcfg_initval;
    wire [31: 0] tcfg_next_value;
    //计时器数值
    wire [31: 0] csr_tval_data;
    reg  [31: 0] timer_cnt;
    //tlb寄存器数值
    wire [31: 0] csr_tlbidx_data;
    wire [31: 0] csr_tlbehi_data;
    wire [31: 0] csr_tlbelo0_data;
    wire [31: 0] csr_tlbelo1_data;
    wire [31: 0] csr_tlbasid_data;
    wire [31: 0] csr_tlbrentry_data;
    //计时器中断清除
    wire [31: 0] csr_ticlr_data;
    assign has_int = (|(csr_estat_is[11:0] & csr_ecfg_lie[11:0])) & csr_crmd_ie;
    assign ex_entry = csr_eentry_data;
    assign ertn_entry = csr_era_data;
    assign tlbr_entry = csr_tlbrentry_data;

    //CRMD  PLV,IE
    always @(posedge clk) begin
        if (reset) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if (wb_ex) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie  <= csr_prmd_pie;
        end
        else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[1:0] & csr_wvalue[1:0]
                          | ~csr_wmask[1:0] & csr_crmd_plv;
            csr_crmd_ie  <= csr_wmask[2] & csr_wvalue[2]
                          | ~csr_wmask[2] & csr_crmd_ie;
        end
    end

    //CRMD  DA,PG,DATF,DATM
    always @(posedge clk) begin
        if(reset) begin
            csr_crmd_da   <= 1'b1;
            csr_crmd_pg   <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end
        else if(csr_we && csr_num == `CSR_CRMD)begin
            csr_crmd_da   <= csr_wmask[3]   & csr_wvalue[3]
                          | ~csr_wmask[3]   & csr_crmd_da;
            csr_crmd_pg   <= csr_wmask[4]   & csr_wvalue[4]
                          | ~csr_wmask[4]   & csr_crmd_pg;
            csr_crmd_datf <= csr_wmask[6:5] & csr_wvalue[6:5]
                          | ~csr_wmask[6:5] & csr_crmd_datf;
            csr_crmd_datm <= csr_wmask[8:7] & csr_wvalue[8:7]
                          | ~csr_wmask[8:7] & csr_crmd_datm;
        end
        else if(wb_ex &&  wb_ecode == 6'h3f) begin//tlb重填异常
            csr_crmd_da   <= 1'b1;
            csr_crmd_pg   <= 1'b0;
        end
        else if(ertn_flush && csr_estat_ecode == 6'h3f) begin//tlb重填异常返回时重置
            csr_crmd_da   <= 1'b0;
            csr_crmd_pg   <= 1'b1;
            // csr_crmd_datf <= 2'b01;
            // csr_crmd_datm <= 2'b01;//软件置采用管，硬件自动置则不用管            
        end
    end

    //PRMD  PPLV,PIE
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end
        else if (csr_we && csr_num == `CSR_PRMD) begin
            csr_prmd_pplv <=  csr_wmask[1:0] & csr_wvalue[1:0]
                           | ~csr_wmask[1:0] & csr_prmd_pplv;
            csr_prmd_pie  <=  csr_wmask[2] & csr_wvalue[2]
                           | ~csr_wmask[2] & csr_prmd_pie;
        end
    end

    //ECFG LIE
    always @(posedge clk) begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we && csr_num == `CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[12:0] & csr_wvalue[12:0]
                        |  ~csr_wmask[12:0] & csr_ecfg_lie;
    end

    //ESTAT IS
    assign hw_int_in = 8'b0;
    assign ipi_int_in= 1'b0;
    always @(posedge clk) begin
        if (reset) begin
            csr_estat_is[1:0] <= 2'b0;
        end
        else if (csr_we && (csr_num == `CSR_ESTAT)) begin
            csr_estat_is[1:0] <= ( csr_wmask[1:0] & csr_wvalue[1:0])
                               | (~csr_wmask[1:0] & csr_estat_is[1:0]          );
        end

        csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[10] <= 1'b0;

        if (timer_cnt[31:0] == 32'b0) begin
            csr_estat_is[11] <= 1'b1;
        end
        else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[0]&& csr_wvalue[0])begin 
            csr_estat_is[11] <= 1'b0;
        end

        csr_estat_is[12] <= ipi_int_in;
    end    

    //ESTAT    Ecode、EsubCode。触发异常时填写异常的类型代号，精确异常是在写回级进行触发
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode    <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end

    //ERA  PC。当位于写回级指令触发异常时，需要记录到 ERA 寄存器的 PC 就是当前写回级的 PC
    always @(posedge clk) begin
        if(wb_ex)
            csr_era_data <= wb_pc;
        else if (csr_we && csr_num == `CSR_ERA) 
            csr_era_data <= csr_wmask[31:0] & csr_wvalue[31:0]
                         | ~csr_wmask[31:0] & csr_era_data;
    end

    //EENTRY 设置中断入口地址
    always @(posedge clk) begin
        if (csr_we && (csr_num == `CSR_EENTRY))
            csr_eentry_va <=   csr_wmask[31:6] & csr_wvalue[31:6]
                            | ~csr_wmask[31:6] & csr_eentry_va ;
    end

    //SAVE
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_SAVE0) 
            csr_save0_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save0_data;
        if (csr_we && (csr_num == `CSR_SAVE1)) 
            csr_save1_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save1_data;
        if (csr_we && (csr_num == `CSR_SAVE2)) 
            csr_save2_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save2_data;
        if (csr_we && (csr_num == `CSR_SAVE3)) 
            csr_save3_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save3_data;
    end

    //BADV 取指或访存地址异常时将异常地址写入(tlb异常时也要全部写入)
    assign wb_ex_addr_err = wb_ecode == 6'h08 || wb_ecode == 6'h09 ||
                            wb_ecode == 6'h3f || wb_ecode == 6'h03 || 
                            wb_ecode == 6'h01 || wb_ecode == 6'h02 || 
                            wb_ecode == 6'h07 || wb_ecode == 6'h04;
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err) begin
            csr_badv_vaddr <= (wb_ecode == 6'h08 && wb_esubcode == 9'd0) ? wb_pc:wb_vaddr;
        end else if (csr_we && csr_num==`CSR_BADV) begin
            csr_badv_vaddr <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_badv_vaddr;
        end
    end

    //TID
    always @(posedge clk) begin
        if (reset) begin
            csr_tid_tid <= 32'b0;
        end
        else if (csr_we && csr_num == `CSR_TID) begin
            csr_tid_tid <= csr_wmask[31:0] & csr_wvalue[31:0]
                        | ~csr_wmask[31:0] & csr_tid_tid;
        end
    end

    //TCFG  EN、Periodic、InitVal
    always @(posedge clk) begin
        if (reset) 
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num == `CSR_TCFG) begin
            csr_tcfg_en <= csr_wmask[0] & csr_wvalue[0]
                        | ~csr_wmask[0] & csr_tcfg_en;
        end
        if (csr_we && csr_num == `CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[1] & csr_wvalue[1]
                              | ~csr_wmask[1] & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[31:2] & csr_wvalue[31:2]
                              | ~csr_wmask[31:2] & csr_tcfg_initval;
        end
    end

    //  TVAL TimeVal。返回计时器的值
    assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                           |~csr_wmask[31:0] & csr_tcfg_data;
    always @(posedge clk) begin
        if (reset) begin
            timer_cnt <= 32'hffffffff;
        end
        else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[0]) begin
            timer_cnt <= {tcfg_next_value[31:2], 2'b0};
        end
        else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin //锟斤拷时锟斤拷锟角凤拷锟斤拷锟斤拷锟皆碉拷锟斤拷锟斤拷锟斤拷锟? 0-1=ff..ff,锟斤拷么停止锟斤拷锟斤拷
            if (timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic) begin
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            end
            else begin
                timer_cnt <= timer_cnt - 1'b1;
            end
        end
    end

    //TICLRCLR

    ////////////////////////////////TLB相关csr寄存器

    /////IDX寄存器
    reg [3:0]   csr_tlbidx_idx;
    reg [5:0]   csr_tlbidx_ps;
    reg         csr_tlbidx_ne;

    always @(posedge clk) begin
        if (reset) begin
            csr_tlbidx_idx <= 4'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBIDX)begin
            csr_tlbidx_idx <=  csr_wmask[3:0] & csr_wvalue[3:0]
                            | ~csr_wmask[3:0] & csr_tlbidx_idx;
        end
        else if (tlbsrch && TLB_s_NE) begin//为查找且命中才写入
            csr_tlbidx_idx <= TLB_s_index;
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbidx_ps <= 6'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBIDX)begin
            csr_tlbidx_ps <=  csr_wmask[29:24] & csr_wvalue[29:24]
                           | ~csr_wmask[29:24] & csr_tlbidx_ps;
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbidx_ps <= TLB_r_ps;
        end
        else if (tlbrd && !TLB_r_E) begin
            csr_tlbidx_ps <= 0;
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbidx_ne <= 1'b1;
        end
        else if(csr_we && csr_num == `CSR_TLBIDX)begin
            csr_tlbidx_ne <=   csr_wmask[31] & csr_wvalue[31]
                            | ~csr_wmask[31] & csr_tlbidx_ne;
        end
        else if (tlbsrch) begin//为查找且命中才写入
            csr_tlbidx_ne <= !TLB_s_NE;
        end
        else if (tlbrd) begin
            csr_tlbidx_ne <= !TLB_r_E;
        end
    end

    assign TLB_r_index =  csr_tlbidx_idx;

    /////EHI(出现异常时需将vaddr记录于此!)
    reg [18:0]    csr_tlbehi_vppn; 
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbehi_vppn <= 19'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBEHI)begin
            csr_tlbehi_vppn <= csr_wmask[31:13] & csr_wvalue[31:13]
                            | ~csr_wmask[31:13] & csr_tlbehi_vppn;
        end
        else if (wb_ex && ( wb_ecode == 6'h3f || wb_ecode==6'h03 || wb_ecode==6'h01 || 
                            wb_ecode == 6'h02 || wb_ecode==6'h07 || wb_ecode==6'h04)) begin
            csr_tlbehi_vppn <= wb_vaddr[31:13];
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbehi_vppn <= TLB_r_vppn;
        end
        else if (tlbrd && !TLB_r_E) begin
            csr_tlbehi_vppn <= 0;
        end
    end

    assign TLB_s_vppn = csr_tlbehi_vppn;
    assign TLB_s_asid = csr_tlbasid_asid;


    //ELO0
    reg         csr_tlbELO0_v; 
    reg         csr_tlbELO0_d; 
    reg [1:0]   csr_tlbELO0_plv; 
    reg [1:0]   csr_tlbELO0_mat; 
    reg         csr_tlbELO0_g; 
    reg [19:0]  csr_tlbELO0_ppn; 
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbELO0_v   <= 1'b0;
            csr_tlbELO0_d   <= 1'b0;
            csr_tlbELO0_plv <= 2'b0;
            csr_tlbELO0_mat <= 2'b0;
            csr_tlbELO0_g   <= 1'b0;
            csr_tlbELO0_ppn <= 20'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBELO0)begin
            csr_tlbELO0_v <=   csr_wmask[0]    & csr_wvalue[0]
                            | ~csr_wmask[0]    & csr_tlbELO0_v;
            csr_tlbELO0_d <=   csr_wmask[1]    & csr_wvalue[1]
                            | ~csr_wmask[1]    & csr_tlbELO0_d;
            csr_tlbELO0_plv <= csr_wmask[3:2]  & csr_wvalue[3:2]
                            | ~csr_wmask[3:2]  & csr_tlbELO0_plv;
            csr_tlbELO0_mat <= csr_wmask[5:4]  & csr_wvalue[5:4]
                            | ~csr_wmask[5:4]  & csr_tlbELO0_mat;
            csr_tlbELO0_g <=   csr_wmask[6]    & csr_wvalue[6]
                            | ~csr_wmask[6]    & csr_tlbELO0_g;
            csr_tlbELO0_ppn <= csr_wmask[27:8] & csr_wvalue[27:8]
                            | ~csr_wmask[27:8] & csr_tlbELO0_ppn;
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbELO0_v   <= TLB_r_valid0;
            csr_tlbELO0_d   <= TLB_r_dirty0;
            csr_tlbELO0_plv <= TLB_r_plv0;
            csr_tlbELO0_mat <= TLB_r_mat0;
            csr_tlbELO0_g   <= TLB_r_g;//两个ELO的g位都置为与此一样
            csr_tlbELO0_ppn <= TLB_r_ppn0;
        end
        else if (tlbrd && !TLB_r_E)begin
            csr_tlbELO0_v   <= 0;
            csr_tlbELO0_d   <= 0;
            csr_tlbELO0_plv <= 0;
            csr_tlbELO0_mat <= 0;
            csr_tlbELO0_g   <= 0;//两个ELO的g位都置为与此一样
            csr_tlbELO0_ppn <= 0;
        end//如果无效，则全为0
    end

    assign TLB_w_ppn0 = csr_tlbELO0_ppn;
    assign TLB_w_plv0 = csr_tlbELO0_plv;
    assign TLB_w_mat0 = csr_tlbELO0_mat;
    assign TLB_w_d0   = csr_tlbELO0_d;
    assign TLB_w_v0   = csr_tlbELO0_v;

    //ELO1
    reg         csr_tlbELO1_v; 
    reg         csr_tlbELO1_d; 
    reg [1:0]   csr_tlbELO1_plv; 
    reg [1:0]   csr_tlbELO1_mat; 
    reg         csr_tlbELO1_g; 
    reg [19:0]  csr_tlbELO1_ppn; 
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbELO1_v   <= 1'b0;
            csr_tlbELO1_d   <= 1'b0;
            csr_tlbELO1_plv <= 2'b0;
            csr_tlbELO1_mat <= 2'b0;
            csr_tlbELO1_g   <= 1'b0;
            csr_tlbELO1_ppn <= 20'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBELO1)begin
            csr_tlbELO1_v <=   csr_wmask[0]    & csr_wvalue[0]
                            | ~csr_wmask[0]    & csr_tlbELO1_v;
            csr_tlbELO1_d <=   csr_wmask[1]    & csr_wvalue[1]
                            | ~csr_wmask[1]    & csr_tlbELO1_d;
            csr_tlbELO1_plv <= csr_wmask[3:2]  & csr_wvalue[3:2]
                            | ~csr_wmask[3:2]  & csr_tlbELO1_plv;
            csr_tlbELO1_mat <= csr_wmask[5:4]  & csr_wvalue[5:4]
                            | ~csr_wmask[5:4]  & csr_tlbELO1_mat;
            csr_tlbELO1_g <=   csr_wmask[6]    & csr_wvalue[6]
                            | ~csr_wmask[6]    & csr_tlbELO1_g;
            csr_tlbELO1_ppn <= csr_wmask[27:8] & csr_wvalue[27:8]
                            | ~csr_wmask[27:8] & csr_tlbELO1_ppn;
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbELO1_v   <= TLB_r_valid1;
            csr_tlbELO1_d   <= TLB_r_dirty1;
            csr_tlbELO1_plv <= TLB_r_plv1;
            csr_tlbELO1_mat <= TLB_r_mat1;
            csr_tlbELO1_g   <= TLB_r_g;//两个ELO的g位都置为与此一样
            csr_tlbELO1_ppn <= TLB_r_ppn1;
        end
        else if (tlbrd && !TLB_r_E)begin
            csr_tlbELO1_v   <= 0;
            csr_tlbELO1_d   <= 0;
            csr_tlbELO1_plv <= 0;
            csr_tlbELO1_mat <= 0;
            csr_tlbELO1_g   <= 0;//两个ELO的g位都置为与此一样
            csr_tlbELO1_ppn <= 0;
        end//如果无效，则全为0
    end

    assign TLB_w_ppn1 = csr_tlbELO1_ppn;
    assign TLB_w_plv1 = csr_tlbELO1_plv;
    assign TLB_w_mat1 = csr_tlbELO1_mat;
    assign TLB_w_d1   = csr_tlbELO1_d;
    assign TLB_w_v1   = csr_tlbELO1_v;

    assign TLB_w_vppn  =  csr_tlbehi_vppn;
    assign TLB_w_ps    =  csr_tlbidx_ps;
    assign TLB_w_e     = !csr_tlbidx_ne;
    assign TLB_w_index =  csr_tlbidx_idx;
    assign TLB_w_g     =  csr_tlbELO0_g && csr_tlbELO1_g;
    assign TLB_w_asid  = csr_tlbasid_asid;
    //两个ELO寄存器的g位都为有效时，才回去把tlb中的g位置为1

    //asid
    reg [9:0]   csr_tlbasid_asid;
    wire[7:0]   csr_tlbasid_asidbits;

    always @(posedge clk)begin
        if (reset) begin
            csr_tlbasid_asid <= 10'b0;
        end
        else if(csr_we && csr_num == `CSR_ASID)begin
            csr_tlbasid_asid <= csr_wmask[9:0] & csr_wvalue[9:0]
                             | ~csr_wmask[9:0] & csr_tlbasid_asid;
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbasid_asid <= TLB_r_asid;
        end
        else if (tlbrd && !TLB_r_E) begin
            csr_tlbasid_asid <= 0;
        end
    end

    assign csr_tlbasid_asidbits = 8'b1010;
    //写入tlb寄存器的asid来自于此，写不写由we控制

    //asid
    reg [25:0]   csr_tlbrentry;

    always @(posedge clk)begin
        if (reset) begin
            csr_tlbrentry <= 26'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBRENTRY)begin
            csr_tlbrentry <=   csr_wmask[31:6] & csr_wvalue[31:6]
                            | ~csr_wmask[31:6] & csr_tlbrentry;
        end
    end

    //tlb重填例外时跳转到此处

    reg         csr_dmw0_plv0;
    reg         csr_dmw0_plv3;
    reg [1:0]   csr_dmw0_mat;
    reg [2:0]   csr_dmw0_pseg;
    reg [2:0]   csr_dmw0_vseg;

    reg         csr_dmw1_plv0;
    reg         csr_dmw1_plv3;
    reg [1:0]   csr_dmw1_mat;
    reg [2:0]   csr_dmw1_pseg;
    reg [2:0]   csr_dmw1_vseg;

    //映射窗口寄存器
    always @(posedge clk) begin
        if (reset) begin
            csr_dmw0_plv0 <= 0;
            csr_dmw0_plv3 <= 0;
            csr_dmw0_mat <= 0;
            csr_dmw0_pseg <= 0;
            csr_dmw0_vseg <= 0;
        end else if (csr_we && csr_num==`CSR_DMW0) begin
            csr_dmw0_plv0 <= csr_wmask[0] & csr_wvalue[0]
                      | ~csr_wmask[0] & csr_dmw0_plv0;
            csr_dmw0_plv3 <= csr_wmask[3] & csr_wvalue[3]
                      | ~csr_wmask[3] & csr_dmw0_plv3;
            csr_dmw0_mat <= csr_wmask[5:4] & csr_wvalue[5:4]
                      | ~csr_wmask[5:4] & csr_dmw0_mat;
            csr_dmw0_pseg <= csr_wmask[27:25] & csr_wvalue[27:25]
                      | ~csr_wmask[27:25] & csr_dmw0_pseg;
            csr_dmw0_vseg <= csr_wmask[31:29] & csr_wvalue[31:29]
                      | ~csr_wmask[31:29] & csr_dmw0_vseg;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            csr_dmw1_plv0 <= 0;
            csr_dmw1_plv3 <= 0;
            csr_dmw1_mat <= 0;
            csr_dmw1_pseg <= 0;
            csr_dmw1_vseg <= 0;
        end else if (csr_we && csr_num==`CSR_DMW1) begin
            csr_dmw1_plv0 <= csr_wmask[0] & csr_wvalue[0]
                      | ~csr_wmask[0] & csr_dmw1_plv0;
            csr_dmw1_plv3 <= csr_wmask[3] & csr_wvalue[3]
                      | ~csr_wmask[3] & csr_dmw1_plv3;
            csr_dmw1_mat <= csr_wmask[5:4] & csr_wvalue[5:4]
                      | ~csr_wmask[5:4] & csr_dmw1_mat;
            csr_dmw1_pseg <= csr_wmask[27:25] & csr_wvalue[27:25]
                      | ~csr_wmask[27:25] & csr_dmw1_pseg;
            csr_dmw1_vseg <= csr_wmask[31:29] & csr_wvalue[31:29]
                      | ~csr_wmask[31:29] & csr_dmw1_vseg;
        end
    end

    ////////////////////////////////TLB相关csr寄存器

    wire csr_ticlr_clr;
    assign csr_ticlr_clr = 1'b0;
    
    assign csr_crmd_data  = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, 
                            csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    assign csr_prmd_data  = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    assign csr_ecfg_data  = {19'b0, csr_ecfg_lie[12:11], 1'd0, csr_ecfg_lie[9:0]};
    assign csr_estat_data = { 1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    assign csr_eentry_data= {csr_eentry_va, 6'b0};
    assign csr_badv_data  = csr_badv_vaddr;
    assign csr_tid_data   = csr_tid_tid;
    assign csr_tcfg_data  = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    assign csr_tval_data  = timer_cnt;
    assign csr_ticlr_data = {31'b0, csr_ticlr_clr};

    assign csr_tlbidx_data    = {csr_tlbidx_ne,1'b0,csr_tlbidx_ps,20'b0,csr_tlbidx_idx};
    assign csr_tlbehi_data    = {csr_tlbehi_vppn,13'b0};
    assign csr_tlbelo0_data   = {4'b0,csr_tlbELO0_ppn,1'b0,csr_tlbELO0_g,csr_tlbELO0_mat,csr_tlbELO0_plv,csr_tlbELO0_d,csr_tlbELO0_v};
    assign csr_tlbelo1_data   = {4'b0,csr_tlbELO1_ppn,1'b0,csr_tlbELO1_g,csr_tlbELO1_mat,csr_tlbELO1_plv,csr_tlbELO1_d,csr_tlbELO1_v};
    assign csr_tlbasid_data   = {8'b0,csr_tlbasid_asidbits,6'b0,csr_tlbasid_asid};
    assign csr_tlbrentry_data = {csr_tlbrentry,6'b0}; 
    assign csr_dmw0_data   = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
    assign csr_dmw1_data   = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};
    //锟斤拷取值
    assign csr_rvalue =  {32{csr_num == `CSR_CRMD}}      & csr_crmd_data
                       | {32{csr_num == `CSR_PRMD}}      & csr_prmd_data
                       | {32{csr_num == `CSR_ECFG}}      & csr_ecfg_data
                       | {32{csr_num == `CSR_ESTAT}}     & csr_estat_data
                       | {32{csr_num == `CSR_ERA}}       & csr_era_data
                       | {32{csr_num == `CSR_BADV}}      & csr_badv_data
                       | {32{csr_num == `CSR_EENTRY}}    & csr_eentry_data
                       | {32{csr_num == `CSR_SAVE0}}     & csr_save0_data
                       | {32{csr_num == `CSR_SAVE1}}     & csr_save1_data
                       | {32{csr_num == `CSR_SAVE2}}     & csr_save2_data
                       | {32{csr_num == `CSR_SAVE3}}     & csr_save3_data
                       | {32{csr_num == `CSR_TID}}       & csr_tid_data
                       | {32{csr_num == `CSR_TCFG}}      & csr_tcfg_data
                       | {32{csr_num == `CSR_TVAL}}      & csr_tval_data
                       | {32{csr_num == `CSR_TICLR}}     & csr_ticlr_data
                       | {32{csr_num == `CSR_TLBIDX}}    & csr_tlbidx_data
                       | {32{csr_num == `CSR_TLBEHI}}    & csr_tlbehi_data
                       | {32{csr_num == `CSR_TLBELO0}}   & csr_tlbelo0_data
                       | {32{csr_num == `CSR_TLBELO1}}   & csr_tlbelo1_data
                       | {32{csr_num == `CSR_ASID}}      & csr_tlbasid_data
                       | {32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry_data
                       | {32{csr_num==`CSR_DMW0}}        & csr_dmw0_data
                       | {32{csr_num==`CSR_DMW1}}        & csr_dmw1_data;

endmodule