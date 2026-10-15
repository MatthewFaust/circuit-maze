(() => {
  "use strict";

  const levels = window.CircuitMazeLevels;
  const DELTAS = [[0, -1], [1, 0], [0, 1], [-1, 0]];
  const DIR_NAMES = ["north", "east", "south", "west"];
  const MAX_COMMANDS = 500;
  const DRAFT_PREFIX = "circuit-maze-beginner-v1-level-";
  const COMPLETION_KEY = "circuit-maze-beginner-v1-completions";
  const LAST_LEVEL_KEY = "circuit-maze-beginner-v1-current-level";

  const board = document.getElementById("board");
  const readout = document.querySelector(".readout");
  const statusTitle = document.getElementById("status-title");
  const statusDetail = document.getElementById("status-detail");
  const stepsValue = document.getElementById("steps-value");
  const runButton = document.getElementById("run-button");
  const nextButton = document.getElementById("next-button");
  const taskDialog = document.getElementById("task-dialog");
  const levelList = document.getElementById("level-list");
  const cells = new Map();
  let level = null;
  let floor = new Set();
  let workspace;
  let robot;
  let runId = 0;
  let running = false;
  let saveTimer;
  let completions = {};

  try { completions = JSON.parse(localStorage.getItem(COMPLETION_KEY) || "{}") || {}; } catch (_) { /* Storage is optional. */ }

  function key(x, y) { return `${x},${y}`; }
  function freshRobot() {
    const [x, y] = level.start;
    return { x, y, direction: level.direction, steps: 0, visited: new Set([key(x, y)]) };
  }
  function passable(x, y) { return floor.has(key(x, y)); }
  function atGoal() { return robot.x === level.goal[0] && robot.y === level.goal[1]; }
  function draftKey() { return `${DRAFT_PREFIX}${level.id}`; }

  function saveWorkspace() {
    if (!workspace || !level) return;
    try { localStorage.setItem(draftKey(), JSON.stringify(Blockly.serialization.workspaces.save(workspace))); } catch (_) { /* The game works without storage. */ }
  }

  function setStatus(kind, heading, message) {
    readout.className = `readout ${kind}`;
    document.getElementById("status-icon").textContent = kind === "success" ? "✓" : kind === "error" ? "!" : "●";
    statusTitle.textContent = heading;
    statusDetail.textContent = message;
  }

  function renderBoard() {
    board.replaceChildren();
    cells.clear();
    for (let y = 0; y < 10; y++) for (let x = 0; x < 10; x++) {
      const isFloor = passable(x, y);
      const isGoal = x === level.goal[0] && y === level.goal[1];
      const cell = document.createElement("div");
      cell.className = `tile ${isFloor ? "grass" : "rock"}${isGoal ? " goal" : ""}`;
      cell.setAttribute("role", "gridcell");
      cell.setAttribute("aria-label", `Row ${y + 1}, column ${x + 1}: ${isFloor ? "floor" : "wall"}${isGoal ? ", flag" : ""}`);
      if (isGoal) {
        const flag = document.createElement("span");
        flag.className = "flag";
        flag.setAttribute("aria-hidden", "true");
        cell.append(flag);
      }
      board.append(cell);
      cells.set(key(x, y), cell);
    }
    renderRobot();
  }

  function renderRobot() {
    for (const cell of cells.values()) { cell.querySelector(".robot")?.remove(); cell.classList.remove("visited"); }
    for (const visited of robot.visited) cells.get(visited)?.classList.add("visited");
    const marker = document.createElement("span");
    marker.className = `robot facing-${DIR_NAMES[robot.direction]}`;
    marker.setAttribute("aria-hidden", "true");
    cells.get(key(robot.x, robot.y)).append(marker);
    stepsValue.textContent = robot.steps;
  }

  function toolboxFor(nextLevel) {
    return { kind: "flyoutToolbox", contents: nextLevel.blocks.map(type => ({ kind: "block", type })) };
  }

  function defineBlocks() {
    Blockly.defineBlocksWithJsonArray([
      { type: "maze_start", message0: "when run", nextStatement: null, colour: "#39453f", tooltip: "Blocks connected below run from top to bottom." },
      { type: "maze_move", message0: "move forward", previousStatement: null, nextStatement: null, colour: "#4f755e", tooltip: "Move one tile in the direction the robot faces." },
      { type: "maze_turn_left", message0: "turn left", previousStatement: null, nextStatement: null, colour: "#4f755e", tooltip: "Rotate 90 degrees left." },
      { type: "maze_turn_right", message0: "turn right", previousStatement: null, nextStatement: null, colour: "#4f755e", tooltip: "Rotate 90 degrees right." },
      { type: "maze_repeat", message0: "repeat %1 times", args0: [{ type: "field_number", name: "COUNT", value: 3, min: 1, max: 50, precision: 1 }], message1: "do %1", args1: [{ type: "input_statement", name: "DO" }], previousStatement: null, nextStatement: null, colour: "#806f55", tooltip: "Run the enclosed blocks this many times." },
    ]);
  }

  function createBlock(type) {
    const block = workspace.newBlock(type);
    block.initSvg();
    block.render();
    return block;
  }

  function createStarter() {
    const start = createBlock("maze_start");
    start.moveBy(25, 55);
    start.setDeletable(false);
    start.setMovable(false);
    if (level.id === 1) start.nextConnection.connect(createBlock("maze_move").previousConnection);
  }

  function loadDraft() {
    workspace.clear();
    let loaded = false;
    try {
      const stored = localStorage.getItem(draftKey());
      if (stored) {
        Blockly.serialization.workspaces.load(JSON.parse(stored), workspace);
        loaded = workspace.getBlocksByType("maze_start", false).length > 0;
      }
    } catch (_) { /* Damaged drafts get a fresh starter. */ }
    if (!loaded) { workspace.clear(); createStarter(); }
    const start = workspace.getBlocksByType("maze_start", false)[0];
    start.setDeletable(false);
    start.setMovable(false);
    Blockly.svgResize(workspace);
  }

  function renderLevelSelector() {
    levelList.replaceChildren();
    for (const option of levels) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `level-option${option.id === level.id ? " active" : ""}`;
      button.dataset.level = option.id;
      if (option.id === level.id) button.setAttribute("aria-current", "step");
      const number = document.createElement("span");
      number.className = "level-number";
      number.textContent = String(option.id).padStart(2, "0");
      const name = document.createElement("span");
      name.className = "level-name";
      name.textContent = option.name;
      button.append(number, name);
      if (completions[option.id]) {
        const check = document.createElement("span");
        check.className = "level-check";
        check.textContent = completions[option.id].efficient ? "★" : "✓";
        check.setAttribute("aria-label", completions[option.id].efficient ? "Completed efficiently" : "Completed");
        button.append(check);
      }
      levelList.append(button);
    }
  }

  function firstLessonCopy() {
    const start = workspace.getBlocksByType("maze_start", false)[0];
    const connected = start ? start.getDescendants(false).length - 1 : 0;
    if (connected >= 2) return "Your program is saved. Press Run program to test it, or Clear blocks to start over.";
    if (connected === 1) return level.lesson;
    return "Drag two move forward blocks below when run, then press Run program.";
  }

  function showTask() {
    document.getElementById("task-level").textContent = `Level ${String(level.id).padStart(2, "0")} / ${String(levels.length).padStart(2, "0")}`;
    document.getElementById("task-title").textContent = level.name;
    document.getElementById("task-objective").textContent = level.objective;
    document.getElementById("task-lesson").textContent = level.id === 1 ? firstLessonCopy() : level.lesson;
    document.getElementById("task-tip").textContent = level.tip;
    if (taskDialog.open) taskDialog.close();
    taskDialog.showModal();
  }

  function resetRobot() {
    runId += 1;
    running = false;
    runButton.disabled = false;
    nextButton.hidden = true;
    workspace?.highlightBlock(null);
    robot = freshRobot();
    renderRobot();
    setStatus("", "Ready to program", level.id === 1 ? firstLessonCopy() : "Build your route, then press Run program.");
  }

  function selectLevel(id, openTask = true) {
    const chosen = levels.find(candidate => candidate.id === Number(id));
    if (!chosen) return;
    clearTimeout(saveTimer);
    if (level && workspace) saveWorkspace();
    runId += 1;
    running = false;
    level = chosen;
    floor = new Set(level.floor.map(([x, y]) => key(x, y)));
    try { localStorage.setItem(LAST_LEVEL_KEY, String(level.id)); } catch (_) { /* Storage is optional. */ }
    document.title = `Circuit Maze — Level ${String(level.id).padStart(2, "0")}`;
    document.getElementById("board-title").textContent = level.name;
    document.getElementById("board-description").textContent = level.objective;
    document.getElementById("editor-tip").textContent = level.tip;
    robot = freshRobot();
    renderBoard();
    workspace.updateToolbox(toolboxFor(level));
    loadDraft();
    document.getElementById("program-description").textContent = level.id === 1 ? firstLessonCopy() : "Drag the available blocks into your program.";
    resetRobot();
    renderLevelSelector();
    if (openTask) showTask();
  }

  function pause() { return new Promise(resolve => setTimeout(resolve, 260)); }
  class ProgramStop extends Error {}
  function checkRun(id, context) {
    if (id !== runId) throw new ProgramStop("cancelled");
    context.commands += 1;
    if (context.commands > MAX_COMMANDS) throw new ProgramStop("The program ran too long. Check your repeat block.");
  }

  async function executeChain(firstBlock, id, context) {
    for (let block = firstBlock; block; block = block.getNextBlock()) {
      checkRun(id, context);
      if (atGoal()) return;
      workspace.highlightBlock(block.id);
      switch (block.type) {
        case "maze_move": {
          const [dx, dy] = DELTAS[robot.direction];
          const nx = robot.x + dx, ny = robot.y + dy;
          if (!passable(nx, ny)) throw new ProgramStop("The robot hit a wall. Check which way it is facing.");
          robot.x = nx; robot.y = ny; robot.steps += 1;
          robot.visited.add(key(nx, ny));
          renderRobot();
          setStatus("", "Program running", `Moving ${DIR_NAMES[robot.direction]}…`);
          await pause();
          break;
        }
        case "maze_turn_left": robot.direction = (robot.direction + 3) % 4; renderRobot(); await pause(); break;
        case "maze_turn_right": robot.direction = (robot.direction + 1) % 4; renderRobot(); await pause(); break;
        case "maze_repeat": {
          const body = block.getInputTargetBlock("DO");
          if (!body) throw new ProgramStop("The repeat block is empty. Put a move or turn inside it.");
          for (let i = 0; i < Number(block.getFieldValue("COUNT")) && !atGoal(); i++) await executeChain(body, id, context);
          break;
        }
      }
      if (id !== runId) throw new ProgramStop("cancelled");
      if (atGoal()) return;
    }
  }

  async function runProgram() {
    if (running) return;
    resetRobot();
    const start = workspace.getBlocksByType("maze_start", false)[0];
    const first = start?.getNextBlock();
    if (!first) { setStatus("error", "Add a block", "Drag a block below “when run” to make a program."); return; }
    running = true;
    runButton.disabled = true;
    const id = ++runId;
    const context = { commands: 0 };
    setStatus("", "Program running", "Watch the robot follow your blocks.");
    try {
      await executeChain(first, id, context);
      if (id !== runId) return;
      if (atGoal()) {
        const efficient = start.getDescendants(false).length - 1 <= level.ideal;
        const previous = completions[level.id];
        completions[level.id] = { efficient: efficient || Boolean(previous?.efficient) };
        try { localStorage.setItem(COMPLETION_KEY, JSON.stringify(completions)); } catch (_) { /* Storage is optional. */ }
        renderLevelSelector();
        setStatus("success", "Flag reached!", `Level ${level.id} complete in ${robot.steps} steps.${efficient ? " ★ Efficient program!" : ""}`);
        nextButton.hidden = level.id === levels.length;
      } else {
        setStatus("error", "Program finished early", "The robot stopped before the flag. Add another block or use repeat.");
      }
    } catch (error) {
      if (id !== runId) return;
      setStatus("error", "Try another program", error instanceof ProgramStop ? error.message : "A block could not run. Check your program and try again.");
      if (!(error instanceof ProgramStop)) console.error(error);
    } finally {
      if (id === runId) { running = false; runButton.disabled = false; workspace.highlightBlock(null); }
    }
  }

  defineBlocks();
  workspace = Blockly.inject("blocklyDiv", {
    toolbox: toolboxFor(levels[0]), renderer: "geras", trashcan: true, sounds: false, scrollbars: true,
    move: { scrollbars: true, drag: true, wheel: true },
    zoom: { controls: true, wheel: true, startScale: .9, minScale: .65, maxScale: 1.2, scaleSpeed: 1.1 },
  });
  workspace.addChangeListener(event => {
    if (event.isUiEvent || !level) return;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveWorkspace, 200);
  });
  window.addEventListener("resize", () => Blockly.svgResize(workspace));
  levelList.addEventListener("click", event => {
    const button = event.target.closest("button[data-level]");
    if (button) selectLevel(button.dataset.level);
  });
  document.getElementById("run-button").addEventListener("click", runProgram);
  document.getElementById("reset-button").addEventListener("click", resetRobot);
  document.getElementById("clear-button").addEventListener("click", () => {
    resetRobot(); workspace.clear(); createStarter(); clearTimeout(saveTimer); saveWorkspace();
    setStatus("", "Blocks cleared", level.id === 1 ? "The first move is ready. Add one more." : "Build a new program below “when run.”");
  });
  document.getElementById("task-button").addEventListener("click", showTask);
  document.getElementById("start-level-button").addEventListener("click", () => taskDialog.close());
  nextButton.addEventListener("click", () => selectLevel(level.id + 1));
  let initialId = 1;
  try { initialId = Number(localStorage.getItem(LAST_LEVEL_KEY)) || 1; } catch (_) { /* Storage is optional. */ }
  selectLevel(initialId);
  requestAnimationFrame(() => Blockly.svgResize(workspace));

  // Read-only state for smoke tests and debugging in the local browser.
  window.CircuitMaze = { getState: () => ({ level: level.id, x: robot.x, y: robot.y, direction: robot.direction, steps: robot.steps, status: statusTitle.textContent }), getWorkspace: () => workspace };
})();
