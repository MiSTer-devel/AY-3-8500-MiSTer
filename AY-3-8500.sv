//============================================================================
//  AY-3-8500 for MiSTer
//
//  Copyright (C) 2019 Cole Johnson
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_F1    = 0;
assign LED_USER  = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

assign AUDIO_MIX = 0;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;

wire [1:0] ar = status[2:1];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"AY-3-8500;;",
	"-;",
	"O12,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O7A,Color Pallette,Mono,Greyscale,RGB1,RGB2,Field,Ice,Christmas,Marksman,Las Vegas;",
	"-;",
	"OBD,Game,Tennis,Soccer,Handicap,Squash,Practice;", //,Rifle 1,Rifle 2;",
	"OE,Auto Serve,No,Yes;",
	"OF,Size,Big,Small;",
	"OG,Angle,1,2;",
	"OH,Speed,Slow,Fast;",
	"O6,Invisiball,OFF,ON;",
	"-;",
	"OIJ,Control P1,Digital,Y,X,Paddle;",
	"OM,Invert P1,No,Yes;",
	"OKL,Control P2,Digital,Y,X,Paddle;",
	"ON,Invert P2,No,Yes;",
	"-;",
	"R0,Reset;",
	"J,Serve;",
	"jn,Start;",
	"V,v",`BUILD_DATE
};


////////////////////   CLOCKS   ///////////////////

wire clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_sys)
);

reg ce_2m;
always @(posedge clk_sys) begin
	reg [5:0] div;
	
	div <= div + 1'd1;
	if(div == 23) div <= 0;

	ce_2m <= !div;
end

reg ce_6m;
always @(posedge clk_sys) begin
	reg [2:0] div;
	
	div <= div + 1'd1;
	ce_6m <= !div;
end

///////////////////////IN+OUT///////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [10:0] ps2_key;

wire [15:0] joy0,joy1;
wire [15:0] joystick_analog_0;
wire [15:0] joystick_analog_1;
wire  [7:0] paddle_0;
wire  [7:0] paddle_1;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.joystick_0(joy0),
	.joystick_1(joy1),
	.joystick_l_analog_0(joystick_analog_0),
	.joystick_l_analog_1(joystick_analog_1),
	.paddle_0(paddle_0),
	.paddle_1(paddle_1),
	.ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];
wire [7:0] code    = ps2_key[7:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		case(code)
			'h1D: btnP1Up   <= pressed; // W
			'h1B: btnP1Down <= pressed; // S
			'h75: btnP2Up   <= pressed; // up
			'h72: btnP2Down <= pressed; // down
			'h29: btnServe  <= pressed; // space
		endcase
	end
end

reg btnP1Up = 0;
reg btnP1Down = 0;
reg btnP2Up = 0;
reg btnP2Down = 0;
reg btnServe = 0;

wire angle = status[16];
wire speed = status[17];
wire size  = status[15];
wire autoserve = status[14];

reg [7:0] gameSelect;
always @(posedge clk_sys) gameSelect <= 8'd1 << status[13:11];

/////////////////Paddle Emulation//////////////////
wire [4:0] paddleMoveSpeed = speed ? 5'd8 : 5'd5;//Faster paddle movement when ball speed is high
reg [8:0] player1pos = 8'd128;
reg [8:0] player2pos = 8'd128;
reg [8:0] player1cap = 0;
reg [8:0] player2cap = 0;
reg hsOld = 0;
reg vsOld = 0;
always @(posedge clk_sys) begin
	hsOld <= hs;
	vsOld <= vs;
	if(vs & !vsOld) begin
		if(!status[19:18]) begin
			player1cap <= player1pos ^ {8{status[22]}};

			if(btnP1Up   | joy0[3]) player1pos <= ((player1pos - paddleMoveSpeed) > 255) ? 9'd0   : (player1pos - paddleMoveSpeed);
			if(btnP1Down | joy0[2]) player1pos <= ((player1pos + paddleMoveSpeed) > 255) ? 9'd255 : (player1pos + paddleMoveSpeed);
		end
		else if(~status[19]) begin
			player1cap <= {~joystick_analog_0[15],joystick_analog_0[14:8]} ^ {8{status[22]}};
		end
		else if(~status[18]) begin
			player1cap <= {~joystick_analog_0[7],joystick_analog_0[6:0]} ^ {8{status[22]}};
		end
		else begin
			player1cap <= paddle_0 ^ {8{status[22]}};
		end

		if(!status[21:20]) begin
			player2cap <= player2pos ^ {8{status[23]}};

			if(btnP2Up   | joy1[3]) player2pos <= ((player2pos - paddleMoveSpeed) > 255) ? 9'd0   : (player2pos - paddleMoveSpeed);
			if(btnP2Down | joy1[2]) player2pos <= ((player2pos + paddleMoveSpeed) > 255) ? 9'd255 : (player2pos + paddleMoveSpeed);
		end
		else if(~status[21]) begin
			player2cap <= {~joystick_analog_1[15],joystick_analog_1[14:8]} ^ {8{status[23]}};
		end
		else if(~status[20]) begin
			player2cap <= {~joystick_analog_1[7],joystick_analog_1[6:0]} ^ {8{status[23]}};
		end
		else begin
			player2cap <= paddle_1 ^ {8{status[23]}};
		end
	end
	else if(hs & !hsOld) begin
		if(player1cap!=0) player1cap <= player1cap - 9'd1;
		if(player2cap!=0) player2cap <= player2cap - 9'd1;
	end
end

//Signal outputs (active-high except for sync)
wire audio;
wire rpOut;
wire lpOut;
wire ballOut;
wire scorefieldOut;
wire syncH;
wire syncV;
wire isBlanking;

wire lpIN = (player1cap == 0);
wire rpIN = (player2cap == 0);
wire lpIN_reset;//We don't use these signals, instead the VSYNC signal (identical) is directly accessed
wire rpIN_reset;
wire chipReset = status[0] | buttons[1];
ay38500NTSC the_chip
(
	.superclock(clk_sys),
	.clk(ce_2m),
	.reset(!chipReset),
	.pinRPout(rpOut),
	.pinLPout(lpOut),
	.pinBallOut(ballOut),
	.pinSFout(scorefieldOut),
	.syncH(syncH),
	.syncV(syncV),
	.pinSound(audio),
	.pinManualServe(!(autoserve | btnServe | joy0[4] | joy1[4])),
	.pinBallAngle(!angle),
	.pinBatSize(!size),
	.pinBallSpeed(!speed),
	.pinPractice(!gameSelect[4]),
	.pinSquash(!gameSelect[3]),
	.pinSoccer(!gameSelect[1]),
	.pinTennis(!gameSelect[0]),
	.pinRifle1(!gameSelect[5]),
	.pinRifle2(!gameSelect[6]),
	.pinHitIn(audio),
	.pinShotIn(1),
	.pinLPin(lpIN),
	.pinRPin(gameSelect[4] ? lpIN : rpIN)
);

/////////////////////VIDEO//////////////////////
wire hs = !syncH;
wire vs = !syncV;
wire [3:0] r,g,b;
wire showBall = !status[6] | (ballHide>0);
reg [5:0] ballHide = 0;
reg audioOld = 0;
always @(posedge clk_sys) begin
	audioOld <= audio;
	if(!audioOld & audio)
		ballHide <= 5'h1F;
	else if(vs & !vsOld & ballHide!=0)
		ballHide <= ballHide - 1'd1;
end
reg [12:0] colorOut = 0;
always @(posedge clk_sys) begin
	if(ballOut & showBall) begin
		case(status[10:7])
			'h0: colorOut <= 12'hFFF;//Mono
			'h1: colorOut <= 12'hFFF;//Greyscale
			'h2: colorOut <= 12'hF00;//RGB1
			'h3: colorOut <= 12'hFFF;//RGB2
			'h4: colorOut <= 12'h000;//Field
			'h5: colorOut <= 12'h000;//Ice
			'h6: colorOut <= 12'hFFF;//Christmas
			'h7: colorOut <= 12'hFFF;//Marksman
			'h8: colorOut <= 12'hFF0;//Las Vegas
		endcase
	end
	else if(lpOut) begin
		case(status[10:7])
			'h0: colorOut <= 12'hFFF;//Mono
			'h1: colorOut <= 12'hFFF;//Greyscale
			'h2: colorOut <= 12'h0F0;//RGB1
			'h3: colorOut <= 12'h00F;//RGB2
			'h4: colorOut <= 12'hF00;//Field
			'h5: colorOut <= 12'hF00;//Ice
			'h6: colorOut <= 12'hF00;//Christmas
			'h7: colorOut <= 12'hFF0;//Marksman
			'h8: colorOut <= 12'hFF0;//Las Vegas
		endcase
	end
	else if(rpOut) begin
		case(status[10:7])
			'h0: colorOut <= 12'hFFF;//Mono
			'h1: colorOut <= 12'h000;//Greyscale
			'h2: colorOut <= 12'h0F0;//RGB1
			'h3: colorOut <= 12'hF00;//RGB2
			'h4: colorOut <= 12'h00F;//Field
			'h5: colorOut <= 12'h030;//Ice
			'h6: colorOut <= 12'h030;//Christmas
			'h7: colorOut <= 12'h000;//Marksman
			'h8: colorOut <= 12'hF0F;//Las Vegas
		endcase
	end
	else if(scorefieldOut) begin
		case(status[10:7])
			'h0: colorOut <= 12'hFFF;//Mono
			'h1: colorOut <= 12'hFFF;//Greyscale
			'h2: colorOut <= 12'h00F;//RGB1
			'h3: colorOut <= 12'h0F0;//RGB2
			'h4: colorOut <= 12'hFFF;//Field
			'h5: colorOut <= 12'h55F;//Ice
			'h6: colorOut <= 12'hFFF;//Christmas
			'h7: colorOut <= 12'hFFF;//Marksman
			'h8: colorOut <= 12'hF90;//Las Vegas
		endcase
	end
	else begin
		case(status[10:7])
			'h0: colorOut <= 12'h000;//Mono
			'h1: colorOut <= 12'h999;//Greyscale
			'h2: colorOut <= 12'h000;//RGB1
			'h3: colorOut <= 12'h000;//RGB2
			'h4: colorOut <= 12'h4F4;//Field
			'h5: colorOut <= 12'hCCF;//Ice
			'h6: colorOut <= 12'h000;//Christmas
			'h7: colorOut <= 12'h0D0;//Marksman
			'h8: colorOut <= 12'h000;//Las Vegas
		endcase
	end
end

reg HBlank, VBlank;
always @(posedge clk_sys) begin
	reg [10:0] hcnt, vcnt;
	reg old_hs, old_vs;

	if(ce_2m) begin
		hcnt <= hcnt + 1'd1;
		old_hs <= syncH;
		if(old_hs & ~syncH) begin
			hcnt <= 0;
			
			vcnt <= vcnt + 1'd1;
			old_vs <= syncV;
			if(old_vs & ~syncV) vcnt <= 0;
		end
		
		if (hcnt == 21)  HBlank <= 0;
		if (hcnt == 100) HBlank <= 1;
		
		if (vcnt == 34)  VBlank <= 0;
		if (vcnt == 240) VBlank <= 1;
	end
end

arcade_video #(.WIDTH(240), .DW(12)) arcade_video
(
	.*,

	.clk_video(clk_sys),
	.ce_pix(ce_6m),

	.RGB_in(colorOut),
	.HSync(syncH),
	.VSync(syncV),

	.fx(status[5:3])
);

////////////////////AUDIO////////////////////////
assign AUDIO_L = {audio, 15'b0};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

endmodule
