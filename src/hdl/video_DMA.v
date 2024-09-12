
module video_DMA#(
    parameter VIDEO_WR_DATA_WIDTH   = 16    ,
    parameter VIDEO_RD_DATA_WIDTH   = 16    ,
    parameter AXI_DATA_WIDTH        = 128   ,
    parameter AXI_ADDR_WIDTH        = 32
    )(
    //system signal
    input                                   i_reset              ,
    //DDR initial signal
    input                                   i_ddr_init_done      ,
    //video data write signals(camera input)
    input   wire                            i_wr_video_clk       ,
    input   wire [15:0]                     i_wr_video_width     ,
    input   wire [15:0]                     i_wr_video_high      ,
    input   wire                            i_wr_video_field     ,
    input   wire                            i_wr_video_valid     ,
    input   wire [VIDEO_WR_DATA_WIDTH-1:0]  i_wr_video_data      ,
    input   wire [AXI_ADDR_WIDTH-1:0]       i_wr_video_base_addr ,
    //video data read signals(LCD output)
    input   wire                            i_rd_video_clk       ,
    input   wire [15:0]                     i_rd_video_width     ,
    input   wire [15:0]                     i_rd_video_high      ,
    input   wire                            i_rd_video_field     ,
    input   wire                            i_rd_video_valid     ,
    output  wire [VIDEO_WR_DATA_WIDTH-1:0]  o_rd_video_data      ,
    output  wire                            o_rd_video_line_last ,
    input   wire [AXI_ADDR_WIDTH-1:0]       i_rd_video_base_addr ,
    //1:Read image data in reverse order | 0:normal
    input   wire                            i_rd_video_frame_mode,
    //1:Read at the rising edge of the field | 0:Read at the falling edge of the field
    input   wire                            i_rd_video_trig_mode ,
    //AXI clock
    input   wire                            i_axi_clk            ,
    //AXI write channel signal
    output  wire                            m_axi_awvalid        ,
    input   wire                            m_axi_awready        ,
    output  wire [AXI_ADDR_WIDTH-1:0]       m_axi_awaddr         ,
    output  wire [3:0]                      m_axi_awid           ,
    output  wire [7:0]                      m_axi_awlen          ,
    output  wire [1:0]                      m_axi_awburst        ,
    output  wire [2:0]                      m_axi_awsize         ,
    output  wire [2:0]                      m_axi_awprot         ,
    output  wire [3:0]                      m_axi_awqos          ,
    output  wire                            m_axi_awlock         ,
    output  wire [3:0]                      m_axi_awcache        ,
    output  wire                            m_axi_wvalid         ,
    input   wire                            m_axi_wready         ,
    output  wire [AXI_DATA_WIDTH-1:0]       m_axi_wdata          ,
    output  wire [AXI_DATA_WIDTH/8-1:0]     m_axi_wstrb          ,
    output  wire                            m_axi_wlast  	     ,
    input   wire [3:0]                      m_axi_bid            ,
    input   wire [1:0]                      m_axi_bresp          ,
    input   wire                            m_axi_bvalid         ,
    output  wire                            m_axi_bready         ,
    //AXI read channel signal
    output  wire                            m_axi_arvalid        ,
    input   wire                            m_axi_arready        ,
    output  wire [AXI_ADDR_WIDTH-1:0]       m_axi_araddr         ,
    output  wire [3:0]                      m_axi_arid           ,
    output  wire [7:0]                      m_axi_arlen          ,
    output  wire [1:0]                      m_axi_arburst        ,
    output  wire [2:0]                      m_axi_arsize         ,
    output  wire [2:0]                      m_axi_arprot         ,
    output  wire [3:0]                      m_axi_arqos          ,
    output  wire                            m_axi_arlock         ,
    output  wire [3:0]                      m_axi_arcache        ,
    input   wire [3:0]                      m_axi_rid            ,
    input   wire                            m_axi_rvalid         ,
    output  wire                            m_axi_rready         ,
    input   wire [AXI_DATA_WIDTH-1:0]       m_axi_rdata          ,
    input   wire                            m_axi_rlast          ,
    input   wire [1:0]                      m_axi_rresp           
    );
/*----------------------		parameter       		----------------------*/

/*----------------------		internal reg signal		----------------------*/

/*----------------------		internal wire signal 	----------------------*/
    //debug signal
	wire   wr_cmd_fifo_err; 
	wire   wr_data_fifo_err;
	wire   rd_cmd_fifo_err;
	wire   rd_data_fifo_err;
	wire   rd_line_buf_err;
	wire   rd_line_buf_empty_err;
/*---------------------- 		output assign 			----------------------*/

/*----------------------		state machine			----------------------*/

/*----------------------		combinatorial logic     ----------------------*/

/*----------------------		sequential logic		----------------------*/

/*----------------------		instantiate  			----------------------*/
    video_wr_channel#(
        .VIDEO_WR_DATA_WIDTH(VIDEO_WR_DATA_WIDTH),
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH     ),
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH     )
    )video_wr_channel (
        .i_reset             (i_reset             ),
        .i_ddr_init_done     (i_ddr_init_done     ),
        .i_wr_video_clk      (i_wr_video_clk      ),
        .i_wr_video_width    (i_wr_video_width    ),
        .i_wr_video_high     (i_wr_video_high     ),
        .i_wr_video_field    (i_wr_video_field    ),
        .i_wr_video_valid    (i_wr_video_valid    ),
        .i_wr_video_data     (i_wr_video_data     ),
        .i_wr_video_base_addr(i_wr_video_base_addr),
        .i_axi_clk           (i_axi_clk           ),
        .m_axi_awvalid       (m_axi_awvalid       ),
        .m_axi_awready       (m_axi_awready       ),
        .m_axi_awaddr        (m_axi_awaddr        ),
        .m_axi_awid          (m_axi_awid          ),
        .m_axi_awlen         (m_axi_awlen         ),
        .m_axi_awburst       (m_axi_awburst       ),
        .m_axi_awsize        (m_axi_awsize        ),
        .m_axi_awprot        (m_axi_awprot        ),
        .m_axi_awqos         (m_axi_awqos         ),
        .m_axi_awlock        (m_axi_awlock        ),
        .m_axi_awcache       (m_axi_awcache       ),
        .m_axi_wvalid        (m_axi_wvalid        ),
        .m_axi_wready        (m_axi_wready        ),
        .m_axi_wdata         (m_axi_wdata         ),
        .m_axi_wstrb         (m_axi_wstrb         ),   	
        .m_axi_wlast  	     (m_axi_wlast  	      ),
        .m_axi_bid           (m_axi_bid           ),
        .m_axi_bresp         (m_axi_bresp         ),
        .m_axi_bvalid        (m_axi_bvalid        ),
        .m_axi_bready        (m_axi_bready        ), 
        .o_wr_cmd_fifo_err   (wr_cmd_fifo_err     ),
        .o_wr_data_fifo_err  (wr_data_fifo_err    )
    );

    video_rd_channel#(
        .VIDEO_RD_DATA_WIDTH(VIDEO_RD_DATA_WIDTH),
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH     ),
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH     )
    )video_rd_channel (
        .i_reset                 (i_reset                ),
        .i_ddr_init_done         (i_ddr_init_done        ),
        .i_rd_video_clk          (i_rd_video_clk         ),
        .i_rd_video_width        (i_rd_video_width       ),
        .i_rd_video_high         (i_rd_video_high        ),
        .i_rd_video_field        (i_rd_video_field       ),
        .i_rd_video_valid        (i_rd_video_valid       ),
        .o_rd_video_data         (o_rd_video_data        ),
        .o_rd_video_line_last    (o_rd_video_line_last   ),
        .i_rd_video_base_addr    (i_rd_video_base_addr   ),
        .i_rd_video_frame_mode   (i_rd_video_frame_mode  ),
        .i_rd_video_trig_mode    (i_rd_video_trig_mode   ),
        .i_axi_clk               (i_axi_clk              ),
        .m_axi_arvalid           (m_axi_arvalid          ),
        .m_axi_arready           (m_axi_arready          ),
        .m_axi_araddr            (m_axi_araddr           ),
        .m_axi_arid              (m_axi_arid             ),
        .m_axi_arlen             (m_axi_arlen            ),
        .m_axi_arburst           (m_axi_arburst          ),
        .m_axi_arsize            (m_axi_arsize           ),
        .m_axi_arprot            (m_axi_arprot           ),
        .m_axi_arqos             (m_axi_arqos            ),
        .m_axi_arlock            (m_axi_arlock           ),
        .m_axi_arcache           (m_axi_arcache          ),
        .m_axi_rid               (m_axi_rid              ),
        .m_axi_rvalid            (m_axi_rvalid           ),
        .m_axi_rready            (m_axi_rready           ),
        .m_axi_rdata             (m_axi_rdata            ),
        .m_axi_rlast             (m_axi_rlast            ),
        .m_axi_rresp             (m_axi_rresp            ),
        .o_rd_cmd_fifo_err       (rd_cmd_fifo_err        ),
        .o_rd_data_fifo_err      (rd_data_fifo_err       ),
        .o_rd_line_buf_err       (rd_line_buf_err        ),
        .o_rd_line_buf_empty_err (rd_line_buf_empty_err  )
    );
endmodule
