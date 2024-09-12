
module video_wr_buffer#(
    parameter AXI_DATA_WIDTH        = 128   ,
    parameter AXI_ADDR_WIDTH        = 32
    )(
    //system signal
    input                                   i_clk                 ,
    input                                   i_reset               ,
    //AXI clock
    input   wire                            i_axi_clk             ,
    //AXI write channel signal
    output  reg                             m_axi_awvalid         ,
    input                                   m_axi_awready         ,
    output  reg  [AXI_ADDR_WIDTH-1:0]       m_axi_awaddr          ,
    output       [3:0]                      m_axi_awid            ,
    output  reg  [7:0]                      m_axi_awlen           ,
    output       [1:0]                      m_axi_awburst         ,
    output       [2:0]                      m_axi_awsize          ,
    output       [2:0]                      m_axi_awprot          ,
    output       [3:0]                      m_axi_awqos           ,
    output                                  m_axi_awlock          ,
    output       [3:0]                      m_axi_awcache         ,
    output  reg                             m_axi_wvalid          ,
    input                                   m_axi_wready          ,
    output  reg  [AXI_DATA_WIDTH-1:0]       m_axi_wdata           ,
    output       [AXI_DATA_WIDTH/8-1:0]     m_axi_wstrb           ,
    output  reg                             m_axi_wlast  	      ,
    input        [3:0]                      m_axi_bid             ,
    input        [1:0]                      m_axi_bresp           ,
    input                                   m_axi_bvalid          ,
    output                                  m_axi_bready          ,
    //video_wr_ctrl interaction signal 
    input   wire                            i_wr_buff_req_en      ,
    input   wire                            i_wr_buff_vld         ,
    input   wire [7:0]                      i_wr_buff_burst_len   ,
    input   wire [AXI_ADDR_WIDTH-1:0]       i_wr_buff_addr        ,
    input   wire [AXI_DATA_WIDTH-1:0]       i_wr_buff_data        ,
    input   wire                            i_wr_buff_data_last   ,
    //debug fifo signal
    output  wire                            o_wr_cmd_fifo_err     ,
    output  wire                            o_wr_data_fifo_err    
    );
/*----------------------		parameter       		----------------------*/
    localparam AXI_WR_IDLE = 4'b0001;
    localparam AXI_WR_PRE  = 4'b0010;
    localparam AXI_WR_DATA = 4'b0100;
    localparam AXI_WR_END  = 4'b1000;
/*----------------------		internal reg signal		----------------------*/
    //output register
    reg r_o_wr_cmd_fifo_err ;
    reg r_o_wr_data_fifo_err;
    //delay
    (* dont_touch ="true" *) reg reset_ff0;
    (* dont_touch ="true" *) reg reset_ff1;
    (* dont_touch ="true" *) reg reset_sync;
    (* dont_touch ="true" *) reg axi_reset_ff0;
    (* dont_touch ="true" *) reg axi_reset_ff1;
    (* dont_touch ="true" *) reg axi_reset_sync;
    //state machine
    reg [3:0] state_current,state_next;
    //command fifo control signal
    reg				cmd_wren;
    reg	[39:0]		cmd_din;
    //data fifo control signal
    reg				data_wren;
    reg				data_rden;
/*----------------------		internal wire signal 	----------------------*/
    //command fifo control signal
    wire [39:0]	    cmd_dout;
    wire			cmd_rden;
    wire			cmd_wrfull;
    wire			cmd_rdempty;
    wire [4:0]	    cmd_wrcount;
    wire [4:0]	    cmd_rdcount;
    //data fifo control signal
    wire			data_wrfull;
    wire			data_rdempty;
/*---------------------- 		output assign 			----------------------*/
    assign o_wr_cmd_fifo_err  = r_o_wr_cmd_fifo_err ;
    assign o_wr_data_fifo_err = r_o_wr_data_fifo_err;
/*----------------------		state machine			----------------------*/
    always@(posedge i_axi_clk)begin
        if(axi_reset_sync)
            state_current <= AXI_WR_IDLE;
        else
            state_current <= state_next;
    end

    always@(*)begin
        case(state_current)
            AXI_WR_IDLE:begin
                if(~cmd_rdempty)
                    state_next = AXI_WR_PRE;
                else
                    state_next = state_current; end
            AXI_WR_PRE:begin
                state_next = AXI_WR_DATA; end
            AXI_WR_DATA:begin
                if(m_axi_wvalid && m_axi_wready && m_axi_wlast)
                    state_next = AXI_WR_END;
                else
                    state_next = state_current; end
            AXI_WR_END:begin
                state_next = AXI_WR_IDLE; end
            default: state_next = AXI_WR_IDLE;
        endcase
    end

    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) 
            m_axi_awvalid <= 0;
        else if (m_axi_awvalid && m_axi_awready) 
            m_axi_awvalid <= 0;
        else if (state_current == AXI_WR_PRE)
            m_axi_awvalid <= 1; 
        else 
            m_axi_awvalid <= m_axi_awvalid;
    end

    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) begin
            m_axi_awlen  <= 0;
            m_axi_awaddr <= 0;
        end
        else if (cmd_rden) begin
            m_axi_awlen  <= cmd_dout[39:32];
            m_axi_awaddr <= cmd_dout[31:0] ;
        end
        else begin 
            m_axi_awlen  <= m_axi_awlen ;
            m_axi_awaddr <= m_axi_awaddr;    	
        end
    end
/*----------------------		combinatorial logic     ----------------------*/
    //AXI property
    assign m_axi_bready  = 1'b1;
    assign m_axi_awprot  = 0;
    assign m_axi_awid    = 0;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awlock  = 0;
    assign m_axi_awcache = 0;
    assign m_axi_awqos   = 0;
    assign m_axi_wstrb   = {AXI_DATA_WIDTH/8{1'b1}};
    assign m_axi_awsize  =  AXI_DATA_WIDTH == 512 ? 3'h6 :
                            AXI_DATA_WIDTH == 256 ? 3'h5 :
                            AXI_DATA_WIDTH == 128 ? 3'h4 :
                            AXI_DATA_WIDTH == 64  ? 3'h3 :
                            AXI_DATA_WIDTH == 32  ? 3'h2 : 3'h0;
/*----------------------		sequential logic		----------------------*/
    //reset CDC 
    always@(posedge i_clk)begin
        reset_ff0  <= i_reset;
        reset_ff1  <= reset_ff0;
        reset_sync <= reset_ff1;
    end
    //AXI reset CDC
    always@(posedge i_axi_clk)begin
        axi_reset_ff0  <= i_reset;
        axi_reset_ff1  <= axi_reset_ff0;
        axi_reset_sync <= axi_reset_ff1;
    end
    //command fifo wren ,rden
    assign cmd_rden = state_current == AXI_WR_PRE;
    always@(posedge i_clk)begin
        if(i_wr_buff_req_en)begin
            cmd_wren <= 1;
            cmd_din  <= {i_wr_buff_burst_len,i_wr_buff_addr};
        end
        else begin
            cmd_wren <= 0;
            cmd_din  <= 0;
        end
    end
    //fifo debug signal
    always @(posedge i_clk) begin
    if (reset_sync) 
        r_o_wr_data_fifo_err <= 0;
    else if (data_wrfull && data_wren)
        r_o_wr_data_fifo_err <= 1;
    else 
        r_o_wr_data_fifo_err <= r_o_wr_data_fifo_err;
    end

    always @(posedge i_clk) begin
        if (reset_sync) 
            r_o_wr_cmd_fifo_err <= 0;
        else if (cmd_wrfull && cmd_wren)
            r_o_wr_cmd_fifo_err <= 1;
        else 
            r_o_wr_cmd_fifo_err <= r_o_wr_cmd_fifo_err;
    end
/*----------------------		instantiate  			----------------------*/
    //cmd fifo
    fifo_w40xd16 wr_cmd_fifo (
        .rst           (reset_sync   ),
        .wr_clk        (i_clk        ),
        .rd_clk        (i_axi_clk    ),
        .din           (cmd_din      ),
        .wr_en         (cmd_wren     ),
        .rd_en         (cmd_rden     ),
        .dout          (cmd_dout     ),
        .full          (cmd_wrfull   ),
        .empty         (cmd_rdempty  ),
        .rd_data_count (cmd_rdcount  ),
        .wr_data_count (cmd_wrcount  )
    );

generate 
  if(AXI_DATA_WIDTH == 256)begin
    reg  [287:0] data_din;
    wire [287:0] data_dout;
    wire [9:0]   data_wrcount;
    wire [9:0]   data_rdcount;

    //data combination
    always@(posedge i_clk)begin
        data_din  <= {31'h0,i_wr_buff_data_last,i_wr_buff_data};
        data_wren <= i_wr_buff_vld;
    end

    always @(posedge i_axi_clk) begin 
        if (m_axi_wvalid && m_axi_wready && m_axi_wlast) 
            m_axi_wvalid <= 1'b0;
        else if (state_current == AXI_WR_PRE)
            m_axi_wvalid <= 1;
        else 
            m_axi_wvalid <= m_axi_wvalid; 
    end

    always @(*) begin
        if (data_rden) begin
            m_axi_wdata <= data_dout[255:0];
            m_axi_wlast <= data_dout[256];
        end
        else begin
            m_axi_wdata <= 0;
            m_axi_wlast <= 0;
        end 
    end

    always @(*) begin
        data_rden <= m_axi_wvalid && m_axi_wready && state_current == AXI_WR_DATA;
    end
    //data fifo
    fifo_w288xd512 wr_data_fifo (
        .rst           (reset_sync   ),
        .wr_clk        (i_clk        ),
        .rd_clk        (i_axi_clk    ),
        .din           (data_din     ),
        .wr_en         (data_wren    ),
        .rd_en         (data_rden    ),
        .dout          (data_dout    ),
        .full          (data_wrfull  ),
        .empty         (data_rdempty ),
        .rd_data_count (data_rdcount ),
        .wr_data_count (data_wrcount ) 
    );
  end 
  else if(AXI_DATA_WIDTH == 128)begin
    reg  [143:0]  data_din;
    wire [143:0]  data_dout;
    wire [10:0]   data_wrcount;
    wire [10:0]   data_rdcount;

    //data combination
    always@(posedge i_clk)begin
        data_din  <= {15'h0,i_wr_buff_data_last,i_wr_buff_data};
        data_wren <= i_wr_buff_vld;
    end

    always @(posedge i_axi_clk) begin 
        if (m_axi_wvalid && m_axi_wready && m_axi_wlast) 
            m_axi_wvalid <= 1'b0;
        else if (state_current == AXI_WR_PRE) 
            m_axi_wvalid <= 1;
        else 
            m_axi_wvalid <= m_axi_wvalid; 
    end

    always @(*) begin
        if (data_rden) begin
            m_axi_wdata <= data_dout[127:0];
            m_axi_wlast <= data_dout[128];
        end
        else begin
            m_axi_wdata <= 0;
            m_axi_wlast <= 0;
        end 
    end

    always @(*) begin
        data_rden <= m_axi_wvalid && m_axi_wready && state_current == AXI_WR_DATA;
    end
    //data fifo
    fifo_w144xd512 wr_data_fifo (
        .rst           (reset_sync   ),
        .wr_clk        (i_clk        ),
        .rd_clk        (i_axi_clk    ),
        .din           (data_din     ),
        .wr_en         (data_wren    ),
        .rd_en         (data_rden    ),
        .dout          (data_dout    ),
        .full          (data_wrfull  ),
        .empty         (data_rdempty ),
        .rd_data_count (data_rdcount ),
        .wr_data_count (data_wrcount ) 
    );
  end
  else if(AXI_DATA_WIDTH == 64)begin
    reg  [71:0]  data_din;
    wire [71:0]  data_dout;
    wire [11:0]  data_wrcount;
    wire [11:0]  data_rdcount;

    //data combination
    always@(posedge i_clk)begin
        data_din  <= {7'h0,i_wr_buff_data_last,i_wr_buff_data};
        data_wren <= i_wr_buff_vld;
    end

    always @(posedge i_axi_clk) begin 
        if (m_axi_wvalid && m_axi_wready && m_axi_wlast) 
            m_axi_wvalid <= 1'b0;
        else if (state_current == AXI_WR_PRE) 
            m_axi_wvalid <= 1;
        else 
            m_axi_wvalid <= m_axi_wvalid; 
    end

    always @(*) begin
        if (data_rden) begin
            m_axi_wdata <= data_dout[63:0];
            m_axi_wlast <= data_dout[64];
        end
        else begin
            m_axi_wdata <= 0;
            m_axi_wlast <= 0;
        end 
    end

    always @(*) begin
        data_rden <= m_axi_wvalid && m_axi_wready && state_current == AXI_WR_DATA;
    end
    //data fifo
    fifo_w72xd512 wr_data_fifo (
        .rst           (reset_sync   ),
        .wr_clk        (i_clk        ),
        .rd_clk        (i_axi_clk    ),
        .din           (data_din     ),
        .wr_en         (data_wren    ),
        .rd_en         (data_rden    ),
        .dout          (data_dout    ),
        .full          (data_wrfull  ),
        .empty         (data_rdempty ),
        .rd_data_count (data_rdcount ),
        .wr_data_count (data_wrcount ) 
    );
  end
endgenerate

endmodule
