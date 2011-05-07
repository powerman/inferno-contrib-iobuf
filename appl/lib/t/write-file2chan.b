implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;
include "./share.m";

test()
{
	plan(3);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();
	
	fio := sys->file2chan("/chan", "write-file2chan.t");
	if(fio == nil)
		skip_all(sprint("file2chan: %r"));

	fd := sys->open("/chan/write-file2chan.t", Sys->OREAD);
	if(fd == nil)
		skip_all(sprint("open: %r"));

	spawn client(fd, pidc := chan of int);
	pid := <-pidc;
	fd = nil;

	w := WriteBuf.newc(Sys->ATOMICIO);

	(nil, count, nil, rc) := <-fio.read;
	ok(rc != nil, "got read request");
	w.request(count, rc);

	pidctl(pid, "kill");

	(nil, count, nil, rc) = <-fio.read;
	ok(rc == nil, "got EOF notification");
	w.request(count, rc);

	w.eof();
	ok(1, "eof doesn't hangs");
}

client(fd: ref Sys->FD, pidc: chan of int)
{
	pidc <-= sys->pctl(0, nil);
	buf := array[Sys->ATOMICIO] of byte;
	sys->read(fd, buf, len buf);
}

pidctl(pid: int, s: string): int
{
	f := sprint("#p/%d/ctl", pid);
	fd := sys->open(f, Sys->OWRITE);
	if(fd == nil || sys->fprint(fd, "%s", s) < 0){
		diag(sprint("pidctl(%d, %s): %r", pid, s));
		return 0;
	}
	return 1;
}

