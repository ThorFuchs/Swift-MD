# Linux supervised worker

`Scripts/run-linux-supervised.py` is an **opt-in outer worker** for trusted
executables that process potentially untrusted input. Core and the Node adapter
APIs do not depend on it. It requires Linux, Python 3, `waitid(WNOWAIT)` and
permission to create processes and apply `RLIMIT_AS` and `RLIMIT_FSIZE`.

```sh
python3 Scripts/run-linux-supervised.py \
  --seconds 30 --memory-mib 8192 --file-mib 8 \
  --input-bytes 1000000 --output-bytes 2000000 --error-bytes 65536 -- \
  /absolute/path/to/swift-md --strict --highlight < input.md > output.html
```

An operator can add the documented trusted absolute Node/module options for
KaTeX and Pele. Supply input on stdin and capture the supervisor's stdout; do
not use `swift-md --output` or a worker input filename when relying on the
stream limits. File paths and commands passed to the worker, its environment,
Node executable and modules are trusted configuration. The shell redirection
in the example is performed by the invoking shell; use a temporary file plus
atomic rename if an existing destination must be preserved on failure.

The supervisor enforces a wall-clock deadline including stdin, byte limits on
stdin and both output streams while they are transferred, and per-process
address-space and individual-file-size limits inherited by ordinary children.
It buffers bounded stdout until the worker exits successfully; a worker failure,
interruption, deadline or stream overflow before delivery emits no stdout.
The deadline also applies when delivering completed output to a slow reader.
Once delivery starts, a broken or stalled downstream can still receive only a
prefix; stream writes are not transactional. Use an atomic file replacement
at the caller when all-or-nothing file output is required.
On a failure it sends SIGKILL to the worker's process group and waits up to one
second to reap its direct child. A process stuck in uninterruptible kernel work
may outlive that cleanup wait; synchronous process creation itself is not
deadline-interruptible. Exit 124 is used for a deadline and 125 for a
supervisor/limit error, but a worker can itself return those same codes; other
worker exit codes are propagated. Captured worker diagnostics are sent to
stderr when the worker itself fails; overflow and supervisor failures report
their own error. This applies only to stdout/stderr passing through the wrapper.

This is **not a security sandbox**. The resource limits are per process, not
an aggregate memory or filesystem quota. A descendant can deliberately enter a
new session, escape the process group and remain alive; the worker can access
whatever filesystem, network, credentials and privileges its account permits.
The supervisor inherits its environment, including Node-related variables.
Killing the supervisor itself with SIGKILL or a host crash cannot trigger
cleanup. A worker that writes files or opens its own network connections
bypasses the stream policy. Use a separately configured and tested OS sandbox
with cgroup v2 limits, restricted credentials, filesystem and network policies
for hostile executables or stronger tenant isolation. Do not infer those
properties from `RLIMIT_AS`, `RLIMIT_FSIZE`, or a process-group timeout.

The Linux CI gate runs boundary tests and an end-to-end CLI invocation with
real Swift highlighting, KaTeX and Pele. The existing legacy
`run-linux-constrained.sh` remains available with its narrower contract; the
two helpers do not silently wrap normal SwiftMD calls. Recheck behavior and
limits on the target host before relying on the worker in a deployment.
