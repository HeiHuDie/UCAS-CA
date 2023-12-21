module cache (
    input wire clk,
    input wire resetn,
    
    input  wire        valid,
    input  wire        op,
    input  wire [ 7:0] index,    // virtual
    input  wire [19:0] tag,      // physical
    input  wire [ 3:0] offset,
    input  wire [ 3:0] wstrb,
    input  wire [31:0] wdata,
    output wire        addr_ok,
    output wire        data_ok,
    output wire [31:0] rdata,
    
    // read
    output wire         rd_req,
    output wire [  2:0] rd_type,    // 3'b100 for page
    output wire [ 31:0] rd_addr,
    input  wire         rd_rdy,
    input  wire         ret_valid,
    input  wire         ret_last,
    input  wire [ 31:0] ret_data,
    
    // write
    output wire         wr_req,
    output wire [  2:0] wr_type,    // 3'b100 for page
    output wire [ 31:0] wr_addr,
    output wire [  3:0] wr_wstrb,
    output wire [127:0] wr_data,
    input  wire         wr_rdy
    );
wire rst = ~resetn;
    
// TAGV Ram Ports
wire way0_tagv_wen, way1_tagv_wen;
wire [7:0] way0_tagv_addr, way1_tagv_addr;
wire [20:0] way0_tagv_wdata, way1_tagv_wdata;
wire [20:0] way0_tagv_rdata, way1_tagv_rdata;
wire [19:0] way0_tag, way1_tag;
wire way0_v, way1_v;
//reg flag
//reg flag_r;
//reg [31:0] rd_addr_r;
//always @(posedge clk) begin
//    if(m_current_state == M_MISS)begin
//        rd_addr_r <= rd_addr;
//    end
//    if(rd_addr_r != rd_addr)begin
//        flag_r <= 1'd1;
//    end
//end
//wire flag;
//assign flag = rd_addr_r != rd_addr;
// Data Bank Ram Ports
wire [3:0] way0_data_wen, way1_data_wen;
wire [ 7:0] way0_data_addr [3:0];
wire [ 7:0] way1_data_addr [3:0];
wire [31:0] way0_data_wdata[3:0];
wire [31:0] way1_data_wdata[3:0];
wire [31:0] way0_data_rdata[3:0];
wire [31:0] way1_data_rdata[3:0];
wire [127:0] way0_data, way1_data;
wire [31:0] way0_data_refill[3:0];
wire [31:0] way1_data_refill[3:0];

// D array
reg [255:0] way0_d_array, way1_d_array;
reg way0_d, way1_d;

// regs for Request Buffer
reg         rb_op;
reg  [ 7:0] rb_index;
reg  [19:0] rb_tag;
reg  [ 3:0] rb_offset;
reg  [ 3:0] rb_wstrb;
reg  [31:0] rb_wdata;
wire [31:0] rb_wstrb_ext;

// regs for Write Buffer
reg  [ 7:0] wb_index;
reg         wb_way;
reg  [ 3:0] wb_offset;
reg  [ 3:0] wb_wstrb;
wire [31:0] wb_wstrb_ext;
reg [31:0] wb_wdata, wb_odata;

// regs for Miss Buffer
// replace_way keep unchanged LOOKUP, don't need to store it.
reg [31:0] mb_cnt;
reg [2:0] lfsr_r;
wire way0_hit, way1_hit, cache_hit;

wire [127:0] replace_data;
reg          replace_way;
wire         relpace_d;
wire [ 19:0] replace_tag;

wire [31:0] way0_load_word, way1_load_word, load_res;

wire hit_write;

reg  wr_req_r;

wire hit_write_hazard;
wire hit_write_hazard_lookup;
wire hit_write_hazard_write;

//FSM
localparam M_IDLE = 5'b1,
           M_LOOKUP = 5'b10,
           M_MISS = 5'b100,
           M_REPLACE = 5'b1000,
           M_REFILL = 5'b10000;
reg [4:0] m_current_state;
reg [4:0] m_next_state;
localparam W_IDLE = 2'b1,
           W_WRITE = 2'b10;
reg [1:0] w_current_state;
reg [1:0] w_next_state;

always @(posedge clk)
begin
    if(rst)begin
        m_current_state <= M_IDLE;
        w_current_state <= W_IDLE;
    end else begin
        m_current_state <= m_next_state;
        w_current_state <= w_next_state;
    end
end
always @(*)begin
    case (m_current_state)
        M_IDLE:
        begin
            if (valid & ~hit_write_hazard) begin
                m_next_state = M_LOOKUP;
            end else begin
                m_next_state = M_IDLE;
            end
        end
        M_LOOKUP:
        begin
            if (cache_hit & (~valid | valid & hit_write_hazard)) begin
                m_next_state = M_IDLE;
            end else if (cache_hit & valid & ~hit_write_hazard) begin
                m_next_state = M_LOOKUP;
            end else if (~cache_hit)begin
                m_next_state = M_MISS;
            end else begin
                m_next_state = M_LOOKUP;
            end
        end
        M_MISS:
        begin
            if (wr_rdy) begin
                m_next_state = M_REPLACE;
            end else begin
                m_next_state = M_MISS;
            end
        end
        M_REPLACE:
            if (rd_rdy) begin
                m_next_state = M_REFILL;
            end else begin
                m_next_state = M_REPLACE;
            end
        M_REFILL:
        begin
            if (ret_valid & ret_last) begin
                m_next_state = M_IDLE;
            end else begin
                m_next_state = M_REFILL;
            end
        end
        default:
        begin
            m_next_state = M_IDLE;
        end
    endcase
end

always @(*)begin
    case (w_current_state)
        W_IDLE:
        begin
            if (hit_write)begin
                w_next_state = W_WRITE;
            end else begin
                w_next_state = W_IDLE;
            end
        end
        W_WRITE:
        begin
            if (hit_write)begin
                w_next_state = W_WRITE;
            end else begin
                w_next_state = W_IDLE;
            end
        end
        default:
        begin
            w_next_state = W_IDLE;
        end
    endcase
end

// Cache Table
// TAGV
tagv_ram way0_tagv_ram (
             .clka (clk),
             .wea  (way0_tagv_wen),
             .addra(way0_tagv_addr),
             .dina (way0_tagv_wdata),
             .douta(way0_tagv_rdata)
         );
tagv_ram way1_tagv_ram (
             .clka (clk),
             .wea  (way1_tagv_wen),
             .addra(way1_tagv_addr),
             .dina (way1_tagv_wdata),
             .douta(way1_tagv_rdata)
         );
// TAGV
assign way0_tagv_wen = (m_current_state == M_REFILL) & ~replace_way;
assign way1_tagv_wen = (m_current_state == M_REFILL) & replace_way;
assign way0_tagv_addr = {8{m_current_state == M_IDLE}} & index
                      | {8{m_current_state == M_LOOKUP}} & rb_index
                      | {8{m_current_state == M_MISS}} & rb_index
                      | {8{m_current_state == M_REFILL}} & rb_index;
assign way1_tagv_addr = {8{m_current_state == M_IDLE}} & index
                      | {8{m_current_state == M_LOOKUP}} & rb_index
                      | {8{m_current_state == M_MISS}} & rb_index
                      | {8{m_current_state == M_REFILL}} & rb_index;
assign way0_tagv_wdata = {21{m_current_state == M_REFILL}} & {rb_tag, 1'b1};
assign way1_tagv_wdata = {21{m_current_state == M_REFILL}} & {rb_tag, 1'b1};
assign {way0_tag, way0_v} = way0_tagv_rdata;
assign {way1_tag, way1_v} = way1_tagv_rdata;

// Data Bank
genvar i;
generate
    for (i = 0; i < 4; i = i + 1)
    begin : data_bank_gen
        data_bank_ram way0_data_bank_ram (
                          .clka (clk),
                          .wea  (way0_data_wen[i]),
                          .addra(way0_data_addr[i]),
                          .dina (way0_data_wdata[i]),
                          .douta(way0_data_rdata[i])
                      );
        data_bank_ram way1_data_bank_ram (
                          .clka (clk),
                          .wea  (way1_data_wen[i]),
                          .addra(way1_data_addr[i]),
                          .dina (way1_data_wdata[i]),
                          .douta(way1_data_rdata[i])
                      );
    end
endgenerate
assign wb_wstrb_ext = {{8{wb_wstrb[3]}}, {8{wb_wstrb[2]}}, {8{wb_wstrb[1]}}, {8{wb_wstrb[0]}}};
assign rb_wstrb_ext = {{8{rb_wstrb[3]}}, {8{rb_wstrb[2]}}, {8{rb_wstrb[1]}}, {8{rb_wstrb[0]}}};
generate
    for (i = 0; i < 4; i = i + 1)
    begin : data_bank_IO_gen
        assign way0_data_wen[i]    = (w_current_state == W_WRITE) & wb_offset[3:2] == i
                                     | (m_current_state == M_REFILL) & ~replace_way & mb_cnt == i;
        assign way1_data_wen[i]    = (w_current_state == W_WRITE) & wb_offset[3:2] == i
                                     | (m_current_state == M_REFILL) & replace_way & mb_cnt == i;
        assign way0_data_addr[i]   = {8{m_current_state == M_IDLE}} & index
                                     | {8{m_current_state == M_LOOKUP}} & index
                                     | {8{m_current_state == M_MISS}} & rb_index
                                     | {8{m_current_state == M_REFILL}} & rb_index
                                     | {8{w_current_state == W_WRITE}} & wb_index;
        assign way1_data_addr[i]   = {8{m_current_state == M_IDLE}} & index
                                     | {8{m_current_state == M_LOOKUP}} & index
                                     | {8{m_current_state == M_MISS}} & rb_index
                                     | {8{m_current_state == M_REFILL}} & rb_index
                                     | {8{w_current_state == W_WRITE}} & wb_index;
        assign way0_data_refill[i] = ((rb_op == 1 & rb_offset[3:2] == i) ? (ret_data & ~rb_wstrb_ext | rb_wdata & rb_wstrb_ext) : ret_data);
        assign way0_data_wdata[i]  = {32{w_current_state == W_WRITE}} & (wb_odata & ~wb_wstrb_ext | wb_wdata & wb_wstrb_ext)
                                     | {32{m_current_state == M_REFILL}} & way0_data_refill[i];
        assign way1_data_refill[i] = ((rb_op == 1 & rb_offset[3:2] == i) ? (ret_data & ~rb_wstrb_ext | rb_wdata & rb_wstrb_ext) : ret_data);
        assign way1_data_wdata[i]  = {32{w_current_state == W_WRITE}} & (wb_odata & ~wb_wstrb_ext | wb_wdata & wb_wstrb_ext)
                                     | {32{m_current_state == M_REFILL}} & way1_data_refill[i];
        assign way0_data[i*32+:32] = way0_data_rdata[i];
        assign way1_data[i*32+:32] = way1_data_rdata[i];
    end
endgenerate

// D
always @(posedge clk)
begin
    if (rst)begin
        way0_d_array <= 256'b0;
    end else if (w_current_state == 1 & ~wb_way)begin
        way0_d_array[wb_index] <= 1'b0;
    end else if (m_current_state == M_REFILL & ~replace_way)begin
        if (rb_op == 1)begin
            way0_d_array[rb_index] <= 1'b1;
        end else begin
            way0_d_array[rb_index] <= 1'b0;
        end
    end
end
always @(posedge clk)
begin
    if (rst)begin
        way1_d_array <= 256'b0;
    end else if (w_current_state == 1 & wb_way)begin
        way1_d_array[wb_index] <= 1'b0;
    end else if (m_current_state == M_REFILL & replace_way)begin
        if (rb_op == 1)begin
            way1_d_array[rb_index] <= 1'b1;
        end else begin
            way1_d_array[rb_index] <= 1'b0;
        end
    end
end
always @(posedge clk)
begin
    if (rst) begin
        way0_d <= 1'b0;
    end else if (m_current_state == M_MISS & m_next_state == M_REPLACE) begin
        way0_d <= way0_d_array[rb_index];
    end
end
always @(posedge clk)
begin
    if (rst)begin
        way1_d <= 1'b0;
    end else if (m_current_state == M_MISS & m_next_state == M_REPLACE) begin
        way1_d <= way1_d_array[rb_index];
    end
end

// Request Buffer
always @(posedge clk)
begin
    if (rst)begin
        rb_op     <= 1'b0;
        rb_index  <= 8'b0;
        rb_tag    <= 20'b0;
        rb_offset <= 4'b0;
        rb_wstrb  <= 4'b0;
        rb_wdata  <= 32'b0;
    end else if (m_next_state == M_LOOKUP)begin
        rb_op     <= op;
        rb_index  <= index;
        rb_tag    <= tag;
        rb_offset <= offset;
        rb_wstrb  <= wstrb;
        rb_wdata  <= wdata;
    end
end

// Tag Compare
assign way0_hit       = way0_v && (way0_tag == rb_tag);
assign way1_hit       = way1_v && (way1_tag == rb_tag);
assign cache_hit      = way0_hit || way1_hit;

// Data Select
assign way0_load_word = way0_data[rb_offset[3:2]*32+:32];
assign way1_load_word = way1_data[rb_offset[3:2]*32+:32];
assign load_res       = (m_current_state == M_REFILL) ? ret_data
                        : {32{way0_hit}} & way0_load_word | {32{way1_hit}} & way1_load_word;

// Miss Buffer
always @(posedge clk)
begin
    if (rst)begin
        mb_cnt <= 32'b0;
    end else if (ret_valid & ret_last)begin
        mb_cnt <= 32'b0;
    end else if (ret_valid)begin
        mb_cnt <= mb_cnt + 1;
    end
end

// Replace
always @(posedge clk)
begin
    if (rst)begin
        replace_way <= 1'b0;
    end else if (m_current_state == M_LOOKUP & ~cache_hit)begin
        replace_way <= lfsr_r[0];
    end
end
// block_ram returns at next clock
// read req at M_MISS & return at M_REPLACE
assign replace_data = replace_way ? way1_data : way0_data;
assign replace_tag  = replace_way ? way1_tag : way0_tag;
assign relpace_d    = replace_way ? (way1_v & way1_d) : (way0_v & way0_d);

// LFSR (design book hasn't specify the design of LFSR?)
always @(posedge clk)begin
    if (rst)begin
        lfsr_r <= 3'b111;
    end else begin
        lfsr_r <= {lfsr_r[0],lfsr_r[2]^lfsr_r[0],lfsr_r[1]};
    end
end

// Write Buffer
assign hit_write = m_current_state == M_LOOKUP & cache_hit & rb_op == 1;
always @(posedge clk)begin
    if (rst)begin
        wb_index  <= 8'b0;
        wb_way    <= 1'b0;
        wb_offset <= 4'b0;
        wb_wstrb  <= 4'b0;
        wb_wdata  <= 32'b0;
    end else if (hit_write)begin
        wb_index  <= rb_index;
        wb_way    <= way1_hit;
        wb_offset <= rb_offset;
        wb_wstrb  <= rb_wstrb;
        wb_wdata  <= rb_wdata;
        wb_odata  <= load_res;
    end
end

// Output Signals
assign addr_ok = m_current_state == M_IDLE & ~hit_write_hazard
       | m_current_state == M_LOOKUP & cache_hit & ~hit_write_hazard;
assign data_ok = m_current_state == M_LOOKUP & cache_hit
       | m_current_state == M_REFILL & ret_valid & mb_cnt == rb_offset[3:2];
assign rdata   = {32{m_current_state == M_LOOKUP}} & load_res
       | {32{m_current_state == M_REFILL}} & ret_data;
assign rd_req  = m_current_state == M_REPLACE;
assign rd_type = 3'b100;
assign rd_addr = {rb_tag, rb_index, 4'b0};
always @(posedge clk)begin
    if (rst)begin
        wr_req_r <= 1'b0;
    end else if (m_current_state == M_MISS & m_next_state == M_REPLACE)begin
        wr_req_r <= 1'b1;
    end else if (wr_rdy)begin
        wr_req_r <= 1'b0;
    end
end
assign wr_req = wr_req_r & relpace_d;
assign wr_type = 3'b100;
assign wr_addr = {replace_tag, rb_index, 4'b0};
assign wr_wstrb = 4'b0;
assign wr_data = replace_data;

// Hit Write Hazard
assign hit_write_hazard_lookup = (m_current_state == M_LOOKUP)
                                 & (rb_op == 1)
                                 & cache_hit & valid
                                 & (op == 0)
                                 & (rb_tag == tag)
                                 & (rb_index == index)
                                 & (rb_offset[3:2] == offset[3:2]);
assign hit_write_hazard_write = (w_current_state == W_WRITE)
                                & valid & (op == 0)
                                & (wb_index == index)
                                & (wb_offset[3:2] == offset[3:2]);
assign hit_write_hazard = hit_write_hazard_lookup | hit_write_hazard_write;

endmodule