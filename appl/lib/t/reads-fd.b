implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;
include "string.m";
	str: String;
include "./share.m";

test()
{
	plan(30);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();
	
	str = load String String->PATH;
	if(str == nil)
		bail_out(sprint("load %s: %r",String->PATH));

	cmd: chan of string;
	r: ref ReadBuf;
	a: array of byte;

	# separators:
	# - default
	# - empty
	# - single-byte
	#   * stripped
	#   * non-stripped
	# - multi-byte
	# - optional separator before EOF
	# - no separator found in full buffer
	
	(cmd, r) = new_fd2buf(16);

	send(cmd, "write", "line 1\nline 2\nline 3\nline 4\n");
	eq(string r.reads(), "line 1", nil);
	eq(string r.reads(), "line 2", nil);

	{ r.setsep("", 1); } exception e { "*" => catched(e); }
	raised("iobuf:empty separator", nil);

	r.setsep("\n", 0);
	eq(string r.reads(), "line 3\n", nil);
	eq(string r.reads(), "line 4\n", nil);

	send(cmd, "write", "12345678901234567890");
	r.setsep("56", 0);
	{ r.reads(); } exception e { "*" => catched(e); }
	raised("iobuf:multibyte separator not implemented yet", nil);

	send(cmd, "stop", nil);
	r.setsep("7", 0);
	eq(string r.reads(), "1234567", nil);
	eq(string r.reads(), "8901234567", nil);
	eq(string r.reads(), "890", "890 (no separator before EOF)");
	ok(r.reads() == nil, "EOF");

	(cmd, r) = new_fd2buf(16);
	send(cmd, "write", "12345678901234567");
	send(cmd, "stop", nil);
	r.setsep("7", 0);
	eq(string r.reads(), "1234567", nil);
	eq(string r.reads(), "8901234567", nil);
	ok(r.reads() == nil, "EOF");

	(cmd, r) = new_fd2buf(16);
	send(cmd, "write", "12345678901234567");
	{ r.reads(); } exception e { "*" => catched(e); }
	raised("iobuf:no separator found in full buffer", nil);
	send(cmd, "stop", nil);

	# read:
	# - block until read data into buffer
	# - return data from buffer
	# - keep data leftover in buffer and block until read more data
	# - block until got EOF and return data leftover
	# - return EOF on next reads

	(cmd, r) = new_fd2buf(16);

	stopwatch_start();
	send(cmd, "sleep", "100");
	send(cmd, "write", "123456\n7890\n1234567");

	eq(string r.reads(), "123456", nil);
	stopwatch_min(100, "block until read data into buffer");

	eq(string r.reads(), "7890", nil);
	stopwatch_max(50, "return data from buffer");

	send(cmd, "sleep", "100");
	send(cmd, "write", "890\n1234567");
	eq(string r.reads(), "1234567890", "keep data leftover in buffer");
	stopwatch_min(100, "block until read more data");

	send(cmd, "write", "\n\n890");
	eq(string r.reads(), "1234567", nil);
	stopwatch_max(50, "return data from buffer");
	a = r.reads();
	ok(a != nil, "not EOF");
	eq(string a, "", nil);
	stopwatch_max(50, "return data from buffer");

	send(cmd, "sleep", "100");
	send(cmd, "stop", nil);
	a = r.reads();
	ok(a != nil, "not EOF");
	eq(string a, "890", "return data leftover");
	stopwatch_min(100, "block until got EOF");

	ok(r.reads() == nil, "EOF");
	ok(r.reads() == nil, "EOF again");
}

