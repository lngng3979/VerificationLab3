`include "ReceiverBase.sv"
`include "OutputPacket.sv"
`include "data_defs.v"

class Receiver extends ReceiverBase;
//  mailbox out_box;	// Scoreboard mailbox
  	typedef mailbox #(OutputPacket) rx_box_type;
  	rx_box_type 	rx_out_box;		// mailbox for Packet objects To Scoreboard 
	//int 			numpackets;
   	extern function new(string name = "Receiver", rx_box_type rx_out_box, virtual Execute_io.TB Execute, virtual DUT_probe_if Prober);
   	extern virtual task start();
endclass

function Receiver::new(string name, rx_box_type rx_out_box, virtual Execute_io.TB Execute, virtual DUT_probe_if Prober);
  super.new(name, Execute, Prober);
  //if (TRACE_ON) $display("[TRACE]%0d %s:%m", $time, name);
  this.rx_out_box = rx_out_box;
  //this.numpackets = numpackets;
endfunction

task Receiver::start();
	int i;
	i = 0;
  //if (TRACE_ON) $display("[TRACE]%0d %s:%m", $time, name);
	$display($time, "[RECEIVER]  RECEIVER STARTED");
	@ (Execute.cb); // to cater to the one cycle delay in the pipeline
	fork
		forever
		begin
			recv();
			rx_out_box.put(pkt2cmp);
			$display($time, "[RECEIVER]  Payload Obtained");
			i++;
			//if (i == numpackets)
			//begin
			//	break;
			//end
		end	
	join_none
	$display ($time, "[RECEIVER] Forking of Process Finished");
endtask

