implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;
include "./share.m";

test()
{
	plan(8);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();

	cmd: Cmd;
	r: ref ReadBuf;
	fd: ref Sys->FD;
	buf := array[Sys->ATOMICIO] of byte;

	# WriteBuf

	(cmd, fd) = new_buf2fd(16);
	send(cmd, "write", "");
	send(cmd, "write", "123456");
	send(cmd, "write", "123456");
	send(cmd, "write", "123456");
	send(cmd, "flush", nil);
	send(cmd, "write", "12345678901234567890");
	send(cmd, "stop", nil);
	eq_int(sys->read(fd, buf, len buf), 16, nil);
	eq_int(sys->read(fd, buf, len buf),  2, nil);
	eq_int(sys->read(fd, buf, len buf), 16, nil);
	eq_int(sys->read(fd, buf, len buf),  4, nil);
	eq_int(sys->read(fd, buf, len buf),  0, "EOF");

	# ReadBuf

	(cmd, r) = new_fd2buf(16);
	send(cmd, "write", "123456\n123456\n12345678901234567890\n");
	eq(string r.reads(), "123456", "123456");
	r.setsep("\n", 0);
	eq(string r.reads(), "123456\n", "123456\\n");
	{ r.reads(); } exception e { "*" => catched(e); }
	raised("iobuf:no separator found in full buffer", nil);
}

