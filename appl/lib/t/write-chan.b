implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;
include "./share.m";

test()
{
	plan(19);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();
	
	cmd: Cmd;
	w: ref WriteBuf;
	readc := chan[16] of array of byte;

	# write:
	# - few small writes does not result in flush()
	# - next write result in flush()
	#   * write only completely fill buffer
	#   * write overload buffer
	# - flush writes leftover of previous write overloaded buffer
	# - flush empty buffer

	(cmd, w) = new_buf2chan(16);

	send(cmd, "write", "1234");
	send(cmd, "write", "12345");
	send(cmd, "write", "123456");
	spawn reader(50, w, readc);
	sys->sleep(100);
	alt{
	<-readc =>	ok(0, "few small writes does not result in flush");
	* =>		ok(1, "few small writes does not result in flush");
	}
	send(cmd, "write", "!");
	eq(string <-readc, "123412345123456!", nil);

	send(cmd, "write", "abcdef");
	send(cmd, "write", "1234567890!");
	reader(50, w, readc);
	eq(string <-readc, "abcdef1234567890", nil);

	send(cmd, "flush", nil);
	reader(50, w, readc);
	eq(string <-readc, "!", nil);

	send(cmd, "flush", nil);
	spawn reader(50, w, readc);
	sys->sleep(100);
	alt{
	<-readc =>	ok(0, "flush empty buffer do nothing");
	* =>		ok(1, "flush empty buffer do nothing");
	}

	send(cmd, "stop", nil);

	# large write:
	# - buffer empty, write n*bufsize written at once
	# - buffer not empty, write n*bufsize written as bufsize + (n-1)*bufsize
	# - flush writes leftover of previous write overloaded buffer
	# - buffer empty, write n*bufsize+k written as n*bufsize
	# - flush writes leftover of previous write overloaded buffer
	
	(cmd, w) = new_buf2chan(5);
	readc = chan[16] of array of byte;

	send(cmd, "write", "1234567890abcde");
	reader(50, w, readc);
	eq(string <-readc, "1234567890abcde", nil);

	send(cmd, "write", "zxc");
	send(cmd, "write", "1234567890abcde");
	reader(50, w, readc);
	eq(string <-readc, "zxc12", nil);
	reader(50, w, readc);
	eq(string <-readc, "34567890ab", nil);
	spawn reader(50, w, readc);
	sys->sleep(100);
	alt{
	<-readc =>	ok(0, "only n*bufsize bytes readed");
	* =>		ok(1, "only n*bufsize bytes readed");
	}

	send(cmd, "flush", nil);
	eq(string <-readc, "cde", nil);

	send(cmd, "write", "1234567890abcdefgh");
	reader(50, w, readc);
	eq(string <-readc, "1234567890abcde", nil);
	spawn reader(50, w, readc);
	sys->sleep(100);
	alt{
	<-readc =>	ok(0, "only n*bufsize bytes readed");
	* =>		ok(1, "only n*bufsize bytes readed");
	}

	send(cmd, "flush", nil);
	eq(string <-readc, "fgh", nil);

	# latency optimization:
	# - write should return incomplete buffer if there is pending request

	spawn reader2(50, w, readc);
	sys->sleep(50);
	send(cmd, "write", "abc");
	eq(string <-readc, "abc", nil);

	spawn reader2(50, w, readc);
	sys->sleep(50);
	send(cmd, "write", "1");
	eq(string <-readc, "1", nil);

	# read size:
	# - flush shouldn't return more than requested bytes

	send(cmd, "flush", nil);
	send(cmd, "write", "1234567890abcde");
	reader(3, w, readc);
	eq(string <-readc, "123", nil);
	reader(4, w, readc);
	eq(string <-readc, "4567", nil);
	reader(6, w, readc);
	eq(string <-readc, "890abc", nil);
	reader(2, w, readc);
	eq(string <-readc, "de", nil);
}

reader(n: int, w: ref WriteBuf, readc: chan of array of byte)
{
	sys->sleep(50); # work around latency optimization in w.write()
	reader2(n, w, readc);
}

reader2(n: int, w: ref WriteBuf, readc: chan of array of byte)
{
	rc := chan of (array of byte, string);
	w.request(n, rc);
	readc <-= (<-rc).t0;
}
