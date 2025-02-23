`include "data_defs.v"
`ifndef OUTPUTPACKET_SV
`define OUTPUTPACKET_SV

class OutputPacket;

	string 	name;
	reg	[`REGISTER_WIDTH-1:0] 	aluout;		 
	reg				mem_write_en;		 
	reg	[`REGISTER_WIDTH-1:0] 	mem_data_write_out;
	reg				carry;
		
	reg 	[`REGISTER_WIDTH-1:0]	aluin1; 
	reg 	[`REGISTER_WIDTH-1:0]	aluin2; 
	reg 	[2:0]			opselect;
	reg 	[2:0]			operation;
	reg 	[4:0]  			shift_number;
	reg 				enable_shift; 
	reg 				enable_arith;
	
	extern function new(string name = "OutputPacket");
    
endclass

function OutputPacket::new(string name);
	this.name = name;
endfunction

`endif