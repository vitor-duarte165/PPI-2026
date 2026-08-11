import 'dart:async';
import 'dart:io';
import 'dart:math';

const int height = 20;
const int width = 50;
const int totalMice = 10;
const String mouseSymbols = 'ABCDEFGHIJ';

const List<Position> directions = [
  Position(-1, 0),
  Position(1, 0),
  Position(0, -1),
  Position(0, 1),
];

final Random random = Random();

class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  Position moved(int dr, int dc) => Position(row + dr, col + dc);

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class Difficulty {
  final String name;
  final int zombieCount;
  final int moveEvery;
  final int movePhases;

  const Difficulty(
    this.name,
    this.zombieCount,
    this.moveEvery,
    this.movePhases,
  );
}

const Map<String, Difficulty> difficulties = {
  '1': Difficulty('Fácil', 12, 2, 1),
  '2': Difficulty('Normal', 20, 1, 1),
  '3': Difficulty('Difícil', 25, 1, 2),
};

class InitialState {
  final Position player;
  final List<Position> zombies;
  final Position mouse;

  const InitialState(this.player, this.zombies, this.mouse);
}

class GameResult {
  final String result;
  final int steps;
  final int? bestSteps;

  const GameResult(this.result, this.steps, this.bestSteps);
}

void clearScreen() {
  stdout.write('\x1B[2J\x1B[H');
}

void hideCursor() {
  stdout.write('\x1B[?25l');
}

void showCursor() {
  stdout.write('\x1B[?25h');
}

String repeatCharacter(String character, int count) {
  return List<String>.filled(count, character).join();
}

String readKey() {
  if (!stdin.hasTerminal) {
    final line = stdin.readLineSync() ?? '';
    return line.isEmpty ? '' : line[0].toLowerCase();
  }

  // No Windows, o eco precisa ser desligado antes do modo de linha.
  stdin.echoMode = false;
  stdin.lineMode = false;

  try {
    final firstByte = stdin.readByteSync();

    // No Windows, teclas especiais começam com 0 ou 224 e possuem um
    // segundo byte. Ele é descartado, como no msvcrt.getwch() do Python.
    if (Platform.isWindows && (firstByte == 0 || firstByte == 224)) {
      stdin.readByteSync();
      return '';
    }

    return String.fromCharCode(firstByte).toLowerCase();
  } finally {
    stdin.lineMode = true;
    stdin.echoMode = true;
  }
}

Position randomEmptyPosition(Set<Position> occupied) {
  while (true) {
    final candidate = Position(
      random.nextInt(height),
      random.nextInt(width),
    );

    if (!occupied.contains(candidate)) {
      return candidate;
    }
  }
}

InitialState createInitialState(Difficulty difficulty) {
  final occupied = <Position>{};

  final player = randomEmptyPosition(occupied);
  occupied.add(player);

  final zombies = <Position>[];
  for (int i = 0; i < difficulty.zombieCount; i++) {
    final zombie = randomEmptyPosition(occupied);
    zombies.add(zombie);
    occupied.add(zombie);
  }

  final mouse = randomEmptyPosition(occupied);
  return InitialState(player, zombies, mouse);
}

void drawGame({
  required Position player,
  required List<Position> zombies,
  required Position mouse,
  required int captured,
  required int steps,
  required int? bestSteps,
  required Difficulty difficulty,
  String message = '',
}) {
  final grid = List.generate(
    height,
    (_) => List<String>.filled(width, ' '),
  );

  for (final zombie in zombies) {
    grid[zombie.row][zombie.col] = 'X';
  }

  if (captured < totalMice) {
    grid[mouse.row][mouse.col] = mouseSymbols[captured];
  }
  grid[player.row][player.col] = '@';

  final bestText = bestSteps == null ? '?' : bestSteps.toString();
  final capturedSymbols = captured == 0
      ? 'nenhum'
      : mouseSymbols.substring(0, captured);

  final output = <String>[
    'ZOMBIE CURSE CURE - dificuldade: ${difficulty.name}',
    'Melhor pontuação: $bestText passos',
    'Camundongos capturados: $captured/10 ($capturedSymbols)',
    'Partida atual: $steps passos',
    'Controles: W A S D | Q sair',
    '+${repeatCharacter('-', width)}+',
  ];

  for (final row in grid) {
    output.add('|${row.join()}|');
  }

  output.add('+${repeatCharacter('-', width)}+');
  if (message.isNotEmpty) {
    output.add(message);
  }

  clearScreen();
  stdout.write('${output.join('\n')}\n');
}

Position movePlayer(Position player, String key) {
  const movements = <String, Position>{
    'w': Position(-1, 0),
    's': Position(1, 0),
    'a': Position(0, -1),
    'd': Position(0, 1),
  };

  final movement = movements[key];
  if (movement == null) {
    return player;
  }

  final candidate = player.moved(movement.row, movement.col);
  if (candidate.row >= 0 &&
      candidate.row < height &&
      candidate.col >= 0 &&
      candidate.col < width) {
    return candidate;
  }

  return player;
}

List<Position> moveZombies(
  List<Position> zombies,
  Position player,
  Position mouse,
) {
  final updated = <Position>[];

  for (int index = 0; index < zombies.length; index++) {
    final zombie = zombies[index];
    final direction = directions[random.nextInt(directions.length)];
    final candidate = zombie.moved(direction.row, direction.col);

    final blockedPositions = <Position>{...updated};
    blockedPositions.addAll(zombies.skip(index + 1));

    final outside = candidate.row < 0 ||
        candidate.row >= height ||
        candidate.col < 0 ||
        candidate.col >= width;
    final blocked = outside ||
        blockedPositions.contains(candidate) ||
        candidate == mouse;

    updated.add(blocked ? zombie : candidate);
  }

  return updated;
}

Difficulty chooseDifficulty() {
  while (true) {
    clearScreen();
    print('ZOMBIE CURSE CURE\n');
    print('1 - Fácil   (12 zumbis; movem a cada 2 passos)');
    print('2 - Normal  (20 zumbis; movem a cada passo)');
    print('3 - Difícil (25 zumbis; movem duas vezes por passo)');
    stdout.write('\nEscolha a dificuldade [1-3]: ');

    final choice = stdin.readLineSync()?.trim() ?? '';
    final difficulty = difficulties[choice];
    if (difficulty != null) {
      return difficulty;
    }

    stdout.write('Opção inválida. Pressione Enter para tentar novamente.');
    stdin.readLineSync();
  }
}

GameResult playGame(int? bestSteps) {
  final difficulty = chooseDifficulty();
  final initialState = createInitialState(difficulty);

  var player = initialState.player;
  var zombies = initialState.zombies;
  var mouse = initialState.mouse;
  var captured = 0;
  var steps = 0;

  hideCursor();
  try {
    while (true) {
      drawGame(
        player: player,
        zombies: zombies,
        mouse: mouse,
        captured: captured,
        steps: steps,
        bestSteps: bestSteps,
        difficulty: difficulty,
      );

      final key = readKey();

      if (key == 'q') {
        return GameResult('abandoned', steps, bestSteps);
      }
      if (!{'w', 'a', 's', 'd'}.contains(key)) {
        continue;
      }

      final newPlayer = movePlayer(player, key);
      if (newPlayer == player) {
        continue;
      }

      player = newPlayer;
      steps++;

      if (zombies.contains(player)) {
        drawGame(
          player: player,
          zombies: zombies,
          mouse: mouse,
          captured: captured,
          steps: steps,
          bestSteps: bestSteps,
          difficulty: difficulty,
          message: 'Um zumbi capturou o cientista!',
        );
        return GameResult('loss', steps, bestSteps);
      }

      if (player == mouse) {
        captured++;

        if (captured == totalMice) {
          if (bestSteps == null || steps < bestSteps) {
            bestSteps = steps;
          }

          drawGame(
            player: player,
            zombies: zombies,
            mouse: mouse,
            captured: captured,
            steps: steps,
            bestSteps: bestSteps,
            difficulty: difficulty,
            message: 'Todos os camundongos foram recuperados!',
          );
          return GameResult('win', steps, bestSteps);
        }

        mouse = randomEmptyPosition({player, ...zombies});
      }

      if (steps % difficulty.moveEvery == 0) {
        for (int phase = 0; phase < difficulty.movePhases; phase++) {
          zombies = moveZombies(zombies, player, mouse);

          if (zombies.contains(player)) {
            drawGame(
              player: player,
              zombies: zombies,
              mouse: mouse,
              captured: captured,
              steps: steps,
              bestSteps: bestSteps,
              difficulty: difficulty,
              message: 'Um zumbi capturou o cientista!',
            );
            return GameResult('loss', steps, bestSteps);
          }
        }
      }
    }
  } finally {
    showCursor();
  }
}

bool askReplay() {
  while (true) {
    stdout.write('\nDeseja jogar novamente? [S/N]: ');
    final answer = stdin.readLineSync()?.trim().toLowerCase() ?? '';

    if (answer == 's' || answer == 'sim') {
      return true;
    }
    if (answer == 'n' || answer == 'nao' || answer == 'não') {
      return false;
    }

    print('Digite S para sim ou N para não.');
  }
}

void main() {
  int? bestSteps;
  StreamSubscription<ProcessSignal>? interruptSubscription;

  if (stdin.hasTerminal) {
    interruptSubscription = ProcessSignal.sigint.watch().listen((_) {
      showCursor();
      print('\nJogo encerrado.');
      exit(0);
    });
  }

  try {
    while (true) {
      final game = playGame(bestSteps);
      bestSteps = game.bestSteps;

      final resultText = switch (game.result) {
        'win' => 'Vitória em ${game.steps} passos!',
        'loss' => 'Derrota após ${game.steps} passos.',
        _ => 'Partida encerrada após ${game.steps} passos.',
      };
      print('\n$resultText');

      if (!askReplay()) {
        break;
      }
    }
  } finally {
    interruptSubscription?.cancel();
    showCursor();
  }

  print('Obrigado por jogar Zombie Curse Cure!');
}