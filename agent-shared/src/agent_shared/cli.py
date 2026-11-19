"""Command line of agent-shared."""

import argparse
import sys

from agent_shared import __version__
from agent_shared.deploy import Refused, Usage, deploy, hooks, placed

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

PLACED_DESCRIPTION = """\
Print, as JSON, the skills, rules, and hooks one source folder placed in each agent of the agent
table and that are still there. Nothing is written, so an app can list what it deployed without
keeping a second copy of where each agent keeps its files."""

PLACED_EPILOG = """\
exit status:
  0  printed (every agent of the table is named, with empty lists when the source placed nothing)
  2  the command line, the source folder, the agent table, the record, or an agent's file could not be used"""

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
    listed = commands.add_parser("placed", help="print what one source placed in each agent, writing nothing",
                                 description=PLACED_DESCRIPTION, epilog=PLACED_EPILOG,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    listed.add_argument("--source", required=True, metavar="DIR",
                        help="the source folder whose placed items are printed, for example ~/.shared")
    return top


def main(argv=None):
    args = parser().parse_args(argv)
    if args.command not in ("deploy", "hooks", "placed"):
        parser().print_help()
        return 2
    try:
        if args.command == "hooks":
            return hooks(args.agent, args.source)
        if args.command == "placed":
            return placed(args.source)
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
