implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;

test()
{
	plan(9);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();
	
	pipe := array[2] of ref Sys->FD;
	if(sys->pipe(pipe) == -1)
		raise sprint("pipe:%r");
	
	w := WriteBuf.new(pipe[0], 16);
	ok(w != nil, "WriteBuf.new");
	spawn writer(w, wsync := chan of int);
	<-wsync;
	pipe[0] = nil;
	w = nil;

	buf := array[Sys->ATOMICIO] of byte;
	n := sys->read(pipe[1], buf, len buf);
	eq_int(n, 16, "read 16 bytes");
	n = sys->read(pipe[1], buf, len buf);
	eq_int(n, 2, "read 2 bytes");
	n = sys->read(pipe[1], buf, len buf);
	eq_int(n, 16, "read 16 bytes");
	n = sys->read(pipe[1], buf, len buf);
	eq_int(n, 0, "EOF");

	if(sys->pipe(pipe) == -1)
		raise sprint("pipe:%r");
	
	r := ReadBuf.new(pipe[0], 16);
	ok(r != nil, "ReadBuf.new");
	spawn writer2(pipe[1], wsync);
	<-wsync;
	pipe[1] = nil;

	eq(string r.reads(), "123456", "123456");
	r.setsep("\n", 0);
	eq(string r.reads(), "123456\n", "123456\\n");
	ex := "";
	{ r.reads(); } exception e { "*" => ex = e; }
	eq(ex, "iobuf:no separator found in full buffer", "iobuf:no separator found in full buffer");
}

writer(w: ref WriteBuf, wsync: chan of int)
{
	wsync <-= 1;
	w.write(array of byte "");
	w.write(array of byte "123456");
	w.write(array of byte "123456");
	w.write(array of byte "123456");
	w.flush();
	w.write(array of byte "12345678901234567890");
}

writer2(fd: ref Sys->FD, wsync: chan of int)
{
	wsync <-= 1;
	buf := array of byte "123456\n123456\n12345678901234567890\n";
	sys->write(fd, buf, len buf);
}
