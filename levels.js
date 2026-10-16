(() => {
  "use strict";

  // These first lessons use only ordinary floor and walls. Coordinates are [x, y].
  const introLevels = [
    {
      id: 1, name: "First steps", objective: "Move the robot forward twice to reach the flag.",
      lesson: "One move block is already connected. Drag one more move forward block underneath it, then press Run program.",
      tip: "The robot is facing right. Each move forward block travels one green tile.",
      start: [3, 5], goal: [5, 5], direction: 1,
      floor: [[3, 5], [4, 5], [5, 5]], blocks: ["maze_move"], ideal: 2,
    },
    {
      id: 2, name: "First turn", objective: "Follow the corner to reach the flag.",
      lesson: "Move forward, turn right, then move forward again. A turn changes direction without changing tiles.",
      tip: "Start by facing right. The path bends downward.",
      start: [3, 4], goal: [4, 5], direction: 1,
      floor: [[3, 4], [4, 4], [4, 5]], blocks: ["maze_move", "maze_turn_right"], ideal: 3,
    },
    {
      id: 3, name: "Two turns", objective: "Navigate two corners to reach the flag.",
      lesson: "You can now turn both left and right. Watch the arrow on the robot to decide which turn comes next.",
      tip: "This time the robot starts facing up.",
      start: [3, 6], goal: [4, 4], direction: 0,
      floor: [[3, 6], [3, 5], [4, 5], [4, 4]], blocks: ["maze_move", "maze_turn_right", "maze_turn_left"], ideal: 5,
    },
    {
      id: 4, name: "Repeat it", objective: "Cross the long corridor using a repeat block.",
      lesson: "Put a move forward block inside repeat and set it to 4 times. The same action can run more than once.",
      tip: "You can also use four separate moves, but repeat makes a shorter program.",
      start: [2, 5], goal: [6, 5], direction: 1,
      floor: [[2, 5], [3, 5], [4, 5], [5, 5], [6, 5]], blocks: ["maze_move", "maze_turn_right", "maze_turn_left", "maze_repeat"], ideal: 2,
    },
    {
      id: 5, name: "A pattern", objective: "Reach the flag by repeating the same corner pattern.",
      lesson: "Look for the little staircase. A repeat block can contain both moves and turns, not just one action.",
      tip: "Try repeating: move, turn right, move, turn left.",
      start: [2, 3], goal: [4, 5], direction: 1,
      floor: [[2, 3], [3, 3], [3, 4], [4, 4], [4, 5]], blocks: ["maze_move", "maze_turn_right", "maze_turn_left", "maze_repeat"], ideal: 5,
    },
  ];
  window.CircuitMazeCollections = [{
    id: "intro",
    name: "Intro",
    description: "Learn to move, turn, and repeat a route.",
    levels: introLevels,
  }];
  // Keep the original level list and storage IDs so existing progress carries over.
  window.CircuitMazeLevels = introLevels;
})();
