(() => {
  "use strict";

  // # = rock, . = grass, A = acid, F = fire. Start and goal overlay grass.
  const MAP = [
    "##########",
    "#........#",
    "#.##.###.#",
    "#....AFF.#",
    "#.#.##.#.#",
    "#.#....#.#",
    "#..#.#.#.#",
    "#....#...#",
    "#........#",
    "##########",
  ];
  const START = { x: 1, y: 8 };
  const GOAL = { x: 8, y: 1 };
  const DELTAS = [[0, -1], [1, 0], [0, 1], [-1, 0]];
  const DIR_NAMES = ["north", "east", "south", "west"];
  const STORAGE_KEY = "circuit-maze-level-1-blocks";
  const MAX_COMMANDS = 500;

  const board = document.getElementById("board");
  const readout = document.querySelector(".readout");
  const title = document.getElementById("status-title");
  const detail = document.getElementById("status-detail");
  const healthValue = document.getElementById("health-value");
  const stepsValue = document.getElementById("steps-value");
  const runButton = document.getElementById("run-button");
  const cells = new Map();
  let workspace;
  let robot = freshRobot();
  let runId = 0;
  let running = false;
  let saveTimer;

  function saveWorkspace() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(Blockly.serialization.workspaces.save(workspace))); } catch (_) { /* The game remains playable without storage. */ }
  }

  function freshRobot() { return { x: START.x, y: START.y, direction: 0, health: 10, steps: 0, visited: new Set([`${START.x},${START.y}`]) }; }
  function key(x, y) { return `${x},${y}`; }
  function tileAt(x, y) { return MAP[y]?.[x] ?? "#"; }
  function passable(x, y) { return tileAt(x, y) !== "#"; }
  function atGoal() { return robot.x === GOAL.x && robot.y === GOAL.y; }

  function setStatus(kind, heading, message) {
    readout.className = `readout ${kind}`;
    document.getElementById("status-icon").textContent = kind === "success" ? "✓" : kind === "error" ? "!" : "●";
    title.textContent = heading;
    detail.textContent = message;
  }

  function renderBoard() {
    board.replaceChildren();
    cells.clear();
    MAP.forEach((row, y) => [...row].forEach((type, x) => {
      const cell = document.createElement("div");
      cell.className = `tile ${type === "#" ? "rock" : type === "A" ? "acid" : type === "F" ? "fire" : "grass"}${x === GOAL.x && y === GOAL.y ? " goal" : ""}`;
      cell.setAttribute("role", "gridcell");
      cell.setAttribute("aria-label", `Row ${y + 1}, column ${x + 1}: ${type === "#" ? "rock" : type === "A" ? "acid" : type === "F" ? "fire" : "grass"}${x === GOAL.x && y === GOAL.y ? ", flag" : ""}`);
      if (x === GOAL.x && y === GOAL.y) {
        const flag = document.createElement("span"); flag.className = "flag"; flag.setAttribute("aria-hidden", "true"); cell.append(flag);
      }
      board.append(cell);
      cells.set(key(x, y), cell);
    }));
    renderRobot();
  }

  function renderRobot() {
    for (const cell of cells.values()) { cell.querySelector(".robot")?.remove(); cell.classList.remove("visited"); }
    for (const visited of robot.visited) cells.get(visited)?.classList.add("visited");
    const marker = document.createElement("span");
    marker.className = `robot facing-${DIR_NAMES[robot.direction]}`;
    marker.setAttribute("aria-hidden", "true");
    cells.get(key(robot.x, robot.y)).append(marker);
    healthValue.textContent = robot.health;
    stepsValue.textContent = robot.steps;
  }

  const toolbox = {
    kind: "categoryToolbox",
    contents: [
      { kind: "category", name: "Move", colour: "#438cc5", contents: [
        { kind: "block", type: "maze_move" }, { kind: "block", type: "maze_turn_left" }, { kind: "block", type: "maze_turn_right" },
      ] },
      { kind: "category", name: "Loops", colour: "#a678d6", contents: [
        { kind: "block", type: "maze_repeat" }, { kind: "block", type: "maze_until_goal" },
      ] },
      { kind: "category", name: "Choices", colour: "#e3a54b", contents: [
        { kind: "block", type: "maze_if_path" }, { kind: "block", type: "maze_if_else" },
      ] },
    ],
  };

  function defineBlocks() {
    Blockly.defineBlocksWithJsonArray([
      { type: "maze_start", message0: "when run", nextStatement: null, colour: "#345a77", tooltip: "Blocks connected below run from top to bottom." },
      { type: "maze_move", message0: "move forward", previousStatement: null, nextStatement: null, colour: "#438cc5", tooltip: "Move one tile in the direction the robot faces." },
      { type: "maze_turn_left", message0: "turn left", previousStatement: null, nextStatement: null, colour: "#438cc5", tooltip: "Rotate 90 degrees left." },
      { type: "maze_turn_right", message0: "turn right", previousStatement: null, nextStatement: null, colour: "#438cc5", tooltip: "Rotate 90 degrees right." },
      { type: "maze_repeat", message0: "repeat %1 times", args0: [{ type: "field_number", name: "COUNT", value: 3, min: 1, max: 50, precision: 1 }], message1: "do %1", args1: [{ type: "input_statement", name: "DO" }], previousStatement: null, nextStatement: null, colour: "#a678d6", tooltip: "Run the enclosed blocks this many times." },
      { type: "maze_until_goal", message0: "repeat until flag", message1: "do %1", args1: [{ type: "input_statement", name: "DO" }], previousStatement: null, nextStatement: null, colour: "#a678d6", tooltip: "Keep running enclosed blocks until the robot reaches the flag." },
      { type: "maze_if_path", message0: "if path %1", args0: [{ type: "field_dropdown", name: "DIRECTION", options: [["ahead", "AHEAD"], ["left", "LEFT"], ["right", "RIGHT"]] }], message1: "do %1", args1: [{ type: "input_statement", name: "DO" }], previousStatement: null, nextStatement: null, colour: "#e3a54b", tooltip: "Run the enclosed blocks if the neighboring tile is open." },
      { type: "maze_if_else", message0: "if path %1", args0: [{ type: "field_dropdown", name: "DIRECTION", options: [["ahead", "AHEAD"], ["left", "LEFT"], ["right", "RIGHT"]] }], message1: "do %1", args1: [{ type: "input_statement", name: "DO" }], message2: "else %1", args2: [{ type: "input_statement", name: "ELSE" }], previousStatement: null, nextStatement: null, colour: "#e3a54b", tooltip: "Choose one action when a path is open and another when it is blocked." },
    ]);
  }

  function addStartBlock() {
    const start = workspace.newBlock("maze_start");
    start.initSvg(); start.render(); start.moveBy(55, 55);
    start.setDeletable(false); start.setMovable(false);
    return start;
  }

  function initBlockly() {
    defineBlocks();
    workspace = Blockly.inject("blocklyDiv", {
      toolbox,
      renderer: "geras",
      trashcan: true,
      sounds: false,
      scrollbars: true,
      move: { scrollbars: true, drag: true, wheel: true },
      zoom: { controls: true, wheel: true, startScale: .9, minScale: .65, maxScale: 1.2, scaleSpeed: 1.1 },
    });
    let loaded = false;
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) { Blockly.serialization.workspaces.load(JSON.parse(stored), workspace); loaded = !!workspace.getBlocksByType("maze_start", false).length; }
    } catch (_) { /* Corrupt local draft falls back to a new program. */ }
    if (!loaded) { workspace.clear(); addStartBlock(); }
    workspace.addChangeListener(event => {
      if (event.isUiEvent) return;
      clearTimeout(saveTimer);
      saveTimer = setTimeout(saveWorkspace, 200);
    });
    window.addEventListener("resize", () => Blockly.svgResize(workspace));
    requestAnimationFrame(() => Blockly.svgResize(workspace));
  }

  function pathOpen(direction) {
    const offset = direction === "LEFT" ? 3 : direction === "RIGHT" ? 1 : 0;
    const index = (robot.direction + offset) % 4;
    const [dx, dy] = DELTAS[index];
    return passable(robot.x + dx, robot.y + dy);
  }

  class ProgramStop extends Error {}
  function checkRun(id, context) {
    if (id !== runId) throw new ProgramStop("cancelled");
    context.commands += 1;
    if (context.commands > MAX_COMMANDS) throw new ProgramStop("The program ran too long. Check for a loop that never reaches the flag.");
  }
  function pause() { return new Promise(resolve => setTimeout(resolve, 260)); }

  async function executeChain(firstBlock, id, context) {
    for (let block = firstBlock; block; block = block.getNextBlock()) {
      checkRun(id, context);
      if (atGoal()) return;
      workspace.highlightBlock(block.id);
      switch (block.type) {
        case "maze_move": {
          const [dx, dy] = DELTAS[robot.direction];
          const nx = robot.x + dx, ny = robot.y + dy;
          if (!passable(nx, ny)) throw new ProgramStop("The robot hit a rock. Change its route or add a path check.");
          robot.x = nx; robot.y = ny; robot.steps += 1;
          robot.visited.add(key(nx, ny));
          robot.health -= tileAt(nx, ny) === "A" ? 2 : tileAt(nx, ny) === "F" ? 4 : 0;
          renderRobot();
          setStatus("", "Program running", `Moving ${DIR_NAMES[robot.direction]} · ${robot.health} health left`);
          await pause();
          if (id !== runId) throw new ProgramStop("cancelled");
          if (robot.health <= 0) throw new ProgramStop("The robot ran out of health. Try a safer route.");
          break;
        }
        case "maze_turn_left": robot.direction = (robot.direction + 3) % 4; renderRobot(); await pause(); break;
        case "maze_turn_right": robot.direction = (robot.direction + 1) % 4; renderRobot(); await pause(); break;
        case "maze_repeat": {
          const body = block.getInputTargetBlock("DO");
          if (!body) throw new ProgramStop("A repeat block is empty. Put a move or turn block inside it.");
          for (let i = 0; i < Number(block.getFieldValue("COUNT")) && !atGoal(); i++) await executeChain(body, id, context);
          break;
        }
        case "maze_until_goal": {
          const body = block.getInputTargetBlock("DO");
          if (!body) throw new ProgramStop("The repeat until flag block needs blocks inside it.");
          while (!atGoal()) await executeChain(body, id, context);
          break;
        }
        case "maze_if_path":
          if (pathOpen(block.getFieldValue("DIRECTION"))) await executeChain(block.getInputTargetBlock("DO"), id, context);
          break;
        case "maze_if_else":
          await executeChain(block.getInputTargetBlock(pathOpen(block.getFieldValue("DIRECTION")) ? "DO" : "ELSE"), id, context);
          break;
      }
      if (id !== runId) throw new ProgramStop("cancelled");
      if (atGoal()) return;
    }
  }

  function resetRobot() {
    runId += 1;
    running = false;
    runButton.disabled = false;
    workspace?.highlightBlock(null);
    robot = freshRobot();
    renderRobot();
    setStatus("", "Ready to program", "Drag blocks into the workspace and press Run program.");
  }

  function loadExample() {
    resetRobot();
    workspace.clear();
    const start = addStartBlock();
    const create = type => { const block = workspace.newBlock(type); block.initSvg(); block.render(); return block; };
    const sections = [
      ["maze_repeat", 5, "maze_move"], ["maze_turn_right"],
      ["maze_repeat", 3, "maze_move"], ["maze_turn_left"],
      ["maze_repeat", 2, "maze_move"], ["maze_turn_right"],
      ["maze_repeat", 4, "maze_move"],
    ];
    let previous = start;
    for (const [type, count, child] of sections) {
      const block = create(type);
      if (count) {
        block.setFieldValue(String(count), "COUNT");
        const inside = create(child);
        block.getInput("DO").connection.connect(inside.previousConnection);
      }
      previous.nextConnection.connect(block.previousConnection);
      previous = block;
    }
    Blockly.svgResize(workspace);
    clearTimeout(saveTimer);
    saveWorkspace();
    setStatus("", "Example loaded", "Press Run program to watch a safe route to the flag.");
  }

  async function runProgram() {
    if (running) return;
    resetRobot();
    const start = workspace.getBlocksByType("maze_start", false)[0];
    const first = start?.getNextBlock();
    if (!first) { setStatus("error", "Add a move block", "Drag a block below “when run” to make a program."); return; }
    running = true; runButton.disabled = true;
    const id = ++runId;
    const context = { commands: 0 };
    setStatus("", "Program running", "Watch the robot follow your blocks.");
    try {
      await executeChain(first, id, context);
      if (id !== runId) return;
      if (atGoal()) setStatus("success", "Flag reached!", `Your robot made it in ${robot.steps} steps with ${robot.health} health left.`);
      else setStatus("error", "Program finished early", "The robot stopped before the flag. Add more blocks or a loop.");
    } catch (error) {
      if (id !== runId) return;
      setStatus("error", "Try another program", error instanceof ProgramStop ? error.message : "A block could not run. Check your program and try again.");
      if (!(error instanceof ProgramStop)) console.error(error);
    } finally {
      if (id === runId) { running = false; runButton.disabled = false; workspace.highlightBlock(null); }
    }
  }

  document.getElementById("run-button").addEventListener("click", runProgram);
  document.getElementById("reset-button").addEventListener("click", resetRobot);
  document.getElementById("example-button").addEventListener("click", loadExample);
  document.getElementById("clear-button").addEventListener("click", () => { resetRobot(); workspace.clear(); addStartBlock(); clearTimeout(saveTimer); saveWorkspace(); setStatus("", "Blocks cleared", "Build a new program below “when run.”"); });
  renderBoard();
  initBlockly();
  // Small test hook for checking movement, damage, and win/loss behavior in the browser.
  window.CircuitMaze = { getState: () => ({ x: robot.x, y: robot.y, direction: robot.direction, health: robot.health, steps: robot.steps, status: title.textContent }), run: runProgram, reset: resetRobot, getWorkspace: () => workspace };
})();
