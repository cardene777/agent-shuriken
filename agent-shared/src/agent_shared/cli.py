"""Command line of agent-shared."""

import argparse
import sys

from agent_shared import __version__
from agent_shared.deploy import Refused, Usage, deploy, hooks

DESCRIPTION = """\
Deploy the skills, rules, and hooks in ~/.shared (and in a repository's .shared) to Claude Code,
Codex, and the other agents in the agent table. Skills and rules are linked, so every agent reads
the one copy in the source folder. Only what agent-shared placed is changed or removed later."""

HOOKS_DESCRIPTION = """\
Print, as JSON, the hook groups deploy adds to one agent's hook file, with agent-shared's mark and
the source folder filled in. Nothing is written, so a guard can compare the agent's hook file with it."""

HOOKS_EPILOG = """\
exit status:
  0  printed
  2  the command line, a source folder, the agent name, or the agent table could not be used"""

EPILOG = """\
exit status:
  0  deployed (warnings, such as Codex hooks left to trust by hand, are printed)
  1  refused: nothing was written, and each reason is printed
  2  the command line, a source folder, or the agent table could not be used

environment:
  AGENT_SHARED_STATE      folder for the record of placed items (default ~/.local/share/agent-shared)
  AGENT_SHARED_CODEX_BIN  the codex command that writes Codex's hook trust (default codex)"""


def parser():
    top = argparse.ArgumentParser(prog="agent-shared", description=DESCRIPTION, epilog=EPILOG,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    top.add_argument("--version", action="version", version="agent-shared " + __version__)
    commands = top.add_subparsers(dest="command", metavar="command")
    run = commands.add_parser("deploy", help="place skills, rules, and hooks in every agent",
                              description=DESCRIPTION, epilog=EPILOG,
                              formatter_class=argparse.RawDescriptionHelpFormatter)
    run.add_argument("--source", action="append", default=[], metavar="DIR",
                     help="another folder with the .shared layout, deployed together with ~/.shared")
    run.add_argument("--repo", metavar="DIR",
                     help="the repository whose .shared skills are linked into its own folders "
                          "(default: the repository that holds the current folder)")
    show = commands.add_parser("hooks", help="print the hooks deploy adds for one agent, writing nothing",
                               description=HOOKS_DESCRIPTION, epilog=HOOKS_EPILOG,
                               formatter_class=argparse.RawDescriptionHelpFormatter)
    show.add_argument("--agent", required=True, metavar="NAME",
                      help='the agent, as named in the agent table (for example "Claude Code" or Codex)')
    show.add_argument("--source", action="append", default=[], metavar="DIR",
                      help="another folder with the .shared layout, read together with ~/.shared")
    return top


def main(argv=None):
    args = parser().parse_args(argv)
    if args.command not in ("deploy", "hooks"):
        parser().print_help()
        return 2
    try:
        if args.command == "hooks":
            return hooks(args.agent, args.source)
        return deploy(args.source, args.repo)
    except Refused as error:
        for line in error.lines:
            print("refused: " + line)
        print("Nothing was written.")
        return 1
    except Usage as error:
        print("error: " + str(error), file=sys.stderr)
        return 2
    except BrokenPipeError:
        return 141
