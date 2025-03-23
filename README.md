# daymin

run a daily task a minute later each day


# To install

```sh
sudo make install
```


# To use

This utility allows command to be periodically executed where the
command must not be executed more than once in 24 hours.  When this
utility is executed via a crontab on at the same time each day:

	0 0 * * * daymin /var/daymin/minfile shell_file

The resulting command and args are executed a minute later each day.
The actual command is delayed by the number of minutes as recorded
in the /var/daymin/minfile contents.

By default, it is an error if the minfile does not exist.  It may
be created by giving the -c flag, in which case the previous value
was assumed to be 0, the command is immediately executed, and the
minfile is left with a value of 1 for next time.

The minfile is assumed to contain a single line containing the
number of minutes for which the command execution should be delayed.
All other minfile contents is ignored and removed when file is
incremented.

The following command is an equivalent way to reset the minfile
(equiavlent to using -c):

	echo 0 > /var/daymin/minfile

If is an error if the minfile does not exit and -c is not used.  So
this crontab line will ensure that the command will be eventually
executed, regardless of the state or non-existence of the minfile:

	0 0 * * * daymin -c /var/daymin/minfile shell_file

A minfile should be used to control the execution time of just one
command.  The effect of doing this:

	0 0 * * * daymin /var/daymin/WRONG /AVOID/REUSING/one/minfile
	0 0 * * * daymin /var/daymin/WRONG /for/multiple/commands!!!

would be to execute the echo commands with a period longer then
the usual day + 1 minute.

The execution delay is accomplished by the at(1) command.  Therefore the
user must be allowed to use at.  See the at(1) man page for details.


# Reporting Security Issues

To report a security issue, please visit "[Reporting Security Issues](https://github.com/lcn2/daymin/security/policy)".
