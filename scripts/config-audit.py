import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from audit_code import check_entry_wrappers, check_python_scripts, check_script_pairs, check_test_inline_python, check_settings, check_shell_scripts, check_template_scripts, check_template_tokens, check_worktree_literals  # noqa: E402
from audit_docs import check_anchors, check_docs, check_ledger, check_links, check_paths, check_readme, check_readme_flow  # noqa: E402
from audit_names import check_names, check_prefixes, check_script_verbs, check_terms, check_test_pairs  # noqa: E402
from audit_skills import check_agents, check_claude_templates, check_rules, check_skill_fields, check_skill_references, check_skill_steps, check_skill_unused  # noqa: E402
from loader import ROOT  # noqa: E402
from script_io import run_main  # noqa: E402


CHECKS = [
    check_skill_fields,
    check_skill_steps,
    check_skill_references,
    check_skill_unused,
    check_claude_templates,
    check_template_scripts,
    check_template_tokens,
    check_agents,
    check_rules,
    check_settings,
    check_prefixes,
    check_script_verbs,
    check_names,
    check_test_pairs,
    check_shell_scripts,
    check_python_scripts,
    check_entry_wrappers,
    check_script_pairs,
    check_test_inline_python,
    check_worktree_literals,
    check_readme,
    check_readme_flow,
    check_terms,
    check_links,
    check_anchors,
    check_paths,
    check_ledger,
    check_docs,
]


def main():
    problems = [f"NG {os.path.relpath(path, ROOT)}:{line} {message}" for check in CHECKS for path, line, message in check()]
    if problems:
        print("\n".join(problems))
        print(f"NG config-audit: {len(problems)} 件")
        sys.exit(1)
    print("OK config-audit")


if __name__ == "__main__":
    run_main(main)
