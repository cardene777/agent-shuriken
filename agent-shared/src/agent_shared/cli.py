"""Command line of agent-shared."""

import argparse
import sys

from agent_shared import __version__
from agent_shared.deploy import Refused, Usage, deploy, hooks, placed, switch

DESCRIPTION = """\
Deploy the skills, rules, and hooks in ~/.shared (and in a repository's .shared) to Claude Code,
Codex, and the other agents in the agent table. Skills and rules are linked, so every agent reads
the one copy in the source folder. Only what agent-shared placed is changed or removed later.
A rule or hook switched off for an agent with `agent-shared off` (kept in off.json beside the
record) is left out of that agent by every deploy until `agent-shared on` switches it on again."""

SWITCH_DESCRIPTION = """\
Switch one rule or hook of a source folder off or on for one agent. The choice is kept in the switch
list off.json, beside the record, readable only by the user; nothing is placed until the next deploy,
which leaves a switched-off item out of that agent and takes it out where it was placed before.
`deploy`, `hooks`, and `placed` read the list on every run, and refuse with exit 2, writing nothing,
when off.json cannot be read.

ITEM is a path inside the source folder: a rule file (rules/<name>.md), a file that hook commands run
(hooks/...; every command that runs it is left out), or, for a hook that runs no file, its whole
command as hooks.json declares it. The source folder itself is never written."""

SWITCH_EPILOG = """\
off.json:
  {"version": 1, "off": [{"source": "<folder>", "agent": "<name>", "item": "<item>"}]}
  kept in AGENT_SHARED_STATE (default ~/.local/share/agent-shared); write it only with off and on

exit status:
  0  switched (or already in that state)
  2  the command line, the source folder, the agent, the item, or off.json could not be used"""

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
  2  the command line, a source folder, the agent table, or off.json could not be used

environment:
  AGENT_SHARED_STATE      folder for the record of placed items and the switch list off.json
                          (default ~/.local/share/agent-shared)
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
    for name, verb in (("off", "leave one rule or hook of a source out of one agent"),
                       ("on", "place a switched-off rule or hook in that agent again")):
        turn = commands.add_parser(name, help=verb + " at the next deploy", description=SWITCH_DESCRIPTION,
                                   epilog=SWITCH_EPILOG, formatter_class=argparse.RawDescriptionHelpFormatter)
        turn.add_argument("--source", required=True, metavar="DIR",
                          help="the source folder that holds the item, for example ~/.shared")
        turn.add_argument("--agent", required=True, metavar="NAME",
                          help='the agent, as named in the agent table (for example "Claude Code" or Codex)')
        turn.add_argument("item", metavar="ITEM", help="rules/<name>.md, a hook file, or a hook command")
    return top


def main(argv=None):
    args = parser().parse_args(argv)
    if args.command not in ("deploy", "hooks", "placed", "off", "on"):
        parser().print_help()
        return 2
    try:
        if args.command == "hooks":
            return hooks(args.agent, args.source)
        if args.command == "placed":
            return placed(args.source)
        if args.command in ("off", "on"):
            return switch(args.source, args.agent, args.item, on=args.command == "on")
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
