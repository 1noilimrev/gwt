#!/usr/bin/env zsh
# ---------------------------------------------------------------------------------------
# gwt test suite
#
# Usage:
#   ./test_gwt.zsh          Run all tests
#   ./test_gwt.zsh -v       Run with verbose output
#
# Each test follows the #given, #when, #then pattern
# ---------------------------------------------------------------------------------------

# Do not use set -e as it causes early exit on test failures

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

VERBOSE=false
[[ "$1" == "-v" ]] && VERBOSE=true

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_DIR=""
ORIGINAL_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------------------
# Test Utilities
# ---------------------------------------------------------------------------------------

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    # Resolve symlinks (macOS /var -> /private/var)
    TEST_DIR=$(pwd -P)
    
    # Initialize a git repo
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    
    # Create initial commit
    echo "initial" > README.md
    git add README.md
    git commit -m "initial commit" --quiet
    
    # Source gwt
    source "$SCRIPT_DIR/gwt.zsh"
}

teardown() {
    cd "$ORIGINAL_DIR"
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

pass() {
    ((TESTS_PASSED++))
    echo "${GREEN}PASS${NC}: $1"
}

fail() {
    ((TESTS_FAILED++))
    echo "${RED}FAIL${NC}: $1"
    if [[ -n "$2" ]]; then
        echo "       $2"
    fi
}

run_test() {
    local test_name="$1"
    ((TESTS_RUN++))
    
    if $VERBOSE; then
        echo "${YELLOW}RUN${NC}: $test_name"
    fi
    
    setup
    
    local result=0
    eval "$test_name" || result=$?
    
    if [[ $result -eq 0 ]]; then
        pass "$test_name"
    else
        fail "$test_name"
    fi
    
    teardown
}

# ---------------------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------------------

test_version() {
    # given
    # gwt is sourced
    
    # when
    local output
    output=$(gwt --version)
    
    # then
    [[ "$output" == gwt\ * ]] || return 1
}

test_help() {
    # given
    # gwt is sourced
    
    # when
    local output
    output=$(gwt --help 2>&1)
    
    # then
    [[ "$output" == *"USAGE"* ]] || return 1
    [[ "$output" == *"COMMANDS"* ]] || return 1
}

test_add_creates_worktree() {
    # given
    local branch_name="test-branch"
    git branch "$branch_name"
    
    # when
    local output
    output=$(gwt add "$branch_name" 2>&1)
    
    # then
    [[ -d ".git/worktree-workspace/$branch_name" ]] || return 1
}

test_add_is_idempotent() {
    # given
    local branch_name="test-branch"
    git branch "$branch_name"
    gwt add "$branch_name" >/dev/null 2>&1
    cd "$TEST_DIR"  # ensure we're back at git root
    
    # when
    local output
    output=$(gwt add "$branch_name" 2>&1)
    
    # then
    [[ "$output" == *"already exists"* ]] || return 1
    [[ -d ".git/worktree-workspace/$branch_name" ]] || return 1
}

test_add_converts_slash_to_dash() {
    # given
    local branch_name="feature/test"
    git branch "$branch_name"
    
    # when
    gwt add "$branch_name" >/dev/null 2>&1
    cd "$TEST_DIR"  # gwt add changes into worktree, go back to root
    
    # then
    [[ -d ".git/worktree-workspace/feature-test" ]] || return 1
}

test_add_links_env_file() {
    # given
    local branch_name="test-branch"
    git branch "$branch_name"
    echo "SECRET=123" > .env
    
    # when
    gwt add "$branch_name" >/dev/null 2>&1
    cd "$TEST_DIR"  # gwt add changes into worktree, go back to root
    
    # then
    [[ -L ".git/worktree-workspace/$branch_name/.env" ]] || return 1
}

test_ls_lists_worktrees() {
    # given
    local branch_name="test-branch"
    git branch "$branch_name"
    gwt add "$branch_name" >/dev/null 2>&1
    
    # when
    local output
    output=$(gwt ls)
    
    # then
    [[ "$output" == *"$branch_name"* ]] || return 1
}

test_ls_with_no_worktrees() {
    # given
    # no worktrees created
    
    # when
    local output
    output=$(gwt ls)
    
    # then
    # should show at least the main worktree
    [[ "$output" == *"[main]"* ]] || [[ "$output" == *"[master]"* ]] || return 1
}

test_path_returns_worktree_path() {
    # given
    local branch_name="test-branch"
    git branch "$branch_name"
    gwt add "$branch_name" >/dev/null 2>&1
    cd "$TEST_DIR"  # gwt add changes into worktree, go back to root
    
    # when
    local output
    output=$(gwt path "$branch_name")
    
    # then
    [[ "$output" == *".git/worktree-workspace/$branch_name" ]] || return 1
}

test_path_fails_for_nonexistent() {
    # given
    # no worktree created
    
    # when
    local output
    output=$(gwt path "nonexistent" 2>&1)
    local exit_code=$?
    
    # then
    [[ $exit_code -ne 0 ]] || return 1
    [[ "$output" == *"not found"* ]] || return 1
}

test_cd_changes_to_worktree() {
    # given
    local branch_name="test-branch"
    git branch "$branch_name"
    gwt add "$branch_name" >/dev/null 2>&1
    cd "$TEST_DIR"  # gwt add changes into worktree, go back to root
    local expected_path="$TEST_DIR/.git/worktree-workspace/$branch_name"
    
    # when
    gwt cd "$branch_name"
    local current_dir="$(pwd)"
    
    # then
    [[ "$current_dir" == "$expected_path" ]] || return 1
}

test_cd_fails_for_nonexistent() {
    # given
    # no worktree created
    
    # when
    local output
    output=$(gwt cd "nonexistent" 2>&1)
    local exit_code=$?
    
    # then
    [[ $exit_code -ne 0 ]] || return 1
}

test_rm_removes_worktree() {
    # given
    local branch_name="test-branch"
    git branch "$branch_name"
    gwt add "$branch_name" >/dev/null 2>&1
    
    # when
    gwt rm "$branch_name" >/dev/null 2>&1
    
    # then
    [[ ! -d ".git/worktree-workspace/$branch_name" ]] || return 1
}

test_rm_fails_for_nonexistent() {
    # given
    # no worktree created
    
    # when
    local output
    output=$(gwt rm "nonexistent" 2>&1)
    local exit_code=$?
    
    # then
    [[ $exit_code -ne 0 ]] || return 1
}

test_rm_self_removes_current_worktree() {
    # given
    local branch_name="test-branch"
    git branch "$branch_name"
    gwt add "$branch_name" >/dev/null 2>&1
    cd "$TEST_DIR"  # gwt add changes into worktree, go back to root
    gwt cd "$branch_name"
    
    # when
    gwt rm -s >/dev/null 2>&1
    
    # then
    [[ ! -d "$TEST_DIR/.git/worktree-workspace/$branch_name" ]] || return 1
    # should be back at git root
    [[ "$(pwd)" == "$TEST_DIR" ]] || return 1
}

test_rm_all_removes_all_worktrees() {
    # given
    git branch "branch-1"
    git branch "branch-2"
    gwt add "branch-1" >/dev/null 2>&1
    gwt add "branch-2" >/dev/null 2>&1
    
    # when
    gwt rm -a -f >/dev/null 2>&1
    
    # then
    [[ ! -d ".git/worktree-workspace/branch-1" ]] || return 1
    [[ ! -d ".git/worktree-workspace/branch-2" ]] || return 1
}

test_merge_merges_branch() {
    # given
    git branch "feature"
    git checkout feature --quiet
    echo "new content" > feature.txt
    git add feature.txt
    git commit -m "feature commit" --quiet
    git checkout main --quiet 2>/dev/null || git checkout master --quiet
    
    # when
    local output
    output=$(gwt merge "feature" 2>&1)
    
    # then
    [[ -f "feature.txt" ]] || return 1
}

test_merge_fails_for_nonexistent_branch() {
    # given
    # no feature branch
    
    # when
    local output
    output=$(gwt merge "nonexistent" 2>&1)
    local exit_code=$?
    
    # then
    [[ $exit_code -ne 0 ]] || return 1
    [[ "$output" == *"not found"* ]] || return 1
}

test_fallback_to_git_worktree() {
    # given
    # using a native git worktree command
    
    # when
    local output
    output=$(gwt list 2>&1)  # 'list' is not a gwt command, falls back to git worktree
    
    # then
    [[ "$output" == *"$TEST_DIR"* ]] || return 1
}

test_requires_branch_name_for_add() {
    # given
    # no branch name provided
    
    # when
    local output
    output=$(gwt add 2>&1)
    local exit_code=$?
    
    # then
    [[ $exit_code -ne 0 ]] || return 1
    [[ "$output" == *"branch name required"* ]] || return 1
}

test_requires_git_repo() {
    # given
    local non_git_dir=$(mktemp -d)
    cd "$non_git_dir"
    
    # when
    local output
    output=$(gwt add "test" 2>&1)
    local exit_code=$?
    
    # then
    rm -rf "$non_git_dir"
    [[ $exit_code -ne 0 ]] || return 1
    [[ "$output" == *"not a git repository"* ]] || return 1
}

# ---------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------

main() {
    echo "Running gwt tests..."
    echo ""
    
    # Version and Help
    run_test test_version
    run_test test_help
    
    # Add command
    run_test test_add_creates_worktree
    run_test test_add_is_idempotent
    run_test test_add_converts_slash_to_dash
    run_test test_add_links_env_file
    
    # Ls command
    run_test test_ls_lists_worktrees
    run_test test_ls_with_no_worktrees
    
    # Path command
    run_test test_path_returns_worktree_path
    run_test test_path_fails_for_nonexistent
    
    # Cd command
    run_test test_cd_changes_to_worktree
    run_test test_cd_fails_for_nonexistent
    
    # Rm command
    run_test test_rm_removes_worktree
    run_test test_rm_fails_for_nonexistent
    run_test test_rm_self_removes_current_worktree
    run_test test_rm_all_removes_all_worktrees
    
    # Merge command
    run_test test_merge_merges_branch
    run_test test_merge_fails_for_nonexistent_branch
    
    # Edge cases
    run_test test_fallback_to_git_worktree
    run_test test_requires_branch_name_for_add
    run_test test_requires_git_repo
    
    echo ""
    echo "----------------------------------------"
    echo "Tests: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
    echo "----------------------------------------"
    
    [[ $TESTS_FAILED -eq 0 ]]
}

main "$@"
