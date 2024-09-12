
module video_wr_ctrl#(
    parameter VIDEO_WR_DATA_WIDTH   = 16    ,
    parameter AXI_DATA_WIDTH        = 128   ,
    parameter AXI_ADDR_WIDTH        = 32
    )(
    //system signal
    input                                   i_clk                 ,
    input                                   i_reset               ,
    //DDR initial signal
    input                                   i_ddr_init_done       ,
    //video data write signals(camera input)
    input   wire [15:0]                     i_wr_video_width      ,
    input   wire [15:0]                     i_wr_video_high       ,
    input   wire                            i_wr_video_field      ,
    input   wire                            i_wr_video_valid      ,
    input   wire [VIDEO_WR_DATA_WIDTH-1:0]  i_wr_video_data       ,
    input   wire [AXI_ADDR_WIDTH-1:0]       i_wr_video_base_addr  ,
    //video_wr_buffer interaction signal 
    output  wire                            o_wr_buff_req_en      ,
    output  wire                            o_wr_buff_vld         ,
    output  wire [7:0]                      o_wr_buff_burst_len   ,
    output  wire [AXI_ADDR_WIDTH-1:0]       o_wr_buff_addr        ,
    output  wire [AXI_DATA_WIDTH-1:0]       o_wr_buff_data        ,
    output  wire                            o_wr_buff_data_last   ,
    output  wire                            o_wr_buff_frame_reset
    );
/*----------------------		parameter       		----------------------*/
    localparam CNT_VIDEO2AXI_COMB_MAX = AXI_DATA_WIDTH/VIDEO_WR_DATA_WIDTH;
/*----------------------		internal reg signal		----------------------*/
    //output register
    reg                         r_o_wr_buff_req_en     ;
    reg                         r_o_wr_buff_vld        ;
    reg [7:0]                   r_o_wr_buff_burst_len  ;
    reg [AXI_ADDR_WIDTH-1:0]    r_o_wr_buff_addr       ;
    reg [AXI_DATA_WIDTH-1:0]    r_o_wr_buff_data       ;
    reg                         r_o_wr_buff_data_last  ;
    reg                         r_o_wr_buff_frame_reset;
    //delay
    (* dont_touch ="true" *) reg reset_ff0;
    (* dont_touch ="true" *) reg reset_ff1;
    (* dont_touch ="true" *) reg reset_sync;
    reg ddr_init_done_ff0,ddr_init_done_ff1;
    reg i_wr_video_field_ff0;
    reg i_wr_video_valid_ff0;
    reg [VIDEO_WR_DATA_WIDTH-1:0] i_wr_video_data_ff0;
    //DDR write enable
    reg ddr_wr_en;
    //register control signal
    reg [AXI_ADDR_WIDTH-1:0] r_i_w_video_base_addr;
    reg [15:0] r_i_w_video_width;
    //counter
    reg [15:0] cnt_pixel;
    reg [$clog2(CNT_VIDEO2AXI_COMB_MAX)-1:0] cnt_comb;
    reg [7:0]   cnt_wr_burst;
    reg [4:0]   cnt_frame_reset_sync;
/*----------------------		internal wire signal 	----------------------*/
    wire wr_video_field_rise,wr_video_field_fall;
    wire line_last;
/*---------------------- 		output assign 			----------------------*/
    assign o_wr_buff_req_en      = r_o_wr_buff_req_en     ;
    assign o_wr_buff_vld         = r_o_wr_buff_vld        ;
    assign o_wr_buff_burst_len   = r_o_wr_buff_burst_len  ;
    assign o_wr_buff_addr        = r_o_wr_buff_addr       ;
    assign o_wr_buff_data        = r_o_wr_buff_data       ;
    assign o_wr_buff_frame_reset = r_o_wr_buff_frame_reset;
    assign o_wr_buff_data_last   = r_o_wr_buff_data_last  ;
/*----------------------		state machine			----------------------*/

/*----------------------		combinatorial logic     ----------------------*/
    assign wr_video_field_rise = ddr_wr_en ? i_wr_video_field && ~i_wr_video_field_ff0 : 0;
    assign wr_video_field_fall = ddr_wr_en ? ~i_wr_video_field && i_wr_video_field_ff0 : 0;
    assign line_last = i_wr_video_field_ff0 & i_wr_video_valid_ff0 && (cnt_pixel == r_i_w_video_width-1);
/*----------------------		sequential logic		----------------------*/
    //reset CDC 
    always@(posedge i_clk)begin
        reset_ff0  <= i_reset;
        reset_ff1  <= reset_ff0;
        reset_sync <= reset_ff1;
    end
    //wr_frame_reset CDC
    always@(posedge i_clk)begin
        if(reset_sync)
            cnt_frame_reset_sync <= 0;
        else if(cnt_frame_reset_sync == 12)
            cnt_frame_reset_sync <= 0;
        else if(wr_video_field_rise || cnt_frame_reset_sync)
            cnt_frame_reset_sync <= cnt_frame_reset_sync + 1;
        else
            cnt_frame_reset_sync <= cnt_frame_reset_sync;
    end

    always@(posedge i_clk)begin
        if(reset_sync)
            r_o_wr_buff_frame_reset <= 1;
        else
            r_o_wr_buff_frame_reset <= cnt_frame_reset_sync != 0;
    end
    //async ddr_init_done
    always@(posedge i_clk)begin
        ddr_init_done_ff0 <= i_ddr_init_done;
        ddr_init_done_ff1 <= ddr_init_done_ff0;
    end

    always@(posedge i_clk)begin
        if(reset_sync)
            ddr_wr_en <= 0;
        else if(~i_wr_video_field)
            ddr_wr_en <= ddr_init_done_ff1;
        else
            ddr_wr_en <= ddr_wr_en;
    end
    //field,valid delay
    always@(posedge i_clk)begin
        if(ddr_wr_en)begin
            i_wr_video_field_ff0 <= i_wr_video_field;
            i_wr_video_valid_ff0 <= i_wr_video_valid;
            i_wr_video_data_ff0  <= i_wr_video_data;
        end
        else begin
            i_wr_video_field_ff0 <= 0;
            i_wr_video_valid_ff0 <= 0;
            i_wr_video_data_ff0  <= 0;
        end
    end
    //locked image base addr and width 
    always@(posedge i_clk)begin
        if(wr_video_field_rise)begin
            r_i_w_video_base_addr <= i_wr_video_base_addr;
            r_i_w_video_width     <= i_wr_video_width >= 16'h1000 ? 16'h1000 : i_wr_video_width;
        end
        else begin
            r_i_w_video_base_addr <= r_i_w_video_base_addr;
            r_i_w_video_width     <= r_i_w_video_width    ;
        end
    end
    //pixel counter
    always@(posedge i_clk)begin
        if(reset_sync)
            cnt_pixel <= 0;
        else if(~i_wr_video_field_ff0 || line_last)
            cnt_pixel <= 0;
        else if(i_wr_video_field_ff0 && i_wr_video_valid_ff0)
            cnt_pixel <= cnt_pixel + 1;
        else
            cnt_pixel <= cnt_pixel;
    end
    //video data combination counter
    always@(posedge i_clk)begin
        if(reset_sync)
            cnt_comb <= 0;
        else if(~i_wr_video_field_ff0 || line_last)
            cnt_comb <= 0;
        else if(i_wr_video_field_ff0 && i_wr_video_valid_ff0 && cnt_comb == CNT_VIDEO2AXI_COMB_MAX-1)
            cnt_comb <= 0;
        else if(i_wr_video_field_ff0 && i_wr_video_valid_ff0)
            cnt_comb <= cnt_comb + 1;
        else
            cnt_comb <= cnt_comb;
    end
    //AXI burst len counter
    always@(posedge i_clk)begin
        if(reset_sync)
            cnt_wr_burst <= 0;
        else if(~i_wr_video_field_ff0 || line_last)
            cnt_wr_burst <= 0;
        else if(i_wr_video_field_ff0 && i_wr_video_valid_ff0 && cnt_comb == CNT_VIDEO2AXI_COMB_MAX-1)
            cnt_wr_burst <= cnt_wr_burst + 1;
        else
            cnt_wr_burst <= cnt_wr_burst;
    end
    // r_o_wr_buff_vld
    always @(posedge i_clk) begin
        if (reset_sync)
            r_o_wr_buff_vld <= 0;
        else if ( (cnt_comb == CNT_VIDEO2AXI_COMB_MAX-1 || line_last) &&  i_wr_video_field_ff0 && i_wr_video_valid_ff0) 
            r_o_wr_buff_vld <= 1'b1;
        else 
            r_o_wr_buff_vld <= 0;
    end
    // comp data
    genvar i;
    generate 
        for(i = 0 ; i <= CNT_VIDEO2AXI_COMB_MAX-1 ; i = i + 1)begin
            always@(posedge i_clk)begin
                if(reset_sync)
                    r_o_wr_buff_data[( VIDEO_WR_DATA_WIDTH*(i+1)-1) : VIDEO_WR_DATA_WIDTH*i] <= 0;
                else if (i_wr_video_field_ff0 && i_wr_video_valid_ff0 && cnt_comb == i) 
                    r_o_wr_buff_data[(VIDEO_WR_DATA_WIDTH*(i+1)-1) : VIDEO_WR_DATA_WIDTH*i] <= i_wr_video_data_ff0;
                //WARING:don't add "else r_o_wr_buff_data <= r_o_wr_buff_data"  
            end
        end
    endgenerate 
    // wr_data_last
    always @(posedge i_clk) begin
        if (reset_sync) begin
            r_o_wr_buff_req_en    <= 0;  
            r_o_wr_buff_data_last <= 0;      
        end
        else begin
            r_o_wr_buff_req_en    <= line_last;
            r_o_wr_buff_data_last <= line_last;
        end   
    end
    //burst len
    always @(posedge i_clk) begin
        if (reset_sync) 
            r_o_wr_buff_burst_len <= 0;
        else if (line_last) 
            r_o_wr_buff_burst_len <= cnt_wr_burst;
        else 
            r_o_wr_buff_burst_len <= r_o_wr_buff_burst_len;
    end
    //base addr
    always @(posedge i_clk) begin
        if (reset_sync) 
            r_o_wr_buff_addr <= 0;
        else if (wr_video_field_rise) 
            r_o_wr_buff_addr <= i_wr_video_base_addr;
        else if (o_wr_buff_req_en)
            r_o_wr_buff_addr <= r_o_wr_buff_addr + 16'h1000; //give every line 4KB address space
        else 
            r_o_wr_buff_addr <= r_o_wr_buff_addr;
    end
/*----------------------		instantiate  			----------------------*/

endmodule
