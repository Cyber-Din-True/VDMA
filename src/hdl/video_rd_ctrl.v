
module video_rd_ctrl#(
    parameter VIDEO_RD_DATA_WIDTH   = 16    ,
    parameter AXI_DATA_WIDTH        = 128   ,
    parameter AXI_ADDR_WIDTH        = 32
    )(
    //system signal
    input                                   i_clk                   ,
    input                                   i_reset                 ,
    //DDR initial signal
    input                                   i_ddr_init_done         ,
    //video data read signals(LCD output)
    input   wire [15:0]                     i_rd_video_width        ,
    input   wire [15:0]                     i_rd_video_high         ,
    input   wire                            i_rd_video_field        ,
    input   wire                            i_rd_video_valid        ,
    input   wire [AXI_ADDR_WIDTH-1:0]       i_rd_video_base_addr    ,
    //1:Read image data in reverse order | 0:normal
    input   wire                            i_rd_video_frame_mode   ,
    //1:Read at the rising edge of the field | 0:Read at the falling edge of the field
    input   wire                            i_rd_video_trig_mode    ,
    //video_rd_buffer interaction signal
    output  wire                            o_rd_buff_req_en        ,
    input   wire                            i_rd_buff_req_ready     ,
    output  wire  [7:0]                     o_rd_buff_burst_len     ,
    output  wire  [AXI_ADDR_WIDTH-1:0]      o_rd_buff_data_addr     ,
    output  wire                            o_rd_buff_frame_reset   ,
    output  wire                            o_rd_buff_line_rden     ,
    output  wire  [15:0]                    o_video_width
    );
/*----------------------		parameter       		----------------------*/
    localparam CNT_AXI2VIDEO_COMB_MAX = AXI_DATA_WIDTH/VIDEO_RD_DATA_WIDTH;
    //state machine
    localparam RD_FRAME_IDLE     = 5'b00001;
    localparam RD_FRAME_CLEAR    = 5'b00010;
    localparam RD_FRAME_RST_WAIT = 5'b00100;
    localparam RD_FRAME_REQ      = 5'b01000;
    localparam RD_FRAME_END      = 5'b10000;
/*----------------------		internal reg signal		----------------------*/
    //output register
    reg                           r_o_rd_buff_req_en      ;
    reg [7:0]                     r_o_rd_buff_burst_len   ;
    reg [AXI_ADDR_WIDTH-1:0]      r_o_rd_buff_data_addr   ;
    reg                           r_o_rd_buff_frame_reset ;
    //state machine
    reg [4:0] state_current,state_next;
    //delay
    (* dont_touch ="true" *) reg reset_ff0;
    (* dont_touch ="true" *) reg reset_ff1;
    (* dont_touch ="true" *) reg reset_sync;
    reg i_rd_video_field_ff0;
    reg i_rd_video_valid_ff0;
    reg ddr_init_done_ff0,ddr_init_done_ff1;
    //DDR read enable
    reg ddr_rd_en;
    //register control signal
    reg  [AXI_ADDR_WIDTH-1: 0] r_i_rd_video_base_addr;
    reg  [15:0]                r_i_rd_video_width    ;
    reg  [15:0]                r_i_rd_video_high     ;
    //counter
    reg  [4:0]  cnt_frame_clear;
    reg  [4:0]  cnt_frame_reset;
    //
    reg  [15:0] line_num;
/*----------------------		internal wire signal 	----------------------*/
    wire rd_video_field_rise,rd_video_field_fall;
    wire video_rd_req_trig  ;
/*---------------------- 		output assign 			----------------------*/
    assign o_rd_buff_req_en        = r_o_rd_buff_req_en     ;
    assign o_rd_buff_burst_len     = r_o_rd_buff_burst_len  ;
    assign o_rd_buff_data_addr     = r_o_rd_buff_data_addr  ;
    assign o_rd_buff_frame_reset   = r_o_rd_buff_frame_reset;
    assign o_video_width           = r_i_rd_video_width     ;
/*----------------------		state machine			----------------------*/
    always@(posedge i_clk)begin
        if(reset_sync)
            state_current <= RD_FRAME_IDLE;
        else
            state_current <= state_next;
    end

    always@(*)begin
        case(state_current)
            RD_FRAME_IDLE : begin
                if (video_rd_req_trig)
                    state_next = RD_FRAME_CLEAR;
                else 
                    state_next = state_current; end
            RD_FRAME_CLEAR : begin  //async fifo need 12 clock to reset
                if (cnt_frame_clear > 5'd12)
                    state_next = RD_FRAME_RST_WAIT;
                else 
                    state_next = state_current; end
            RD_FRAME_RST_WAIT : begin   //after reset,async fifo need 12 clock to wait
                if (cnt_frame_reset > 5'd12)
                    state_next = RD_FRAME_REQ;
                else 
                    state_next = state_current; end
            RD_FRAME_REQ : begin
                if (~i_rd_video_trig_mode && o_rd_buff_req_en && i_rd_buff_req_ready && line_num == r_i_rd_video_high - 1)
                    state_next = RD_FRAME_END;
                else if (i_rd_video_trig_mode && o_rd_buff_req_en && i_rd_buff_req_ready && line_num == 0)
                    state_next = RD_FRAME_END;
                else 
                    state_next = state_current; end
            RD_FRAME_END : begin
                state_next = RD_FRAME_IDLE; end
            default:state_next = RD_FRAME_IDLE;
        endcase
    end
    //fifo reset wait counter
    always @(posedge i_clk) begin
        if (reset_sync) 
            cnt_frame_clear <= 0;
        else if (state_current == RD_FRAME_CLEAR) 
            cnt_frame_clear <= cnt_frame_clear + 1'b1;
        else 
            cnt_frame_clear <= 0;
    end

    always @(posedge i_clk) begin
        if (reset_sync) 
            cnt_frame_reset <= 0;
        else if (state_current == RD_FRAME_RST_WAIT) 
            cnt_frame_reset <= cnt_frame_reset + 1'b1;
        else 
            cnt_frame_reset <= 0;
    end
    //r_o_rd_buff_req_en
    always @(posedge i_clk) begin
        if (reset_sync)
            r_o_rd_buff_req_en <= 0;
        else if (r_o_rd_buff_req_en)
            r_o_rd_buff_req_en <= 0;
        else if (state_current == RD_FRAME_REQ && i_rd_buff_req_ready)
            r_o_rd_buff_req_en <= 1'b1;
        else
            r_o_rd_buff_req_en <= r_o_rd_buff_req_en;
    end
    //r_o_rd_buff_frame_reset
    always @(posedge i_clk) begin
        if (reset_sync)
            r_o_rd_buff_frame_reset <= 1'b1;
        else
            r_o_rd_buff_frame_reset <= state_current == RD_FRAME_CLEAR;
    end
/*----------------------		combinatorial logic     ----------------------*/
    //rd_video+field edge detection
    assign rd_video_field_rise = ddr_rd_en ? i_rd_video_field & ~i_rd_video_field_ff0 : 1'b0;
    assign rd_video_field_fall = ddr_rd_en ? ~i_rd_video_field & i_rd_video_field_ff0 : 1'b0;

    assign o_rd_buff_line_rden = ddr_rd_en ? i_rd_video_field & i_rd_video_valid : 1'b0;

    assign video_rd_req_trig = i_rd_video_trig_mode ? rd_video_field_rise : rd_video_field_fall;
    //read data address
    always @(*) begin
        r_o_rd_buff_data_addr <= r_i_rd_video_base_addr + {line_num[11:0], 12'h0};
    end
/*----------------------		sequential logic		----------------------*/
    //reset CDC 
    always@(posedge i_clk)begin
        reset_ff0  <= i_reset;
        reset_ff1  <= reset_ff0;
        reset_sync <= reset_ff1;
    end
    //async ddr_init_done
    always@(posedge i_clk)begin
        ddr_init_done_ff0 <= i_ddr_init_done;
        ddr_init_done_ff1 <= ddr_init_done_ff0;
    end

    always@(posedge i_clk)begin
        if(reset_sync)
            ddr_rd_en <= 0;
        else if(~i_rd_video_field)
            ddr_rd_en <= ddr_init_done_ff1;
        else
            ddr_rd_en <= ddr_rd_en;
    end
    //field,valid delay
    always@(posedge i_clk)begin
        if(ddr_rd_en)begin
            i_rd_video_field_ff0 <= i_rd_video_field;
            i_rd_video_valid_ff0 <= i_rd_video_valid;
        end
        else begin
            i_rd_video_field_ff0 <= 0;
            i_rd_video_valid_ff0 <= 0;
        end
    end
    //locked image base addr, high and width
    always @(posedge i_clk) begin
        if (video_rd_req_trig) begin
            r_i_rd_video_base_addr <= i_rd_video_base_addr;
            r_i_rd_video_width     <= i_rd_video_width;
            r_i_rd_video_high      <= i_rd_video_high ;
        end 
        else begin
            r_i_rd_video_base_addr <= r_i_rd_video_base_addr;
            r_i_rd_video_width     <= r_i_rd_video_width    ;
            r_i_rd_video_high      <= i_rd_video_high       ;
        end  
    end 
    //burst len
    always @(posedge i_clk) begin
        if (reset_sync) 
            r_o_rd_buff_burst_len <= 0;
        else if (r_i_rd_video_width[$clog2(CNT_AXI2VIDEO_COMB_MAX)-1:0] == 0)
            r_o_rd_buff_burst_len <= r_i_rd_video_width[15:$clog2(CNT_AXI2VIDEO_COMB_MAX)] - 1;
        else 
            r_o_rd_buff_burst_len <= r_i_rd_video_width[15:$clog2(CNT_AXI2VIDEO_COMB_MAX)];
    end
    //line num
    always @(posedge i_clk) begin
        if (reset_sync) 
            line_num <= 0;
        else if (video_rd_req_trig && ~i_rd_video_trig_mode) 
            line_num <= 0;
        else if (video_rd_req_trig && i_rd_video_trig_mode)
            line_num <= r_i_rd_video_high - 1;
        else if (r_o_rd_buff_req_en && i_rd_buff_req_ready && ~i_rd_video_trig_mode)
            line_num <= line_num + 1;
        else if (r_o_rd_buff_req_en && i_rd_buff_req_ready && i_rd_video_trig_mode)
            line_num <= line_num - 1;
        else 
            line_num <= line_num;
    end
/*----------------------		instantiate  			----------------------*/

endmodule
