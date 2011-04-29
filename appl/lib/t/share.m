Cmd: type chan of list of string;

send(cmd: Cmd, op, param: string)
{
	cmd <-= op :: param :: nil;
}

new_chan2buf(queuesize, rbufsize: int): (Cmd, ref ReadBuf, Sys->Rwrite)
{
	r := ReadBuf.newc(queuesize, rbufsize);
	if(r == nil)
		raise "ReadBuf.new";

	wc := chan of (int, string);

	cmd := chan[16] of list of string;
	spawn write_chan(cmd, r, wc);
	<-cmd;

	return (cmd, r, wc);
}

new_fd2buf(rbufsize: int): (Cmd, ref ReadBuf)
{
	pipe := array[2] of ref Sys->FD;
	if(sys->pipe(pipe) == -1)
		raise sprint("pipe:%r");

	cmd := chan[16] of list of string;
	spawn write_fd(cmd, pipe[0]);
	<-cmd;

	r := ReadBuf.new(pipe[1], rbufsize);
	if(r == nil)
		raise "ReadBuf.new";

	return (cmd, r);
}

new_buf2fd(wbufsize: int): (Cmd, ref Sys->FD)
{
	pipe := array[2] of ref Sys->FD;
	if(sys->pipe(pipe) == -1)
		raise sprint("pipe:%r");

	w := WriteBuf.new(pipe[0], wbufsize);
	if(w == nil)
		raise "WriteBuf.new";

	cmd := chan[16] of list of string;
	spawn write_buf(cmd, w);
	<-cmd;

	return (cmd, pipe[1]);
}

new_buf2chan(wbufsize: int): (Cmd, ref WriteBuf)
{
	w := WriteBuf.newc(wbufsize);
	if(w == nil)
		raise "WriteBuf.new";

	cmd := chan[16] of list of string;
	spawn write_buf(cmd, w);
	<-cmd;

	return (cmd, w);
}

new_buf2buf(wbufsize, rbufsize: int): (Cmd, ref ReadBuf)
{
	(cmd, fd) := new_buf2fd(wbufsize);

	r := ReadBuf.new(fd, rbufsize);
	if(r == nil)
		raise "ReadBuf.new";

	return (cmd, r);
}

write_fd(cmd: Cmd, fd: ref Sys->FD)
{
	cmd <-= string sys->pctl(0, nil) :: nil;
	for(;;){
		l := <-cmd;
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

write_buf(cmd: Cmd, w: ref WriteBuf)
{
	cmd <-= string sys->pctl(0, nil) :: nil;
	for(;;){
		l := <-cmd;
		(op, param) := (hd l, hd tl l);
		case op{
		"stop" =>	w.flush();
				exit;
		"sleep"	=>	sys->sleep(int param);
		"write"	=>	w.write(array of byte param);
		"flush" =>	w.flush();
		* =>		diag("unknown cmd: "+op);
		}
	}
}

write_chan(cmd: Cmd, r: ref ReadBuf, wc: Sys->Rwrite)
{
	cmd <-= string sys->pctl(0, nil) :: nil;
	for(;;){
		l := <-cmd;
		(op, param) := (hd l, hd tl l);
		case op{
		"stop" =>	r.fill(nil, nil);
				exit;
		"sleep"	=>	sys->sleep(int param);
		"write"	=>	r.fill(array of byte param, wc);
		* =>		diag("unknown cmd: "+op);
		}
	}
}

