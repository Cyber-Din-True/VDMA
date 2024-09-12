
module video_rd_buffer#(
    parameter VIDEO_RD_DATA_WIDTH   = 16    ,
    parameter AXI_DATA_WIDTH        = 128   ,
    parameter AXI_ADDR_WIDTH        = 32
    )(
    //system signal
    input                                   i_clk                   ,
    input                                   i_reset                 ,
    //AXI clock
    input   wire                            i_axi_clk               ,
    //AXI read channel signal
    output  reg                             m_axi_arvalid           ,
    input                                   m_axi_arready           ,
    output  reg  [AXI_ADDR_WIDTH-1:0]       m_axi_araddr            ,
    output       [3:0]                      m_axi_arid              ,
    output  reg  [7:0]                      m_axi_arlen             ,
    output       [1:0]                      m_axi_arburst           ,
    output       [2:0]                      m_axi_arsize            ,
    output       [2:0]                      m_axi_arprot            ,
    output       [3:0]                      m_axi_arqos             ,
    output                                  m_axi_arlock            ,
    output       [3:0]                      m_axi_arcache           ,
    input        [3:0]                      m_axi_rid               ,
    input                                   m_axi_rvalid            ,
    output                                  m_axi_rready            ,
    input        [AXI_DATA_WIDTH-1:0]       m_axi_rdata             ,
    input                                   m_axi_rlast             ,
    input        [1:0]                      m_axi_rresp             ,
    //video_rd_ctrl interaction signal
    input   wire                            i_rd_buff_req_en        ,
    output  wire                            o_rd_buff_req_ready     ,
    input   wire [7:0]                      i_rd_buff_burst_len     ,
    input   wire [AXI_ADDR_WIDTH-1:0]       i_rd_buff_data_addr     ,
    input   wire                            i_rd_buff_line_rden     ,
    input   wire [15:0]                     i_video_width           ,
    //video data output
    output  wire [VIDEO_RD_DATA_WIDTH-1:0]  o_rd_video_data         ,
    output  wire                            o_rd_video_line_last,
    //debug fifo signal
    output  wire                            o_rd_cmd_fifo_err       ,
    output  wire                            o_rd_data_fifo_err      ,
    output  wire                            o_rd_line_buf_err       ,
    output  wire                            o_rd_line_buf_empty_err 
    );
/*----------------------		parameter       		----------------------*/
    localparam CNT_AXI2VIDEO_COMB_MAX = AXI_DATA_WIDTH/VIDEO_RD_DATA_WIDTH;
    localparam AXI_RD_IDLE = 4'b0001;
    localparam AXI_RD_PRE  = 4'b0010;
    localparam AXI_RD_DATA = 4'b0100;
    localparam AXI_RD_END  = 4'b1000;
/*----------------------		internal reg signal		----------------------*/
    //output register
    reg [VIDEO_RD_DATA_WIDTH-1:0]   r_o_rd_video_data         ;
    reg                             r_o_rd_video_line_last;
    reg                             r_o_rd_cmd_fifo_err       ;
    reg                             r_o_rd_data_fifo_err      ;
    reg                             r_o_rd_line_buf_err       ;
    reg                             r_o_rd_line_buf_empty_err ;
    //state machine
    reg [3:0] state_current,state_next;
    //delay
    (* dont_touch ="true" *) reg reset_ff0;
    (* dont_touch ="true" *) reg reset_ff1;
    (* dont_touch ="true" *) reg reset_sync;
    (* dont_touch ="true" *) reg axi_reset_ff0;
    (* dont_touch ="true" *) reg axi_reset_ff1;
    (* dont_touch ="true" *) reg axi_reset_sync;
    //counter
    reg [15:0]                                  cnt_pixel;
    reg	[$clog2(CNT_AXI2VIDEO_COMB_MAX)-1:0]	cnt_decomb  ;
    //command fifo control signal
    reg				cmd_wren;
    reg	 [39:0]		cmd_din;
    //data fifo control signal
    reg				data_wren;
    reg				data_rden;
    //line fifo control signal
    reg				line_buff_wren;
    //other 
    reg								rd_data_flag     ;
    reg [AXI_DATA_WIDTH-1:0]        rd_data_fifo_out ;
    reg                             rd_data_fifo_last;
    reg						        video_line_valid ;
    reg                             video_line_last  ;
    reg [VIDEO_RD_DATA_WIDTH-1:0]   video_line_data  ;
/*----------------------		internal wire signal 	----------------------*/
    //command fifo control signal
    wire [39:0]	 cmd_dout;
    wire		 cmd_rden;
    wire		 cmd_wrfull;
    wire		 cmd_rdempty;
    wire [4:0]	 cmd_wrcount;
    wire [4:0]	 cmd_rdcount;
    //data fifo control signal
    wire  data_wrfull;
    wire  data_rdempty;
    //line fifo control signal
    wire  line_buff_rden;
    wire  line_buff_wrfull;
    wire  line_buff_rdempty;
    //other
    wire  rd_data_buff_ready;
    wire  rd_line_buff_ready;
    wire  rd_line_buff_mask ;
    wire  rd_line_buff_wlast;
/*---------------------- 		output assign 			----------------------*/
    assign o_rd_video_data          = r_o_rd_video_data         ;
    assign o_rd_video_line_last = r_o_rd_video_line_last;
    assign o_rd_cmd_fifo_err        = r_o_rd_cmd_fifo_err       ;
    assign o_rd_data_fifo_err       = r_o_rd_data_fifo_err      ;
    assign o_rd_line_buf_err        = r_o_rd_line_buf_err       ;
    assign o_rd_line_buf_empty_err  = r_o_rd_line_buf_empty_err ;
/*----------------------		state machine			----------------------*/
    always@(posedge i_axi_clk)begin
        if(axi_reset_sync)
            state_current <= AXI_RD_IDLE;
        else
            state_current <= state_next;
    end

    always@(*)begin
        case(state_current)
            AXI_RD_IDLE : begin
                if (~cmd_rdempty && rd_data_buff_ready)
                    state_next = AXI_RD_PRE;
                else 
                    state_next = state_current; end
            AXI_RD_PRE : begin
                state_next = AXI_RD_DATA; end
            AXI_RD_DATA : begin
                if (m_axi_rvalid && m_axi_rlast && m_axi_rready)
                    state_next = AXI_RD_END;
                else 
                    state_next = state_current; end
            AXI_RD_END : begin
                state_next = AXI_RD_IDLE; end
            default : state_next = AXI_RD_IDLE; 
        endcase
    end
    //m_axi_arvalid
    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) 
            m_axi_arvalid <= 0;
        else if (m_axi_arvalid && m_axi_arready)
            m_axi_arvalid <= 0;
        else if (state_current == AXI_RD_PRE)
            m_axi_arvalid <= 1;
        else 
            m_axi_arvalid <= m_axi_arvalid;
    end
    //m_axi_arlen m_axi_araddr
    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) begin
            m_axi_arlen  <= 0;
            m_axi_araddr <= 0;
        end
        else if (cmd_rden) begin
            m_axi_arlen  <= cmd_dout[39:32];
            m_axi_araddr <= cmd_dout[31:0] ;
        end
        else begin 
            m_axi_arlen  <= m_axi_arlen ;
            m_axi_araddr <= m_axi_araddr;
        end
    end

/*----------------------	 	combinatorial logic     ----------------------*/
    assign o_rd_buff_req_ready = reset_sync ? 0 : cmd_wrcount < 'd12; //cmd fifo not full
    assign rd_line_buff_mask   = axi_reset_sync ? 1'b0 : video_line_valid & cnt_pixel >= i_video_width;
    assign rd_line_buff_wlast  = axi_reset_sync ? 1'b0 : video_line_valid & cnt_pixel == i_video_width - 1;
    //line fifo read en
    assign line_buff_rden      = i_rd_buff_line_rden;
    //AXI property
    assign m_axi_rready  = 1'b1;
    assign m_axi_arprot  = 0;
    assign m_axi_arid    = 0;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arlock  = 0;
    assign m_axi_arcache = 0;
    assign m_axi_arqos   = 0;
    assign m_axi_arsize  =  AXI_DATA_WIDTH == 512 ? 3'h6 :
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
    //cmd fifo write en
    always @(posedge i_clk) begin
        if (i_rd_buff_req_en && o_rd_buff_req_ready) begin
            cmd_wren <= 1'b1;
            cmd_din  <= {i_rd_buff_burst_len,i_rd_buff_data_addr};
        end
        else begin
            cmd_wren <= 0;
            cmd_din  <= cmd_din;
        end 
    end
    //cmd fifo read en
    assign cmd_rden = state_current == AXI_RD_PRE;
    //data read en
    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) 
            data_rden <= 0;
        else if (data_rden) 
            data_rden <= 0;
        else if (~data_rdempty && ~rd_data_flag && rd_line_buff_ready)
            data_rden <= 1'b1;
        else 
            data_rden <= data_rden;
    end

    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) 
            rd_data_flag <= 0;
        else if (cnt_decomb == CNT_AXI2VIDEO_COMB_MAX-1 && rd_data_flag) 
            rd_data_flag <= 0;
        else if (data_rden)
            rd_data_flag <= 1'b1;
        else 
            rd_data_flag <= rd_data_flag;
            
    end
    //video_line_data video_line_valid
    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) begin
            video_line_data  <= 0;
            video_line_valid <= 0;
        end
        else if (rd_data_flag) begin
            video_line_data  <= rd_data_fifo_out[VIDEO_RD_DATA_WIDTH-1:0];
            video_line_valid <= 1'b1;
        end    
        else begin
            video_line_data  <= 0;
            video_line_valid <= 0;
        end
    end
    //video_line_last
    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) 
            video_line_last <= 0;
        else if (cnt_decomb == CNT_AXI2VIDEO_COMB_MAX-1 && rd_data_fifo_last) 
            video_line_last <= 1;
        else 
            video_line_last <= 0;
    end
    //pixel counter
    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) 
            cnt_pixel <= 0;
        else if (video_line_last && video_line_valid)
            cnt_pixel <= 0;
        else if (video_line_valid) 
            cnt_pixel <= cnt_pixel + 1;
        else 
            cnt_pixel <= cnt_pixel;
    end
    //cnt_decomb
    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) 
            cnt_decomb <= 0;
        else if (rd_data_flag && cnt_decomb == CNT_AXI2VIDEO_COMB_MAX-1)
            cnt_decomb <= 0;
        else if (rd_data_flag)
            cnt_decomb <= cnt_decomb + 1;
        else 
            cnt_decomb <= cnt_decomb; 
    end
    //debug signal
    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) 
            r_o_rd_data_fifo_err <= 0;
        else if (data_wrfull && data_wren) 
            r_o_rd_data_fifo_err <= 1;
        else 
            r_o_rd_data_fifo_err <= r_o_rd_data_fifo_err;
    end

    always @(posedge i_clk) begin
        if (reset_sync) 
            r_o_rd_cmd_fifo_err <= 0;
        else if (cmd_wrfull && cmd_wren) 
            r_o_rd_cmd_fifo_err <= 1;
        else 
            r_o_rd_cmd_fifo_err <= r_o_rd_cmd_fifo_err;
    end

    always @(posedge i_axi_clk) begin
        if (axi_reset_sync) 
            r_o_rd_line_buf_err <= 0;
        else if (line_buff_wrfull && line_buff_wren) 
            r_o_rd_line_buf_err <= 1;
        else 
            r_o_rd_line_buf_err <= r_o_rd_line_buf_err;
    end

    always @(posedge i_clk) begin
        if (reset_sync) 
            r_o_rd_line_buf_empty_err <= 0;
        else if (line_buff_rden && line_buff_rdempty) 
            r_o_rd_line_buf_empty_err <= 1;
        else 
            r_o_rd_line_buf_empty_err <= r_o_rd_line_buf_empty_err; 
    end
/*----------------------		instantiate  			----------------------*/
    //cmd fifo
    fifo_w40xd16 rd_cmd_fifo (
        .rst          (reset_sync   ),
        .wr_clk       (i_clk        ),
        .rd_clk       (i_axi_clk    ),
        .din          (cmd_din      ),
        .wr_en        (cmd_wren     ),
        .rd_en        (cmd_rden     ),
        .dout         (cmd_dout     ),
        .full         (cmd_wrfull   ),
        .empty        (cmd_rdempty  ),
        .rd_data_count(cmd_rdcount  ),
        .wr_data_count(cmd_wrcount  )
    );
//////////////////////// different AXI data width ////////////////////////
generate
  if(AXI_DATA_WIDTH == 256)begin
    reg  [287:0] data_din;
    wire [287:0] data_dout;
    wire [9:0]   data_wrcount;
    wire [9:0]   data_rdcount;

    always @(posedge i_axi_clk) begin
        data_wren <= m_axi_rvalid;
        data_din  <= {31'h0,m_axi_rlast,m_axi_rdata};
    end
    
    always @(posedge i_axi_clk) begin
        if (data_rden) 
            rd_data_fifo_out <= data_dout[255:0];
        else if (rd_data_flag) 
            rd_data_fifo_out <= rd_data_fifo_out >> VIDEO_RD_DATA_WIDTH;
        else 
            rd_data_fifo_out <= rd_data_fifo_out;
    end
    
    always @(posedge i_axi_clk) begin
        if (rd_data_flag && cnt_decomb == CNT_AXI2VIDEO_COMB_MAX-1) 
            rd_data_fifo_last <= 0;
        else if (data_rden && data_dout[256]) 
            rd_data_fifo_last <= 1;
        else 
            rd_data_fifo_last <= rd_data_fifo_last;
    end

    assign rd_data_buff_ready = axi_reset_sync ? 0 :data_wrcount <= 'd384;

    //data fifo
    fifo_w288xd512 rd_data_fifo (
        .rst           (axi_reset_sync ),
        .wr_clk        (i_axi_clk      ),
        .rd_clk        (i_axi_clk      ),
        .din           (data_din       ),
        .wr_en         (data_wren      ),
        .rd_en         (data_rden      ),
        .dout          (data_dout      ),
        .full          (data_wrfull    ),
        .empty         (data_rdempty   ),
        .rd_data_count (data_rdcount   ),
        .wr_data_count (data_wrcount   )
    );
  end else if (AXI_DATA_WIDTH == 128) begin
    reg  [143:0] data_din;
    wire [143:0] data_dout;
    wire [10:0]  data_wrcount;
    wire [10:0]  data_rdcount;

    always @(posedge i_axi_clk) begin
        data_wren <= m_axi_rvalid;
        data_din  <= {15'h0,m_axi_rlast,m_axi_rdata};
    end
    
    always @(posedge i_axi_clk) begin
        if (data_rden) 
            rd_data_fifo_out <= data_dout[127:0];
        else if (rd_data_flag) 
            rd_data_fifo_out <= rd_data_fifo_out >> VIDEO_RD_DATA_WIDTH;
        else 
            rd_data_fifo_out <= rd_data_fifo_out;
    end
    
    always @(posedge i_axi_clk) begin
        if (rd_data_flag && cnt_decomb == CNT_AXI2VIDEO_COMB_MAX-1) 
            rd_data_fifo_last <= 0;
        else if (data_rden && data_dout[128]) 
            rd_data_fifo_last <= 1;
        else 
            rd_data_fifo_last <= rd_data_fifo_last;
    end

    assign rd_data_buff_ready = axi_reset_sync ? 0 :data_wrcount <= 'd256;

    //data fifo
    fifo_w144xd512 rd_data_fifo (
        .rst           (axi_reset_sync ),
        .wr_clk        (i_axi_clk      ),
        .rd_clk        (i_axi_clk      ),
        .din           (data_din       ),
        .wr_en         (data_wren      ),
        .rd_en         (data_rden      ),
        .dout          (data_dout      ),
        .full          (data_wrfull    ),
        .empty         (data_rdempty   ),
        .rd_data_count (data_rdcount   ),
        .wr_data_count (data_wrcount   )
    );

end else if (AXI_DATA_WIDTH == 64) begin
    reg  [71:0] data_din;
    wire [71:0] data_dout;
    wire [9:0]   data_wrcount;
    wire [9:0]   data_rdcount;

    always @(posedge i_axi_clk) begin
        data_wren <= m_axi_rvalid;
        data_din  <= {7'h0,m_axi_rlast,m_axi_rdata};
    end
    
    always @(posedge i_axi_clk) begin
        if (data_rden) 
            rd_data_fifo_out <= data_dout[63:0];
        else if (rd_data_flag) 
            rd_data_fifo_out <= rd_data_fifo_out >> VIDEO_RD_DATA_WIDTH;
        else 
            rd_data_fifo_out <= rd_data_fifo_out;
    end
    
    always @(posedge i_axi_clk) begin
        if (rd_data_flag && cnt_decomb == CNT_AXI2VIDEO_COMB_MAX-1) 
            rd_data_fifo_last <= 0;
        else if (data_rden && data_dout[64]) 
            rd_data_fifo_last <= 1;
        else 
            rd_data_fifo_last <= rd_data_fifo_last;
    end

    assign rd_data_buff_ready = axi_reset_sync ? 0 :data_wrcount <= 'd256;

    //data fifo
    fifo_w72xd512 rd_data_fifo (
        .rst           (axi_reset_sync ),
        .wr_clk        (i_axi_clk      ),
        .rd_clk        (i_axi_clk      ),
        .din           (data_din       ),
        .wr_en         (data_wren      ),
        .rd_en         (data_rden      ),
        .dout          (data_dout      ),
        .full          (data_wrfull    ),
        .empty         (data_rdempty   ),
        .rd_data_count (data_rdcount   ),
        .wr_data_count (data_wrcount   )
    );
end
endgenerate
//////////////////////// different AXI data width ////////////////////////
generate
  if(VIDEO_RD_DATA_WIDTH == 32)begin
        reg  [35:0]   	line_buff_din;
		wire [35:0]		line_buff_dout;
		wire [ 9:0]     line_buff_wrcount;
		wire [ 9:0]     line_buff_rdcount;

    always @(posedge i_axi_clk) begin
        line_buff_din  <= {3'h0,rd_line_buff_wlast,video_line_data};
        line_buff_wren <= video_line_valid & ~rd_line_buff_mask; 
    end

    always @(posedge i_clk) begin
        if (line_buff_rden) begin
            r_o_rd_video_data      <= line_buff_dout[31:0];
            r_o_rd_video_line_last <= line_buff_dout[32];
        end
        else begin
            r_o_rd_video_data          <= 0;
            r_o_rd_video_line_last <= 0;
        end
    end

    assign rd_line_buff_ready = line_buff_wrcount <= 10'd448; 
    //video data fifo
    fifo_w36xd512 rd_line_buff_fifo (
        .rst          (axi_reset_sync    ),
        .wr_clk       (i_axi_clk         ),
        .rd_clk       (i_clk             ),
        .din          (line_buff_din     ),
        .wr_en        (line_buff_wren    ),
        .rd_en        (line_buff_rden    ),
        .dout         (line_buff_dout    ),
        .full         (line_buff_wrfull  ),
        .empty        (line_buff_rdempty ),
        .rd_data_count(line_buff_rdcount ),
        .wr_data_count(line_buff_wrcount )
    );
  end else if(VIDEO_RD_DATA_WIDTH == 16)begin
    reg  [17:0]   	line_buff_din;
    wire [17:0]		line_buff_dout;
    wire [10:0]     line_buff_wrcount;
    wire [10:0]     line_buff_rdcount;

    always @(posedge i_axi_clk) begin
        line_buff_din  <= {1'h0,rd_line_buff_wlast,video_line_data};
        line_buff_wren <= video_line_valid & ~rd_line_buff_mask; 
    end

    always @(posedge i_clk) begin
        if (line_buff_rden) begin
            r_o_rd_video_data      <= line_buff_dout[15:0];
            r_o_rd_video_line_last <= line_buff_dout[16];
        end
        else begin
            r_o_rd_video_data      <= 0;
            r_o_rd_video_line_last <= 0;
        end
    end

    assign rd_line_buff_ready = line_buff_wrcount <= 11'd896; 
    //video data fifo
    fifo_w18xd1024 rd_line_buff_fifo (
        .rst          (axi_reset_sync    ),
        .wr_clk       (i_axi_clk         ),
        .rd_clk       (i_clk             ),
        .din          (line_buff_din     ),
        .wr_en        (line_buff_wren    ),
        .rd_en        (line_buff_rden    ),
        .dout         (line_buff_dout    ),
        .full         (line_buff_wrfull  ),
        .empty        (line_buff_rdempty ),
        .rd_data_count(line_buff_rdcount ),
        .wr_data_count(line_buff_wrcount )
    );
  end else if(VIDEO_RD_DATA_WIDTH == 8)begin
    reg  [8:0]   	line_buff_din;
    wire [8:0]		line_buff_dout;
    wire [11:0]     line_buff_wrcount;
    wire [11:0]     line_buff_rdcount;

    always @(posedge i_axi_clk) begin
        line_buff_din  <= {1'h0,rd_line_buff_wlast,video_line_data};
        line_buff_wren <= video_line_valid & ~rd_line_buff_mask; 
    end

    always @(posedge i_clk) begin
        if (line_buff_rden) begin
            r_o_rd_video_data      <= line_buff_dout[7:0];
            r_o_rd_video_line_last <= line_buff_dout[8];
        end
        else begin
            r_o_rd_video_data      <= 0;
            r_o_rd_video_line_last <= 0;
        end
    end

    assign rd_line_buff_ready = line_buff_wrcount <= 11'd1792;
    //video data fifo
    fifo_w9xd2048 rd_line_buff_fifo (
        .rst          (axi_reset_sync    ),
        .wr_clk       (i_axi_clk         ),
        .rd_clk       (i_clk             ),
        .din          (line_buff_din     ),
        .wr_en        (line_buff_wren    ),
        .rd_en        (line_buff_rden    ),
        .dout         (line_buff_dout    ),
        .full         (line_buff_wrfull  ),
        .empty        (line_buff_rdempty ),
        .rd_data_count(line_buff_rdcount ),
        .wr_data_count(line_buff_wrcount )
    );
  end

endgenerate

endmodule
