module axi_sram_bridge(
    input  wire        clk,
    input  wire        reset,

    output wire [ 3:0]  arid   ,//
    output wire [31:0]  araddr ,//
    output wire [ 7:0]  arlen  ,//
    output wire [ 2:0]  arsize ,//
    output wire [ 1:0]  arburst,//
    output wire [ 1:0]  arlock ,//
    output wire [ 3:0]  arcache,//
    output wire [ 2:0]  arprot ,//
    output wire         arvalid,//
    input  wire         arready,
                
    input  wire [ 3:0]  rid   ,
    input  wire [31:0]  rdata ,
    input  wire [ 1:0]  rresp ,
    input  wire         rlast ,
    input  wire         rvalid,
    output wire         rready,//
               
    output wire [ 3:0]  awid   ,//
    output wire [31:0]  awaddr ,//
    output wire [ 7:0]  awlen  ,//
    output wire [ 2:0]  awsize ,//
    output wire [ 1:0]  awburst,//
    output wire [ 1:0]  awlock ,//
    output wire [ 3:0]  awcache,//
    output wire [ 2:0]  awprot ,//
    output wire         awvalid,//
    input  wire         awready,
    
    output wire [ 3:0]  wid   ,//
    output wire [31:0]  wdata ,//
    output wire [ 3:0]  wstrb ,//
    output wire         wlast ,//
    output wire         wvalid,//
    input  wire         wready,
    
    input  wire [ 3:0]  bid   ,
    input  wire [ 1:0]  bresp ,
    input  wire         bvalid,
    output wire         bready,//
    //axi_master

    //inst sram interface(��sram_slave)
//    input         inst_sram_req,
//    input         inst_sram_wr,
//    input [ 1:0]  inst_sram_size,
//    input [ 3:0]  inst_sram_wstrb,
//    input [31:0]  inst_sram_addr,
//    input [31:0]  inst_sram_wdata,
//    output        inst_sram_addr_ok,//
//    output        inst_sram_data_ok,//
//    output[31:0]  inst_sram_rdata,//
    input               	icache_rd_req,
    input   	[ 2:0]      icache_rd_type,
    input   	[31:0]      icache_rd_addr,
    output              	icache_rd_rdy,		// icache_addr_ok
    output              	icache_ret_valid,	// icache_data_ok
	output					icache_ret_last,
    output  	[31:0]      icache_ret_data,
    // data sram interface(��sram_slave)
    input         data_sram_req,
    input         data_sram_wr,
    input [ 1:0]  data_sram_size,
    input [ 3:0]  data_sram_wstrb,
    input [31:0]  data_sram_addr,
    input [31:0]  data_sram_wdata,
    output        data_sram_addr_ok,//
    output        data_sram_data_ok,//
    output[31:0]  data_sram_rdata//
);

    wire        inst_write;//ȡָд
    wire        inst_read;//ȡָ��
    wire        data_write;//�ô�д
    wire        data_read;//�ô��

    assign      inst_read   = icache_rd_req;
    assign      data_read   = data_sram_req && !data_sram_wr;
    assign      data_write  = data_sram_req && data_sram_wr;

    //arͨ��
    localparam  AR_INIT = 5'b00000,
                AR_REQUIRE = 5'b00001,
                AR_VALID_IF_ADDR = 5'b00010,
                AR_VALID_MEM_ADDR = 5'b00100,
                AR_VALID_IF_CANCEL = 5'b01000,
                AR_VALID_MEM_CANCEL = 5'b01000;
    reg [ 4:0]  ar_current_state;
    reg [ 4:0]  ar_next_state;
    //��������cancel״???����Ϊ�˱�֤����cancel״???����REQUIRE״???ʱ���ü�cancel_cnt
    //��Ϊ��ʱҪô�Ѿ�ȡ���˶�Ӧ�ģ�Ҫôvalid�źŲ�������

    wire[34:0]  ar_info_inst;
    wire[34:0]  ar_info_data;
    reg [34:0]  ar_info_reg;

    assign ar_info_inst =  {3'b010,//3λsize
                            icache_rd_addr};//32
    assign ar_info_data =  {1'b0,data_sram_size,//3λsize
                            data_sram_addr};//32
    always @(posedge clk) begin
        if(reset)begin
            ar_info_reg <= 35'b0;
        end
        if(ar_current_state[0] && data_read)begin
            ar_info_reg <= ar_info_data;
        end else if(ar_current_state[0] && inst_read && !data_read)begin
            ar_info_reg <= ar_info_inst;
        end
    end

    always @(posedge clk)begin
        if(reset) begin
            ar_current_state <= AR_INIT;
        end else begin
            ar_current_state <= ar_next_state;
        end
    end

    always @(*)begin
        case(ar_current_state)
            AR_INIT:begin
                ar_next_state = AR_REQUIRE;
            end
            AR_REQUIRE:begin
                if(data_read)begin
                    ar_next_state = AR_VALID_MEM_ADDR;
                end else if(inst_read && !data_read)begin//MEM�����ȼ��ϸ�
                    ar_next_state = AR_VALID_IF_ADDR;
                end else begin
                    ar_next_state = AR_REQUIRE;
                end
            end
            AR_VALID_IF_ADDR:begin
                if(arvalid && arready)begin
                    ar_next_state = AR_REQUIRE;
                end else if(icache_rd_addr != ar_info_reg[31:0])begin
                    ar_next_state = AR_VALID_IF_CANCEL;
                end else begin
                    ar_next_state = AR_VALID_IF_ADDR;
                end
            end
            AR_VALID_MEM_ADDR:begin
                if(arvalid && arready)begin
                    ar_next_state = AR_REQUIRE;
                end else if(!data_read)begin
                    ar_next_state = AR_VALID_MEM_CANCEL;
                end else begin
                    ar_next_state = AR_VALID_MEM_ADDR;
                end
            end
            AR_VALID_IF_CANCEL:begin
                if(arvalid && arready)begin
                    ar_next_state = AR_REQUIRE;
                end else begin
                    ar_next_state = AR_VALID_IF_CANCEL;
                end
            end
            AR_VALID_MEM_CANCEL:begin
                if(arvalid && arready)begin
                    ar_next_state = AR_REQUIRE;
                end else begin
                    ar_next_state = AR_VALID_MEM_CANCEL;
                end
            end
            default:begin
                ar_next_state = AR_INIT;
            end
        endcase
    end

    assign arvalid = (icache_rd_req || data_sram_req) && 
                     (ar_current_state[1] || ar_current_state[2] ||
                      ar_current_state[3] || ar_current_state[4]);
    assign arid    = ar_current_state[2] || ar_current_state[4];
    assign araddr  = ar_info_reg[31:0];
//    reg [7:0] arlen_r;
//    always @(posedge clk) begin
//		if(reset) begin
//            arlen_r <= 8'd0;
//		end
//		else if(ar_current_state[0]) begin// ������״̬��Ϊ����״̬����������
//			arlen_r[1:0] <= icache_rd_req? 2'd3 : 2'd0;
//		end
//	end
    assign arlen   = arid ? 8'd0 : 8'd3;
    assign arsize  = ar_info_reg[34:32];
    assign arburst = 2'b01;
    assign arlock  = 2'b0;
    assign arcache = 4'b0;
    assign arprot  = 3'b0;

    //rͨ��

    localparam  R_INIT = 3'b00,
                R_WAIT = 3'b01,//�ڵȴ�������
                R_OK   = 3'b10,//������֮��׼�������ݴ���
                R_MID =  3'b100;
    reg [ 2:0]  r_current_state;
    reg [ 1:0]  r_next_state;

    reg [ 7:0]  r_cancel_data;//�����ar�����ڼ䣬���ּĴ����е�ֵ�봫���ĵ�??��һ����˵����ǰ��ȡָ��Ҫȡ��������ע��ȡ����һ����rid==0??
    reg [ 7:0]  r_cancel_inst;//�����ar�����ڼ䣬���ּĴ����е�ֵ�봫���ĵ�??��һ����˵����ǰ��ȡָ��Ҫȡ��������ע��ȡ����һ����rid==0??
    reg [ 7:0]  r_wait_cnt;//�����Ѿ������˶�������ֻҪ��Ϊ0��r_valid����??

    always @(posedge clk)begin
        if(reset) begin
            r_cancel_inst <= 2'b0;
        end else if(ar_current_state[1] && (icache_rd_addr != ar_info_reg[31:0])) begin//
            r_cancel_inst <= r_cancel_inst + 8'd4;
        end else if(r_current_state[1] && (r_info_reg[38:35] == 4'b0) && r_cancel_inst)begin
            r_cancel_inst <= r_cancel_inst - 8'd1;
        end
    end

    always @(posedge clk)begin
        if(reset) begin
            r_cancel_data <= 2'b0;
        end else if(ar_current_state[2] && !data_read) begin
            r_cancel_data <= r_cancel_data + 8'd1;
        end else if(r_current_state[1] && (r_info_reg[38:35] == 4'b1) && r_cancel_data)begin
            r_cancel_data <= r_cancel_data - 8'd1;
        end
    end

    always @(posedge clk)begin
        if(reset) begin
            r_wait_cnt <= 8'b0;
        end else if((arvalid && arready) && !(rvalid && rready)) begin
            r_wait_cnt <= r_wait_cnt + arlen + 1'b1;
        end else if(!(arvalid && arready) && (rvalid && rready)) begin
            r_wait_cnt <= r_wait_cnt - 8'b1;
        end else if((arvalid && arready) && (rvalid && rready)) begin
            r_wait_cnt <= r_wait_cnt + arlen;
        end
    end
    //��valid�ź��Ѿ������Ľ׶Σ��������ӣ����Ҽ�סֻ��inst���ܻᱻȡ��

    // wire[34:0]  ar_info_inst;
    // wire[34:0]  ar_info_data;
    reg [38:0]  r_info_reg;
    wire[38:0]  r_info;

    assign r_info   = {rid,     //4
                       rdata,   //32
                       rresp,   //2
                       rlast};  //1

    always @(posedge clk) begin
        if(reset)begin
            r_info_reg <= 39'b0;
        end else if(rvalid && rready)begin
            r_info_reg <= r_info;
        end
    end

    always @(posedge clk)begin
        if(reset) begin
            r_current_state <= R_INIT;
        end else begin
            r_current_state <= r_next_state;
        end
    end

    always @(*)begin
        case(r_current_state)
            R_INIT:begin
                r_next_state = R_WAIT;
            end
            R_WAIT:begin
                if(rvalid && rready)begin
                    r_next_state = R_OK;
                end else begin
                    r_next_state = R_WAIT;
                end
            end
            R_OK:begin
                if(rvalid && rready)begin
                    r_next_state = R_OK;
                end else begin
                    r_next_state = R_WAIT;
                end
            end
            default:begin
                r_next_state = R_INIT;
            end
        endcase
    end

    assign rready  = (r_wait_cnt != 8'b0);
    //assign inst_sram_rdata = r_info_reg[34:3];
    assign data_sram_rdata = r_info_reg[34:3];


    //w,awͨ��
    localparam  W_INIT = 4'b0000,
                W_REQUIRE = 4'b0001,
                W_VALID_ADDR = 4'b0010,
                W_WREADY = 4'b0100,
                W_AWREADY = 4'b1000;
    reg [ 3:0]  w_current_state;
    reg [ 3:0]  w_next_state;

    wire[70:0]  w_info;
    reg [70:0]  w_info_reg;
    
    wire        next_is_require;

    assign w_info   = {1'b0,data_sram_size,//3
                       data_sram_wstrb,   //4
                       data_sram_addr,    //32
                       data_sram_wdata};  //32
    assign next_is_require = (w_current_state[2] && awvalid && awready) || 
                             (w_current_state[3] && wvalid && wready)   ||
                             (w_current_state[1] && wvalid && wready && awvalid && awready);

    always @(posedge clk) begin
        if(reset)begin
            w_info_reg <= 71'b0;
        end else if(w_current_state[0] && data_write)begin
            w_info_reg <= w_info;
        end
    end

    always @(posedge clk)begin
        if(reset) begin
            w_current_state <= AR_INIT;
        end else begin
            w_current_state <= w_next_state;
        end
    end

    always @(*)begin
        case(w_current_state)
            W_INIT:begin
                w_next_state = W_REQUIRE;
            end
            W_REQUIRE:begin
                if(data_write)begin
                    w_next_state = W_VALID_ADDR;
                end else begin
                    w_next_state = W_REQUIRE;
                end
            end
            W_VALID_ADDR:begin
                if((awvalid && awready) && (wvalid && wready))begin
                    w_next_state = W_REQUIRE;
                end else if(awvalid && awready)begin
                    w_next_state = W_AWREADY;
                end else if(wvalid && wready)begin
                    w_next_state = W_WREADY;
                end else begin
                    w_next_state = W_VALID_ADDR;
                end
            end
            W_WREADY:begin
                if(awvalid && awready)begin
                    w_next_state = W_REQUIRE;
                end else begin
                    w_next_state = W_WREADY;
                end
            end
            W_AWREADY:begin
                if(wvalid && wready)begin
                    w_next_state = W_REQUIRE;
                end else begin
                    w_next_state = W_AWREADY;
                end
            end
            default:begin
                w_next_state = W_INIT;
            end
        endcase
    end

    assign awvalid = data_sram_req && (w_current_state[1] || w_current_state[2]);
    assign awid    = 4'b1;
    assign awaddr  = w_info_reg[63:32];
    assign awlen   = 8'b0;
    assign awsize  = w_info_reg[70:68];
    assign awburst = 2'b1;
    assign awlock  = 2'b0;
    assign awcache = 4'b0;
    assign awprot  = 3'b0;

    assign wvalid  = data_sram_req && (w_current_state[1] || w_current_state[3]);
    assign wid     = 4'b1;
    assign wdata   = w_info_reg[31:0];
    assign wstrb   = w_info_reg[67:64];
    assign wlast   = 1'b1;

    //bͨ��
    localparam  B_INIT = 2'b00,
                B_REQUIRE = 2'b01,
                B_VALID_DATA = 2'b10;
    reg [ 1:0]  b_current_state;
    reg [ 1:0]  b_next_state;


    always @(posedge clk)begin
        if(reset) begin
            b_current_state <= B_INIT;
        end else begin
            b_current_state <= b_next_state;
        end
    end

    always @(*)begin
        case(b_current_state)
            B_INIT:begin
                b_next_state = B_REQUIRE;
            end
            B_REQUIRE:begin
                if(next_is_require)begin
                    b_next_state = B_VALID_DATA;
                end else begin
                    b_next_state = B_REQUIRE;
                end
            end
            B_VALID_DATA:begin
                if(bvalid && bready)begin
                    b_next_state = B_REQUIRE;
                end else begin
                    b_next_state = B_VALID_DATA;
                end
            end
            default:begin
                b_next_state = B_INIT;
            end
        endcase
    end

    assign bready = b_current_state[1];











    //assign inst_sram_addr_ok = ar_current_state[1] && arvalid && arready && (icache_rd_addr == ar_info_reg[31:0]);//
    //cancle̬�����ԣ���ʱ��cpu���Ѿ�Ĭ��addr_ok��Ӧ������һ��ָ����
    assign data_sram_addr_ok = (ar_current_state[2] && arvalid && arready) ||
                                next_is_require;
                               
    //assign inst_sram_data_ok =  r_current_state[1] && !r_info_reg[35] && !r_cancel_inst;
    
    assign data_sram_data_ok = (r_current_state[1] &&  r_info_reg[35] && !r_cancel_data) ||
                               (b_current_state[1] && bvalid && bready);
    assign icache_rd_rdy = (arvalid && arready) && (ar_current_state[1] || ar_current_state[3]);		// icache_addr_ok
   	assign icache_ret_valid = r_current_state[1] && !r_info_reg[35] && !r_cancel_inst;
	assign icache_ret_last = r_current_state[1] && r_info_reg[0] && !r_info_reg[35] && !r_cancel_inst;
    assign icache_ret_data = r_info_reg[34:3];
endmodule