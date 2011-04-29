implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;
include "./share.m";

test()
{
	plan(7);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();
	
	cmd: Cmd;
	r: ref ReadBuf;
	wc: Sys->Rwrite;

	# queue:
	# - n=queuesize writes answered without read
	# - next write not answered (pending)
	# - next write answered with error "concurent…"
	# - after read pending write answered
	
	(cmd, r, wc) = new_chan2buf(4, 16);

	send(cmd, "write", "123");
	eq_int((<-wc).t0, 3, nil);
	send(cmd, "write", "12");
	eq_int((<-wc).t0, 2, nil);
	send(cmd, "write", "12345\n");
	eq_int((<-wc).t0, 6, nil);
	send(cmd, "write", "12345678");
	eq_int((<-wc).t0, 8, nil);

	send(cmd, "write", "1234");
	sys->sleep(100);
	alt{
	<-wc =>	ok(0, "no reply on pending write");
	* =>	ok(1, "no reply on pending write");
	}

	send(cmd, "write", "bad");
	eq((<-wc).t1, "concurrent writes not supported", nil);

	spawn reads(r);
	eq_int((<-wc).t0, 4, "pending write replied");
}

reads(r: ref ReadBuf)
{
	r.reads();
}
