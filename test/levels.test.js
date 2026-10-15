const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const context = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "..", "levels.js"), "utf8"), context);
const levels = context.window.CircuitMazeLevels;

const solutions = [
  ["maze_move", "maze_move"],
  ["maze_move", "maze_turn_right", "maze_move"],
  ["maze_move", "maze_turn_right", "maze_move", "maze_turn_left", "maze_move"],
  ["maze_move", "maze_move", "maze_move", "maze_move"],
  ["maze_move", "maze_turn_right", "maze_move", "maze_turn_left", "maze_move", "maze_turn_right", "maze_move"],
];
const deltas = [[0, -1], [1, 0], [0, 1], [-1, 0]];

test("five beginner levels add blocks in order", () => {
  assert.equal(levels.length, 5);
  assert.deepEqual(Array.from(levels[0].blocks), ["maze_move"]);
  assert.deepEqual(Array.from(levels[1].blocks), ["maze_move", "maze_turn_right"]);
  assert.ok(levels[2].blocks.includes("maze_turn_left"));
  assert.ok(!levels[2].blocks.includes("maze_repeat"));
  assert.ok(levels[3].blocks.includes("maze_repeat"));
});

for (const [index, level] of levels.entries()) {
  test(`Level ${level.id} is a valid, solvable floor-and-wall lesson`, () => {
    assert.equal(level.id, index + 1);
    assert.ok(level.objective && level.lesson && level.tip);
    assert.equal(new Set(level.floor.map(([x, y]) => `${x},${y}`)).size, level.floor.length);
    const floor = new Set(level.floor.map(([x, y]) => {
      assert.ok(x >= 0 && x < 10 && y >= 0 && y < 10);
      return `${x},${y}`;
    }));
    assert.ok(floor.has(level.start.join(",")));
    assert.ok(floor.has(level.goal.join(",")));
    let [x, y] = level.start;
    let direction = level.direction;
    for (const command of solutions[index]) {
      assert.ok(level.blocks.includes(command), `${command} must be available`);
      if (command === "maze_turn_right") direction = (direction + 1) % 4;
      if (command === "maze_turn_left") direction = (direction + 3) % 4;
      if (command === "maze_move") {
        x += deltas[direction][0];
        y += deltas[direction][1];
        assert.ok(floor.has(`${x},${y}`), `move to ${x},${y} must be on the path`);
      }
    }
    assert.deepEqual([x, y], Array.from(level.goal));
  });
}
