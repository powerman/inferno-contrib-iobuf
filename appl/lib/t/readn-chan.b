implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;
include "./share.m";

test()
{
	plan(20);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();
	
	cmd: Cmd;
	r: ref ReadBuf;
	wc: Sys->Rwrite;
	a: array of byte;

	# read:
	# - block until read data into buffer
	# - return data from buffer
	# - keep data leftover in buffer and block until read more data
	# - block until got EOF and return data leftover
	# - return EOF on next readn

	(cmd, r, wc) = new_chan2buf(4, 16);
	spawn suck(wc);

	stopwatch_start();
	send(cmd, "sleep", "100");
	send(cmd, "write", "12345678901234567");

	eq(string r.readn(6), "123456", nil);
	stopwatch_min(100, "block until read data into buffer");

	eq(string r.readn(1), "7", nil);
	stopwatch_max(50, "return data from buffer");
	eq(string r.readn(3), "890", nil);
	stopwatch_max(50, "return data from buffer");

	send(cmd, "sleep", "100");
	send(cmd, "write", "8901234567");
	eq(string r.readn(10), "1234567890", "keep data leftover in buffer");
	stopwatch_min(100, "block until read more data");

	send(cmd, "sleep", "100");
	send(cmd, "stop", nil);
	a = r.readn(10);
	ok(a != nil, "not EOF");
	eq(string a, "1234567", "return data leftover");
	stopwatch_min(100, "block until got EOF");

	ok(r.readn(10) == nil, "EOF");
	ok(r.readn(10) == nil, "EOF again");

	# read large:
	# - do small read which left some data in buffer
	# - block until read data into buffer
	# - block until got EOF and return data leftover
	# - return EOF on next readn

	(cmd, r, wc) = new_chan2buf(4, 16);
	spawn suck(wc);

	send(cmd, "write", "1234567890");
	r.readn(10);
	send(cmd, "write", "abcdefghijABCDEFGHIJ");
	eq(string r.readn(20), "abcdefghijABCDEFGHIJ", nil);

	send(cmd, "write", "1234567890");
	r.readn(7);
	send(cmd, "write", "abcdefghijABCDEFGHIJ");
	eq(string r.readn(20), "890abcdefghijABCDEFG", nil);

	send(cmd, "write", "abcdefghijABCDEFGHIJ");
	send(cmd, "stop", nil);
	a = r.readn(30);
	ok(a != nil, "not EOF");
	eq_int(len a, 23, nil);
	eq(string a, "HIJabcdefghijABCDEFGHIJ", "return data leftover");

	ok(r.readn(30) == nil, "EOF");
	ok(r.readn(30) == nil, "EOF again");
}

suck(wc: Sys->Rwrite)
{
	for(;;)
		<-wc;
}
