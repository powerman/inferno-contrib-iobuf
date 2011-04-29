
send(cmd: chan of string, op, param: string)
{
	cmd <-= str->quoted(op :: param :: nil);
}

new_fd2buf(rbufsize: int): (chan of string, ref ReadBuf)
{
	pipe := array[2] of ref Sys->FD;
	if(sys->pipe(pipe) == -1)
		raise sprint("pipe:%r");

	cmd := chan[16] of string;
	spawn write_fd(cmd, pipe[0]);
	<-cmd;

	r := ReadBuf.new(pipe[1], rbufsize);
	if(r == nil)
		raise "ReadBuf.new";

	return (cmd, r);
}

new_buf2fd(wbufsize: int): (chan of string, ref Sys->FD)
{
	pipe := array[2] of ref Sys->FD;
	if(sys->pipe(pipe) == -1)
		raise sprint("pipe:%r");

	w := WriteBuf.new(pipe[0], wbufsize);
	if(w == nil)
		raise "WriteBuf.new";

	cmd := chan[16] of string;
	spawn write_buf(cmd, w);
	<-cmd;

	return (cmd, pipe[1]);
}

new_buf2buf(wbufsize, rbufsize: int): (chan of string, ref ReadBuf)
{
	(cmd, fd) := new_buf2fd(wbufsize);

	r := ReadBuf.new(fd, rbufsize);
	if(r == nil)
		raise "ReadBuf.new";

	return (cmd, r);
}

write_fd(cmd: chan of string, fd: ref Sys->FD)
{
	cmd <-= string sys->pctl(0, nil);
	for(;;){
		l := str->unquoted(<-cmd);
		(op, param) := (hd l, hd tl l);
		case op{
		"stop" =>	exit;
		"sleep"	=>	sys->sleep(int param);
		"write"	=>	a := array of byte param;
				sys->write(fd, a, len a);
		* =>		diag("unknown cmd: "+op);
		}
	}
}

write_buf(cmd: chan of string, w: ref WriteBuf)
{
	cmd <-= string sys->pctl(0, nil);
	for(;;){
		l := str->unquoted(<-cmd);
		(op, param) := (hd l, hd tl l);
		case op{
		"stop" =>	exit;
		"sleep"	=>	sys->sleep(int param);
		"write"	=>	w.write(array of byte param);
		"flush" =>	w.flush();
		* =>		diag("unknown cmd: "+op);
		}
	}
}

