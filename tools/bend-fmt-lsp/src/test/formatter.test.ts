import assert from "node:assert/strict";
import test from "node:test";
import { formatBend } from "../formatter.js";

test("formats Bend 2 declarations and nested blocks", () => {
  const source = [
    "import   Base",
    "",
    "def  area ( x : Shape )-> U32:",
    "     match   x:",
    "          case  Circle{ +r }:",
    "             ( 3*r*r : U32 )",
    "",
  ].join("\n");
  assert.equal(formatBend(source), [
    "import Base",
    "",
    "def area(x : Shape) -> U32:",
    "  match x:",
    "    case Circle{+r}:",
    "      (3 * r * r : U32)",
    "",
  ].join("\n"));
});

test("preserves comments, literals, line endings, and final newline state", () => {
  const source = "def main()->String:\r\n\t\"a # b\\n\"   # exact comment";
  assert.equal(formatBend(source), "def main() -> String:\r\n  \"a # b\\n\"  # exact comment");
});

test("preserves angle spacing because Bend uses it to disambiguate syntax", () => {
  const source = "def f(x:U32)->U32:\n    y=x < 2\n    List<List<U32>>{}";
  assert.equal(formatBend(source), "def f(x: U32) -> U32:\n  y = x < 2\n  List<List<U32>>{}");
});

test("uses tabs when requested and is idempotent", () => {
  const source = "def main() -> U32:\n    match x:\n      case 0 n:\n        0";
  const once = formatBend(source, { tabSize: 4, insertSpaces: false });
  assert.equal(once, "def main() -> U32:\n\tmatch x:\n\t\tcase 0 n:\n\t\t\t0");
  assert.equal(formatBend(once, { tabSize: 4, insertSpaces: false }), once);
});

test("keeps Bend prefix forms glued without changing infix operators", () => {
  const source = "law use:\n    for + value: U32\n    List< & 2,U32>\n    & item:U32 -> { item==item:U32}\n    \\ {}\n    % proof : {==}";
  assert.equal(formatBend(source), "law use:\n  for +value: U32\n  List<&2, U32>\n  &item: U32 -> {item == item: U32}\n  \\{}\n  %proof : {==}");
});

test("keeps floating point exponents intact", () => {
  assert.equal(formatBend("def x()->F32:\n  1.25e-4"), "def x() -> F32:\n  1.25e-4");
});

test("preserves adjacency in natural-number successor patterns", () => {
  assert.equal(formatBend("case 1n+p:\n  p"), "case 1n+p:\n  p");
  assert.equal(formatBend("case 1n++p:\n  p"), "case 1n++p:\n  p");
  assert.equal(formatBend("value=1n + p"), "value = 1n + p");
});

test("keeps adjacent parallel binders and template quantities", () => {
  assert.equal(formatBend("+a +b=x y"), "+a +b = x y");
  assert.equal(formatBend("f(~ & 2,~T,[1,2])"), "f(~&2, ~T, [1, 2])");
});

test("formats dot operators and keeps continuation operators infix", () => {
  assert.equal(formatBend("x=(6 .&. 3 .|. 8 : U32)\n  + value"), "x = (6 .&. 3 .|. 8 : U32)\n  + value");
});

test("keeps parallel execution call suffixes glued", () => {
  assert.equal(formatBend("result = run ! (20n)"), "result = run!(20n)");
});

test("leaves unterminated literals unchanged", () => {
  const source = "def main() -> String:\n  \"unfinished";
  assert.equal(formatBend(source), source);
});

test("comment-only lines do not change the following code's indentation", () => {
  const source = "def main() -> U32:\n    a = 1\n  # same block\n    a\n";
  const expected = "def main() -> U32:\n  a = 1\n  # same block\n  a\n";
  assert.equal(formatBend(source), expected);
  assert.equal(formatBend(expected), expected);
});

test("comment placement preserves formatted code and idempotence", () => {
  const lines = [
    "def choose(x: Bool) -> U32:",
    "    match x:",
    "        case True{}:",
    "            1",
    "        case False{}:",
    "            0",
    "def main() -> String:",
    "    \"# literal, not a comment\"",
  ];
  const stripComments = (text: string) => text.split(/\r?\n/)
    .filter((line) => !line.trimStart().startsWith("#")).join("\n");
  for (const options of [{ tabSize: 2 }, { tabSize: 4 }, { insertSpaces: false }]) {
    for (const eol of ["\n", "\r\n"]) {
      for (const final of ["", eol]) {
        const expected = stripComments(formatBend(lines.join(eol) + final, options));
        for (let at = 0; at <= lines.length; at++) {
          for (const indent of ["", " ", "  ", "    ", "      ", "        ", "            ", "                ", "\t", " \t"]) {
            const input = [...lines.slice(0, at), indent + "# keep", ...lines.slice(at)].join(eol) + final;
            const once = formatBend(input, options);
            assert.equal(stripComments(once), expected);
            assert.equal(once.split(/\r?\n/)[at].trimStart(), "# keep");
            assert.equal(formatBend(once, options), once);
          }
        }
      }
    }
  }
});
