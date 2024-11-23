`include "Packet.sv"
`include "OutputPacket.sv"
class Scoreboard;
       string   name;			// unique identifier
       Packet pkt_sent = new();	// Packet object from Driver
       OutputPacket   pkt2cmp = new();		// Packet object from Receiver

       typedef mailbox #(Packet) out_box_type;
       out_box_type driver_mbox;		// mailbox for Packet objects from Drivers

       typedef mailbox #(OutputPacket) rx_box_type;
       rx_box_type 	receiver_mbox;		// mailbox for Packet objects from Receiver

	// Declare the signals to be compared over here.
       reg	[`REGISTER_WIDTH-1:0] 	aluout_chk = 0;
       reg				mem_en_chk;
       reg	[`REGISTER_WIDTH-1:0] 	memout_chk;

       reg	[`REGISTER_WIDTH-1:0]	aluin1_chk =0 , aluin2_chk=0; 
       reg	[2:0]			opselect_chk=0;
       reg	[2:0]			operation_chk=0;	
       reg	[4:0]          		shift_number_chk=0;
       reg				enable_shift_chk=0, enable_arith_chk=0;
       reg	[16:0] 			aluout_half_chk;
	
       extern function new(string name = "Scoreboard", out_box_type driver_mbox = null, rx_box_type receiver_mbox = null);
       extern virtual task start();
       extern virtual task check();
       extern virtual task check_arith();
       extern virtual task check_preproc();
	extern virtual task check_shift() ;
	extern virtual task check_mem_write() ;

	
endclass

function Scoreboard::new(string name, out_box_type driver_mbox, rx_box_type receiver_mbox);
       this.name = name;
       if (driver_mbox == null) 
	       driver_mbox = new();
       if (receiver_mbox == null) 
	       receiver_mbox = new();
       this.driver_mbox = driver_mbox;
       this.receiver_mbox = receiver_mbox;
endfunction

task Scoreboard::start();
       $display ($time, "[SCOREBOARD] Scoreboard Started");

       $display ($time, "[SCOREBOARD] Receiver Mailbox contents = %d", receiver_mbox.num());
       fork
	       forever 
	       begin
		       if(receiver_mbox.try_get(pkt2cmp)) begin
			       $display ($time, "[SCOREBOARD] Grabbing Data From both Driver and Receiver");
			       //receiver_mbox.get(pkt2cmp);
			       driver_mbox.get(pkt_sent);
			       check();
		       end
		       else 
		       begin
			       #1;
		       end
	       end
       join_none
       $display ($time, "[SCOREBOARD] Forking of Process Finished");
endtask

task Scoreboard::check();
	
       $display($time, "ns: [CHECKER] Checker Start\n\n");		
       // Grab packet sent from scoreboard 				
       $display($time, "ns:   [CHECKER] Pkt Contents: src1 = %h, src2 = %h, imm = %h, ", pkt_sent.src1, pkt_sent.src2, pkt_sent.imm);
       $display($time, "ns:   [CHECKER] Pkt Contents: opselect = %b, immp_regn = %b, operation = %b, ", pkt_sent.opselect_gen, pkt_sent.immp_regn_op_gen, pkt_sent.operation_gen);
       
       //check_arith();
       check_preproc();
	check_shift() ;
	//check_mem_write() ;

endtask

task Scoreboard::check_mem_write() ;
	$display($time, "ns:  	[CHECK_ARITH] Golden Incoming CONTROL = %h(opselect)  %h(operation) ", opselect_chk, operation_chk);
	$display($time, "ns:  mem_en_chk = %b", mem_en_chk);
		if(mem_en_chk == 1 ) 
			memout_chk = pkt_sent.src2 ;
		else 
			memout_chk = 0 ;
		assert( pkt2cmp.mem_data_write_out == memout_chk) $display($time, "ns:   [CHECKER CORRECT] ALUOUT: DUT = %h   & Golden Model = %h\n", pkt2cmp.mem_data_write_out , memout_chk);
		else $display($time, "ns:   [CHECKER BUG] ALUOUT: DUT = %h   & Golden Model = %h\n", pkt2cmp.mem_data_write_out , memout_chk); 
endtask

task Scoreboard::check_arith();
      $display($time, "ns:  	[CHECK_ARITH] Golden Incoming Arithmetic enable = %b", enable_arith_chk);
       $display($time, "ns:  	[CHECK_ARITH] Golden Incoming ALUIN = %h  %h ", aluin1_chk, aluin2_chk);
       $display($time, "ns:  	[CHECK_ARITH] Golden Incoming CONTROL = %h(opselect)  %h(operation) ", opselect_chk, operation_chk);
       if(1 == enable_arith_chk) begin
	       if ((opselect_chk == `ARITH_LOGIC))	// arithmetic
	       begin
		       case(operation_chk)
		       `ADD : 	begin	aluout_chk = aluin1_chk + aluin2_chk;	    end
		       `HADD: 	begin   {aluout_half_chk} = aluin1_chk[15:0] + aluin2_chk[15:0]; aluout_chk = {{16{aluout_half_chk[15]}},aluout_half_chk[15:0]};	end 
		       `SUB: 	begin   aluout_chk = aluin1_chk - aluin2_chk;    	end 
		       `NOT: 	begin   aluout_chk = ~aluin2_chk;    	end 
		       `AND: 	begin   aluout_chk = aluin1_chk & aluin2_chk;    	end
		       `OR: 	begin   aluout_chk = aluin1_chk | aluin2_chk;    	end
		       `XOR: 	begin   aluout_chk = aluin1_chk ^ aluin2_chk;      	end
		       `LHG: 	begin   aluout_chk = {aluin2_chk[15:0],{16{1'b0}}};	end
		       endcase
	       end
		if(opselect_chk== `MEM_READ)
		begin
			case(operation_chk)
			`LOADBYTE : aluout_chk = {{24{aluin2_chk[7]}}, aluin2_chk[7:0]};
			`LOADBYTEU :  aluout_chk = {24'b0, aluin2_chk[7:0]};
			`LOADHALF : aluout_chk = {{16{aluin2_chk[15]}}, aluin2_chk[15:0]};
			`LOADHALFU : aluout_chk = {16'b0 , aluin2_chk[15:0]};
			`LOADWORD : aluout_chk = aluin2_chk ;
			default : aluout_chk = aluin2_chk ;
			endcase	
		end	
	end	       
	else
       		aluout_chk = 0;

	assert (pkt2cmp.aluout == aluout_chk) $display($time, "ns:   [CHECKER CORRECT] ALUOUT: DUT = %h   & Golden Model = %h\n", pkt2cmp.aluout, aluout_chk); 
	else $display($time, "ns:   [CHECKER BUG] ALUOUT: DUT = %h   & Golden Model = %h\n", pkt2cmp.aluout, aluout_chk);	
endtask	

/*task Scoreboard::check_shift();
    $display($time, "ns:   \t[CHECK_SHIFT] Golden Incoming Shift enable = %b", enable_shift_chk);
    $display($time, "ns:   \t[CHECK_SHIFT] Golden Incoming ALUIN = %h  %h ", aluin1_chk, aluin2_chk);
    $display($time, "ns:   \t[CHECK_SHIFT] Golden Incoming CONTROL = %h(opselect)  %h(operation) ", opselect_chk, operation_chk);
    $display("shift_number_chk (Decimal): %d", shift_number_chk);
    if (enable_shift_chk == 1) begin
        if (opselect_chk == `SHIFT_REG) begin
            case (operation_chk)
                `SHLEFTLOG: begin
                    aluout_chk = aluin1_chk << shift_number_chk;
                    $display("Operation: Logical Shift Left");
                end
                `SHLEFTART: begin
                    aluout_chk = aluin1_chk <<< shift_number_chk;
                    $display("Operation: Arithmetic Shift Left");
                end
                `SHRGHTLOG: begin
                    aluout_chk = aluin1_chk >> shift_number_chk;
                    $display("Operation: Logical Shift Right");
                end
                `SHRGHTART: begin
                    aluout_chk = $signed (aluin1_chk) >> shift_number_chk;
                    $display("Operation: Arithmetic Shift Right");
                end
            endcase
        end
    end else begin
        aluout_chk = 0;
    end

    assert (pkt2cmp.aluout == aluout_chk)
        $display($time, "ns:   [CHECKER CORRECT] ALUOUT: DUT = %h   & Golden Model = %h\n", pkt2cmp.aluout, aluout_chk);
    else
        $display($time, "ns:   [CHECKER BUG] ALUOUT: DUT = %h   & Golden Model = %h\n", pkt2cmp.aluout, aluout_chk); 
endtask */

task Scoreboard::check_shift();
    $display($time, "ns:   [CHECK_SHIFT] bdau");
    $display($time, "ns:  	[CHECK_SHIFT] Golden Incoming ALUIN = %h  %h ", aluin1_chk, aluin2_chk);
       $display($time, "ns:  	[CHECK_SHIFT] Golden Incoming CONTROL = %h(opselect)  %h(operation) %h(shift_number_chk) ", opselect_chk, operation_chk, shift_number_chk);
        if (enable_shift_chk) begin
        case (operation_chk)
            `SHLEFTLOG: begin
                // Ph�p d?ch tr�i logic
                aluout_chk = aluin1_chk << shift_number_chk;
                $display($time, "ns:   [CHECK_SHIFT] dichtrai");
            end
            `SHLEFTART: begin
                aluout_chk = aluin1_chk << shift_number_chk;
                $display($time, "ns:   [CHECK_SHIFT] dichtraisohoc");
            end
            `SHRGHTLOG: begin
                // Ph�p d?ch ph?i logic
                aluout_chk = aluin1_chk >> shift_number_chk;
                $display($time, "ns:   [CHECK_SHIFT] dichphai");
            end
            `SHRGHTART: begin
                // Ph�p d?ch ph?i s? h?c
                aluout_chk = aluin1_chk >>> shift_number_chk;
                $display($time, "ns:   [CHECK_SHIFT] dichphaisohoc");
            end
            endcase
    end else begin
	aluin1_chk = pkt2cmp.aluin1 ;
        aluout_chk = pkt2cmp.aluout ;
    end
 
    // Ki?m tra gi� tr? ??u ra c?a DUT
    assert (pkt2cmp.aluout == aluout_chk)
        $display($time, "ns:   [CHECK_SHIFT CORRECT] ALUOUT: DUT = %h, Golden Model = %h", pkt2cmp.aluout, aluout_chk);
    else
        $display($time, "ns:   [CHECK_SHIFT BUG] ALUOUT: DUT = %h, Golden Model = %h", pkt2cmp.aluout, aluout_chk);
endtask

task Scoreboard::check_preproc();

       if (((pkt_sent.opselect_gen == `ARITH_LOGIC)||((pkt_sent.opselect_gen == `MEM_READ) && (pkt_sent.immp_regn_op_gen==1))) && pkt_sent.enable) begin
	       enable_arith_chk = 1'b1;
       end
       else begin
	       enable_arith_chk = 1'b0;
       end

       if ((pkt_sent.opselect_gen == `SHIFT_REG)&& pkt_sent.enable) begin
	       enable_shift_chk = 1'b1;
       end
       else begin
	       enable_shift_chk = 1'b0;
       end

       if (((pkt_sent.opselect_gen == `ARITH_LOGIC)||((pkt_sent.opselect_gen == `MEM_READ) && (pkt_sent.immp_regn_op_gen==1))) && pkt_sent.enable) begin 
	       if((1 == pkt_sent.immp_regn_op_gen)) begin
		       if (pkt_sent.opselect_gen == `MEM_READ) // memory read operation that needs to go to dest 
			       aluin2_chk = pkt_sent.mem_data;
		       else // here we assume that the operation must be a arithmetic operation
			       aluin2_chk = pkt_sent.imm;
	       end
	       else begin
		       aluin2_chk = pkt_sent.src2;
	       end
       end

       if(pkt_sent.enable) begin
	       aluin1_chk = pkt_sent.src1;
	       operation_chk = pkt_sent.operation_gen;
	       opselect_chk = pkt_sent.opselect_gen;
       end

       if ((pkt_sent.opselect_gen == `SHIFT_REG)&& pkt_sent.enable) begin
   if (pkt_sent.imm[2] == 1'b0) 
       shift_number_chk = pkt_sent.imm[10:6];
   else 
       shift_number_chk = pkt_sent.src2[4:0];
end
else 
   shift_number_chk = 0;
	
	if( (pkt_sent.immp_regn_op_gen == 1) && (pkt_sent.opselect_gen == `MEM_WRITE) ) 
		mem_en_chk = 1'b1 ;
	else
		mem_en_chk = 1'b0 ;
			
	
	assert (pkt2cmp.aluin1 == aluin1_chk) else
	       $display($time, "ns:   [CHECK_PREPROC BUG] ALUIN1: DUT = %h   & Golden Model = %h\n", pkt2cmp.aluin1, aluin1_chk);	
	assert (pkt2cmp.aluin2 == aluin2_chk) else      
	       $display($time, "ns:   [CHECK_PREPROC BUG] ALUIN2: DUT = %h   & Golden Model = %h\n", pkt2cmp.aluin2, aluin2_chk);	
        assert (pkt2cmp.enable_arith == enable_arith_chk) else
	       $display($time, "ns:   [CHECK_PREPROC BUG] ENABLE_ARITH: DUT = %b   & Golden Model = %b\n", pkt2cmp.enable_arith, enable_arith_chk);	
       	assert (pkt2cmp.enable_shift == enable_shift_chk) else
	       $display($time, "ns:   [CHECK_PREPROC BUG] ENABLE_SHIFT: DUT = %h   & Golden Model = %h\n", pkt2cmp.enable_shift, enable_shift_chk);	
       	assert (pkt2cmp.operation == operation_chk) else
	       $display($time, "ns:   [CHECK_PREPROC BUG] OPERATION: DUT = %h   & Golden Model = %h\n", pkt2cmp.operation, operation_chk);	
	assert (pkt2cmp.opselect == opselect_chk) else	       
	       $display($time, "ns:   [CHECK_PREPROC BUG] OPSELECT: DUT = %h   & Golden Model = %h\n", pkt2cmp.opselect, opselect_chk);
	assert (pkt2cmp.shift_number == shift_number_chk) else	       	
	       $display($time, "ns:   [CHECK_PREPROC BUG] SHIFT_NUMBER: DUT = %h   & Golden Model = %h\n", pkt2cmp.shift_number, shift_number_chk);	
	endtask	


			
		
	
