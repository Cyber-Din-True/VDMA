
module video_wr_channel#(
    parameter VIDEO_WR_DATA_WIDTH   = 16    ,
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
    //debug fifo signal
    output  wire                            o_wr_cmd_fifo_err    ,
    output  wire                            o_wr_data_fifo_err
    );

    wire                            wr_buff_req_en     ;
    wire                            wr_buff_vld        ;
    wire [7:0]                      wr_buff_burst_len  ;
    wire [AXI_ADDR_WIDTH-1:0]       wr_buff_addr       ;
    wire [AXI_DATA_WIDTH-1:0]       wr_buff_data       ;
    wire                            wr_buff_data_last  ;
    wire                            wr_buff_frame_reset;

    video_wr_ctrl#(
        .VIDEO_WR_DATA_WIDTH(VIDEO_WR_DATA_WIDTH),
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH     ),
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH     )
    )video_wr_ctrl (
        .i_clk                (i_wr_video_clk       ),
        .i_reset              (i_reset              ),
        .i_ddr_init_done      (i_ddr_init_done      ),
        .i_wr_video_width     (i_wr_video_width     ),
        .i_wr_video_high      (i_wr_video_high      ),
        .i_wr_video_field     (i_wr_video_field     ),
        .i_wr_video_valid     (i_wr_video_valid     ),
        .i_wr_video_data      (i_wr_video_data      ),
        .i_wr_video_base_addr (i_wr_video_base_addr ),
        .o_wr_buff_req_en     (wr_buff_req_en       ),
        .o_wr_buff_vld        (wr_buff_vld          ),
        .o_wr_buff_burst_len  (wr_buff_burst_len    ),
        .o_wr_buff_addr       (wr_buff_addr         ),
        .o_wr_buff_data       (wr_buff_data         ),
        .o_wr_buff_data_last  (wr_buff_data_last    ),
        .o_wr_buff_frame_reset(wr_buff_frame_reset  )
    );

    video_wr_buffer#(
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH     ),
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH     )
    )video_wr_buffer (
        .i_clk                (i_wr_video_clk     ),
        .i_reset              (i_reset | wr_buff_frame_reset),
        .i_axi_clk            (i_axi_clk          ),
        .m_axi_awvalid        (m_axi_awvalid      ),
        .m_axi_awready        (m_axi_awready      ),
        .m_axi_awaddr         (m_axi_awaddr       ),
        .m_axi_awid           (m_axi_awid         ),
        .m_axi_awlen          (m_axi_awlen        ),
        .m_axi_awburst        (m_axi_awburst      ),
        .m_axi_awsize         (m_axi_awsize       ),
        .m_axi_awprot         (m_axi_awprot       ),
        .m_axi_awqos          (m_axi_awqos        ),
        .m_axi_awlock         (m_axi_awlock       ),
        .m_axi_awcache        (m_axi_awcache      ),
        .m_axi_wvalid         (m_axi_wvalid       ),
        .m_axi_wready         (m_axi_wready       ),
        .m_axi_wdata          (m_axi_wdata        ),
        .m_axi_wstrb          (m_axi_wstrb        ),
        .m_axi_wlast  	      (m_axi_wlast        ),  
        .m_axi_bid            (m_axi_bid          ),
        .m_axi_bresp          (m_axi_bresp        ),
        .m_axi_bvalid         (m_axi_bvalid       ),
        .m_axi_bready         (m_axi_bready       ),
        .i_wr_buff_req_en     (wr_buff_req_en     ),
        .i_wr_buff_vld        (wr_buff_vld        ),
        .i_wr_buff_burst_len  (wr_buff_burst_len  ),
        .i_wr_buff_addr       (wr_buff_addr       ),
        .i_wr_buff_data       (wr_buff_data       ),
        .i_wr_buff_data_last  (wr_buff_data_last  ),
        .o_wr_cmd_fifo_err    (o_wr_cmd_fifo_err  ),
        .o_wr_data_fifo_err   (o_wr_data_fifo_err )
    );

endmodule
