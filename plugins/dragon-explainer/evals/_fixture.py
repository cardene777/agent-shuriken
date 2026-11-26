"""Writes the starting state of a dragon-explainer eval case into the current folder.

Usage: python3 _fixture.py <mode>

  project  queue-lite, a small Node.js job queue with retries, for the explainer to describe
  fix      project, plus docs/explainers/queue-lite/ holding a content JSON whose Retries
           section has no figure and the HTML built from it, so check.py fails on that section

Everything is written below the current folder, which is the run's workspace.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(HERE, "..", "skills", "dragon-explainer", "scripts")

PACKAGE = {
    "name": "queue-lite",
    "version": "0.3.0",
    "description": "An in-memory job queue that retries failed jobs with a growing delay",
    "main": "src/queue.js",
    "license": "MIT",
}

README = """# queue-lite

An in-memory job queue for small Node.js services.
A producer adds jobs, a worker runs them one at a time, and a job that throws is retried
after 1 second and then after 2 seconds. On its third failure the job moves to the dead-letter list.

```js
const { Queue } = require("queue-lite");
const { startWorker } = require("queue-lite/src/worker");

const queue = new Queue();
queue.enqueue("send-email", { to: "someone@example.com" });
startWorker(queue, { "send-email": async (payload) => { /* ... */ } });
```
"""

QUEUE_JS = """// An in-memory job queue. A job moves waiting -> running -> done, or back to waiting
// with a delay when it fails, until it has failed MAX_ATTEMPTS times and is marked failed.
const MAX_ATTEMPTS = 3;
const BACKOFF_MS = [1000, 2000];

class Queue {
  constructor() {
    this.jobs = [];
    this.dead = [];
    this.nextId = 1;
  }

  enqueue(name, payload) {
    const job = { id: this.nextId++, name, payload, state: "waiting", attempts: 0, runAt: 0 };
    this.jobs.push(job);
    return job;
  }

  // The oldest waiting job whose delay has passed, marked running.
  next(now = Date.now()) {
    const job = this.jobs.find((j) => j.state === "waiting" && j.runAt <= now);
    if (job) job.state = "running";
    return job;
  }

  complete(job) {
    job.state = "done";
  }

  fail(job, error, now = Date.now()) {
    job.attempts += 1;
    job.lastError = String(error);
    if (job.attempts >= MAX_ATTEMPTS) {
      job.state = "failed";
      this.dead.push(job);
    } else {
      retryJob(job, now);
    }
  }
}

// Puts a failed job back in line after the delay for its attempt.
function retryJob(job, now) {
  job.state = "waiting";
  job.runAt = now + BACKOFF_MS[job.attempts - 1];
}

module.exports = { Queue, retryJob, MAX_ATTEMPTS, BACKOFF_MS };
"""

WORKER_JS = """// Runs the jobs of a queue one at a time with the handler registered for each job name.
const { retryJob } = require("./queue");

function startWorker(queue, handlers, intervalMs = 200) {
  const timer = setInterval(async () => {
    const job = queue.next();
    if (!job) return;
    const handler = handlers[job.name];
    if (!handler) {
      job.attempts = 0;
      retryJob(job, Date.now());
      return;
    }
    try {
      await handler(job.payload);
      queue.complete(job);
    } catch (error) {
      queue.fail(job, error);
    }
  }, intervalMs);
  return () => clearInterval(timer);
}

module.exports = { startWorker };
"""

FLOW_CSS = (
    "container-type: inline-size; .row { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; }"
    " .node { padding: 12px 14px; background: var(--panel); border: 1px solid var(--line-2); border-radius: var(--radius); }"
    " .node b { display: block; color: var(--ink); } .node small { display: block; margin-top: 4px; color: var(--ink-3); }"
)


def node(title, note):
    return '<div class="node"><b>%s</b><small>%s</small></div>' % (title, note)


CONTENT = {
    "lang": "en",
    "title": "How the queue-lite job queue works",
    "lead": "queue-lite keeps jobs in memory, runs them one at a time, and retries a failed job after a growing delay.",
    "tabs": [{
        "id": "a",
        "label": "Queue",
        "title": "How the queue-lite job queue works",
        "lead": "A producer adds jobs, a worker runs them, and failed jobs wait before they run again.",
        "sections": [
            {
                "id": "a-s1",
                "title": "What the queue does",
                "blocks": [
                    {"type": "paragraph", "text": "A producer adds a job with a name and a payload. The queue keeps the job in a list, and the worker takes the oldest waiting job and runs the handler registered for its name."},
                    {"type": "html", "id": "a-parts", "caption": "Figure 1 The producer, the queue, and the worker",
                     "html": '<div class="row">%s%s%s</div>' % (
                         node("Producer", "adds a job with a name and a payload"),
                         node("Queue", "keeps every job and its state"),
                         node("Worker", "runs one job at a time")),
                     "css": FLOW_CSS},
                ],
            },
            {
                "id": "a-s2",
                "title": "A job's states",
                "blocks": [
                    {"type": "paragraph", "text": "A new job is waiting. The worker marks it running, then done when the handler returns. When the handler throws, the job goes back to waiting, and after its third failure it is marked failed and moves to the dead-letter list."},
                    {"type": "html", "id": "a-states", "caption": "Figure 2 How a job moves between its states",
                     "html": '<div class="row">%s%s%s%s</div>' % (
                         node("Waiting", "added, or back after a failure"),
                         node("Running", "the worker took it"),
                         node("Done", "the handler returned"),
                         node("Failed", "the third failure, kept in the dead-letter list")),
                     "css": FLOW_CSS},
                ],
            },
            {
                "id": "a-s3",
                "title": "Retries",
                "blocks": [
                    {"type": "paragraph", "text": "When a handler throws, the queue counts the attempt and puts the job back in line with a delay. The delay is 1 second after the first failure and 2 seconds after the second. The third failure ends the job."},
                    {"type": "paragraph", "text": "A job whose name has no handler goes back to waiting with its attempts reset, so it runs again once a handler is registered."},
                ],
            },
            {
                "id": "a-s4",
                "title": "Terms",
                "nofigure": "A glossary only",
                "blocks": [
                    {"type": "keys", "items": [
                        {"term": "Job", "text": "One unit of work with a name and a payload"},
                        {"term": "Handler", "text": "The function that runs the jobs of one name"},
                        {"term": "Dead-letter list", "text": "The jobs that failed three times"},
                    ]},
                ],
            },
        ],
    }],
}


def write(path, text):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def project():
    write("package.json", json.dumps(PACKAGE, indent=2) + "\n")
    write("README.md", README)
    write("src/queue.js", QUEUE_JS)
    write("src/worker.js", WORKER_JS)


def run(script, *args):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    subprocess.run([sys.executable, os.path.join(SCRIPTS, script), *args], check=True,
                   stdout=subprocess.DEVNULL, env=env)


def fix():
    project()
    folder = os.path.join("docs", "explainers", "queue-lite")
    content = os.path.join(folder, "content.json")
    body = os.path.join(folder, "body.html")
    write(content, json.dumps(CONTENT, indent=2) + "\n")
    run("render.py", "--in", content, "--out", body)
    run("build.py", "--in", body, "--out", os.path.join(folder, "queue-lite.html"))
    os.remove(body)


MODES = {"project": project, "fix": fix}

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in MODES:
        sys.exit("usage: _fixture.py project|fix")
    MODES[sys.argv[1]]()
