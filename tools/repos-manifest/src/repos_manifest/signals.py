"""Stop signals: SIGINT, SIGTERM and SIGHUP end a run through an exception, so that the
`finally` blocks that remove the run's temporaries run, and the run says how far it got."""

from __future__ import annotations

import signal
import sys
from contextlib import contextmanager


class Stopped(BaseException):
    """SIGINT, SIGTERM or SIGHUP arrived during the run."""

    def __init__(self, signum: int):
        super().__init__(signum)
        self.signum = signum


@contextmanager
def signals_end_the_run():
    """While in this context, SIGINT, SIGTERM and SIGHUP raise `Stopped`. A signal that was
    ignored stays ignored."""
    previous = {}

    def on_signal(signum, _frame):
        raise Stopped(signum)

    for name in ("SIGINT", "SIGTERM", "SIGHUP"):
        sig = getattr(signal, name, None)
        if sig is None or signal.getsignal(sig) in (signal.SIG_IGN, None):
            continue
        try:
            previous[sig] = signal.signal(sig, on_signal)
        except ValueError:  # not the main thread: signals cannot be caught here
            pass
    try:
        yield
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def signal_name(exc: Stopped) -> str:
    return signal.Signals(exc.signum).name


def stop_exit(exc: Stopped, message: str) -> int:
    """Print `message` and end the run as the signal would: called after the context above has
    put the previous handlers back. Returns the exit status, 128 + the signal."""
    try:
        print(f"ERROR: {message}", file=sys.stderr)
    except (OSError, ValueError):
        pass  # a terminal that hung up, a closed pipe: the signal still ends the run
    # Output to a file or a pipe is buffered, and the signal's default action does not flush it.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.flush()
        except (OSError, ValueError):  # closed, or a broken pipe: nothing more can be written
            pass
    # The previous handlers are back: the signal is delivered again, to end the process as it
    # would have or to run the caller's own handler. Python's own SIGINT handler would raise
    # KeyboardInterrupt and print a traceback; the message above says it all.
    if signal.getsignal(exc.signum) is not signal.default_int_handler:
        signal.raise_signal(exc.signum)
    return 128 + exc.signum
