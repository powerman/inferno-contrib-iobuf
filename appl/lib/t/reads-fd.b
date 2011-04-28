implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;

test()
{
	plan(16);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();
	
	pipe := array[2] of ref Sys->FD;
	if(sys->pipe(pipe) == -1)
		raise sprint("pipe:%r");
	
	spawn writer(pipe[0], sync := chan of string);
	<-sync;
	pipe[0] = nil;

	r := ReadBuf.new(pipe[1], 16);
	ok(r != nil, "ReadBuf.new");

	# separators:
	# - default
	# - empty
	# - single-byte
	#   * stripped
	#   * non-stripped
	# - multi-byte
	
	# reads:
	# - first reads() blocks until read data into buffer
	# - next reads() return data from buffer
	# - next reads() keep incomplete data tail and blocks/read more
	# - next read return last record
	#   * ending with separator
	#   * not ending with separator
	# - next read return eof
	# - check "iobuf:no separator found in full buffer"
	
	t0: int;
	ex: string;
	a: array of byte;
	s: string;

	t0 = sys->millisec();
	spawn writeafter(100, sync, "123456\n7890\n1234567");
	s = string r.reads();
	ok(sys->millisec() - t0 >= 100, "reads blocked");
	eq(s, "123456", "123456");

	t0 = sys->millisec();
	s = string r.reads();
	ok(sys->millisec() - t0 < 50, "reads not blocked");
	eq(s, "7890", "7890");

	sync <-= "8901234567";
	ex = nil;
	{ r.reads(); } exception e { "*" => ex = e; }
	eq(ex, "iobuf:no separator found in full buffer", "iobuf:no separator found in full buffer");

	r.setsep("0", 0);
	s = string r.reads();
	eq(s, "1234567890", "1234567890");

	ex = nil;
	{ r.setsep("", 1); } exception e { "*" => ex = e; }
	eq(ex, "iobuf:empty separator", "iobuf:empty separator");
	r.setsep("\n", 1);

	t0 = sys->millisec();
	spawn writeafter(100, sync, "\n\n123");
	s = string r.reads();
	ok(sys->millisec() - t0 >= 100, "reads blocked");
	eq(s, "1234567", "1234567");

	a = r.reads();
	ok(a != nil, "not EOF yet");
	eq(string a, "", "empty string");

	sync <-= "";

	a = r.reads();
	ok(a != nil, "not EOF yet");
	eq(string a, "123", "123");

	a = r.reads();
	ok(a == nil, "EOF");

	a = r.reads();
	ok(a == nil, "EOF again");
}

writeafter(delay: int, sync: chan of string, s: string)
{
	sys->sleep(delay);
	sync <-= s;
}

writer(fd: ref Sys->FD, sync: chan of string)
{
	sync <-= "";
	for(;;){
		a := array of byte <-sync;
		if(len a == 0)
			break;
		sys->write(fd, a, len a);
	}
}

