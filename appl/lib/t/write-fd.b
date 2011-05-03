implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;
include "./share.m";

test()
{
	plan(16);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();
	
	cmd: Cmd;
	fd: ref Sys->FD;
	readc := chan[16] of array of byte;

	# write:
	# - few small writes does not result in flush()
	# - next write result in flush()
	#   * write only completely fill buffer
	#   * write overload buffer
	# - flush writes leftover of previous write overloaded buffer
	# - flush empty buffer

	(cmd, fd) = new_buf2fd(16);
	spawn reader(fd, readc);

	send(cmd, "write", "1234");
	send(cmd, "write", "12345");
	send(cmd, "write", "123456");
	sys->sleep(100);
	alt{
	<-readc =>	ok(0, "few small writes does not result in flush");
	* =>		ok(1, "few small writes does not result in flush");
	}
	send(cmd, "write", "!");
	eq(string <-readc, "123412345123456!", nil);

	send(cmd, "write", "abcdef");
	send(cmd, "write", "1234567890!");
	eq(string <-readc, "abcdef1234567890", nil);

	send(cmd, "flush", nil);
	eq(string <-readc, "!", nil);

	send(cmd, "flush", nil);
	sys->sleep(100);
	alt{
	<-readc =>	ok(0, "flush empty buffer do nothing");
	* =>		ok(1, "flush empty buffer do nothing");
	}

	send(cmd, "stop", nil);
	eq_int(len <-readc, 0, "EOF");

	# writeln:

	(cmd, fd) = new_buf2fd(16);
	spawn reader(fd, readc);

	send(cmd, "write",   "123");
	send(cmd, "writeln", "456");
	send(cmd, "write",   "789");
	send(cmd, "writeln", "0");
	sys->sleep(100);
	alt{
	<-readc =>	ok(0, "few small writes does not result in flush");
	* =>		ok(1, "few small writes does not result in flush");
	}
	send(cmd, "flush", nil);
	eq(string <-readc, "123456\n7890\n", nil);

	# large write:
	# - buffer empty, write n*bufsize written at once
	# - buffer not empty, write n*bufsize written as bufsize + (n-1)*bufsize
	# - flush writes leftover of previous write overloaded buffer
	# - buffer empty, write n*bufsize+k written as n*bufsize
	# - flush writes leftover of previous write overloaded buffer
	
	(cmd, fd) = new_buf2fd(5);
	spawn reader(fd, readc);

	send(cmd, "write", "1234567890abcde");
	eq(string <-readc, "1234567890abcde", nil);

	send(cmd, "write", "zxc");
	send(cmd, "write", "1234567890abcde");
	eq(string <-readc, "zxc12", nil);
	eq(string <-readc, "34567890ab", nil);
	sys->sleep(100);
	alt{
	<-readc =>	ok(0, "only n*bufsize bytes readed");
	* =>		ok(1, "only n*bufsize bytes readed");
	}

	send(cmd, "flush", nil);
	eq(string <-readc, "cde", nil);

	send(cmd, "write", "1234567890abcdefgh");
	eq(string <-readc, "1234567890abcde", nil);
	sys->sleep(100);
	alt{
	<-readc =>	ok(0, "only n*bufsize bytes readed");
	* =>		ok(1, "only n*bufsize bytes readed");
	}

	send(cmd, "flush", nil);
	eq(string <-readc, "fgh", nil);
}

reader(fd: ref Sys->FD, readc: chan of array of byte)
{
	buf := array[Sys->ATOMICIO] of byte;
	for(;;){
		n := sys->read(fd, buf, len buf);
		if(n < 0){
			diag(sprint("read: %r"));
			raise sprint("fail:read: %r");
		}
		readc <-= buf[:n];
		if(n == 0)
			break;
	}
}
