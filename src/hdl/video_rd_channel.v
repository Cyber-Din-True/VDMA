
module video_rd_channel#(
    parameter VIDEO_RD_DATA_WIDTH   = 16    ,
    parameter AXI_DATA_WIDTH        = 128   ,
    parameter AXI_ADDR_WIDTH        = 32
    )(
    //system signal
    input                                   i_reset              ,
    //DDR initial signal
    input                                   i_ddr_init_done      ,
    //video data read signals(LCD output)
    input   wire                            i_rd_video_clk       ,
    input   wire [15:0]                     i_rd_video_width     ,
    input   wire [15:0]                     i_rd_video_high      ,
    input   wire                            i_rd_video_field     ,
    input   wire                            i_rd_video_valid     ,
    output  wire [VIDEO_RD_DATA_WIDTH-1:0]  o_rd_video_data      ,
    output  wire                            o_rd_video_line_last ,
    input   wire [AXI_ADDR_WIDTH-1:0]       i_rd_video_base_addr ,
    //1:Read image data in reverse order | 0:normal
    input   wire                            i_rd_video_frame_mode,
    //1:Read at the rising edge of the field | 0:Read at the falling edge of the field
    input   wire                            i_rd_video_trig_mode ,
    //AXI clock
    input   wire                            i_axi_clk            ,
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
    input   wire [1:0]                      m_axi_rresp          ,
    //debug fifo signal
    output  wire                            o_rd_cmd_fifo_err    ,
    output  wire                            o_rd_data_fifo_err   ,
    output  wire                            o_rd_line_buf_err    ,
    output  wire                            o_rd_line_buf_empty_err
    );
    wire                      rd_buff_req_en     ;
    wire                      rd_buff_req_ready  ;
    wire [7:0]                rd_buff_burst_len  ;
    wire [AXI_ADDR_WIDTH-1:0] rd_buff_data_addr  ;
    wire                      rd_buff_frame_reset;
    wire                      rd_buff_line_rden  ;
    wire [15:0]               video_width        ;

    video_rd_ctrl#(
        .VIDEO_RD_DATA_WIDTH(VIDEO_RD_DATA_WIDTH),
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH     ),
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH     )
    )video_rd_ctrl (
        .i_clk                 (i_rd_video_clk       ),
        .i_reset               (i_reset              ),
        .i_ddr_init_done       (i_ddr_init_done      ),
        .i_rd_video_width      (i_rd_video_width     ),
        .i_rd_video_high       (i_rd_video_high      ),
        .i_rd_video_field      (i_rd_video_field     ),
        .i_rd_video_valid      (i_rd_video_valid     ),
        .i_rd_video_base_addr  (i_rd_video_base_addr ),
        .i_rd_video_frame_mode (i_rd_video_frame_mode),
        .i_rd_video_trig_mode  (i_rd_video_trig_mode ),
        .o_rd_buff_req_en      (rd_buff_req_en       ),
        .i_rd_buff_req_ready   (rd_buff_req_ready    ),
        .o_rd_buff_burst_len   (rd_buff_burst_len    ),
        .o_rd_buff_data_addr   (rd_buff_data_addr    ),
        .o_rd_buff_frame_reset (rd_buff_frame_reset  ),
        .o_rd_buff_line_rden   (rd_buff_line_rden    ),
        .o_video_width         (video_width          )
    );

    video_rd_buffer#(
        .VIDEO_RD_DATA_WIDTH(VIDEO_RD_DATA_WIDTH),
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH     ),
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH     )
    )video_rd_buffer (
        .i_clk                    (i_rd_video_clk          ),
        .i_reset                  (i_reset|rd_buff_frame_reset),
        .i_axi_clk                (i_axi_clk               ),
        .m_axi_arvalid            (m_axi_arvalid           ),
        .m_axi_arready            (m_axi_arready           ),
        .m_axi_araddr             (m_axi_araddr            ),
        .m_axi_arid               (m_axi_arid              ),
        .m_axi_arlen              (m_axi_arlen             ),
        .m_axi_arburst            (m_axi_arburst           ),
        .m_axi_arsize             (m_axi_arsize            ),
        .m_axi_arprot             (m_axi_arprot            ),
        .m_axi_arqos              (m_axi_arqos             ),
        .m_axi_arlock             (m_axi_arlock            ),
        .m_axi_arcache            (m_axi_arcache           ),
        .m_axi_rid                (m_axi_rid               ),
        .m_axi_rvalid             (m_axi_rvalid            ),
        .m_axi_rready             (m_axi_rready            ),
        .m_axi_rdata              (m_axi_rdata             ),
        .m_axi_rlast              (m_axi_rlast             ),
        .m_axi_rresp              (m_axi_rresp             ),
        .i_rd_buff_req_en         (rd_buff_req_en          ),
        .o_rd_buff_req_ready      (rd_buff_req_ready       ),
        .i_rd_buff_burst_len      (rd_buff_burst_len       ),
        .i_rd_buff_data_addr      (rd_buff_data_addr       ),
        .i_rd_buff_line_rden      (rd_buff_line_rden       ),
        .i_video_width            (video_width             ),
        .o_rd_video_data          (o_rd_video_data         ),
        .o_rd_video_line_last     (o_rd_video_line_last    ),
        .o_rd_cmd_fifo_err        (o_rd_cmd_fifo_err       ),
        .o_rd_data_fifo_err       (o_rd_data_fifo_err      ),
        .o_rd_line_buf_err        (o_rd_line_buf_err       ),
        .o_rd_line_buf_empty_err  (o_rd_line_buf_empty_err )
    );
endmodule
