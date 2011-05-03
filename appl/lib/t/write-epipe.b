implement T;

include "opt/powerman/tap/module/t.m";
include "../../../module/iobuf.m";
	iobuf: IOBuf;
	ReadBuf, WriteBuf: import iobuf;
include "./share.m";

test()
{
	plan(9);

	iobuf = load IOBuf IOBuf->PATH;
	if(iobuf == nil)
		bail_out(sprint("load %s: %r",IOBuf->PATH));
	iobuf->init();
	
	w: ref WriteBuf;
	rc := chan[16] of (array of byte, string);
	data: array of byte;
	err: string;

	w = WriteBuf.newc(16);

	w.request(Sys->ATOMICIO, rc);
	w.write(array of byte "123");
	(data, err) = <-rc;
	eq(string data, "123", nil);
	eq(err, nil, "no error");

	w.request(0, nil);
	{ w.request(0, nil); } exception e { "*" => catched(e); }
	raised(nil, nil);

	w.request(0, nil);
	{ w.writeln(array of byte "456"); } exception e { "*" => catched(e); }
	raised("iobuf:broken pipe", nil);

	w.request(0, nil);
	{ w.flush(); } exception e { "*" => catched(e); }
	raised("iobuf:broken pipe", nil);

	w.request(0, nil);
	{ w.eof(); } exception e { "*" => catched(e); }
	raised("iobuf:broken pipe", nil);

	w.request(Sys->ATOMICIO, rc);
	w.flush();
	(data, err) = <-rc;
	eq(string data, "456", "got '456', without '\\n' because of EPIPE");
	eq(err, nil, "no error");

	w.request(0, nil);
	{ w.eof(); } exception e { "*" => catched(e); }
	raised(nil, nil);
}
