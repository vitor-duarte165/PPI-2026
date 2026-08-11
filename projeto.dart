import 'dart:async';
import 'dart:io';
import 'dart:math';

const int labHeight = 20;
const int labWidth = 50;
const int zombieCount = 20;
const int mouseCount = 10;

final Random random = Random();

class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class Difficulty {
  final String name;
  final int zombieMovesPerTurn;

  const Difficulty(this.name, this.zombieMovesPerTurn);
}

void clearScreen() {
  stdout.write('\x1B[2J\x1B[H');
}

String repeatChar(String character, int count) {
  return List.filled(count, character).join();
}

Position randomFreePosition(Set<Position> occupied) {
  while (true) {
    final position = Position(
      random.nextInt(labHeight),
      random.nextInt(labWidth),
    );

    if (!occupied.contains(position)) {
      return position;
    }
  }
}

List<Position> createZombies(Set<Position> occupied) {
  final zombies = <Position>[];

  while (zombies.length < zombieCount) {
    final unavailable = <Position>{...occupied, ...zombies};
    zombies.add(randomFreePosition(unavailable));
  }

  return zombies;
}

String capturedIds(int captured) {
  if (captured == 0) return '-';

  final buffer = StringBuffer();
  for (int i = 0; i < captured; i++) {
    buffer.write(String.fromCharCode('A'.codeUnitAt(0) + i));
  }
  return buffer.toString();
}

void drawGame({
  required Position player,
  required List<Position> zombies,
  required Position mouse,
  required int captured,
  required int steps,
  required int? bestSteps,
  required String difficulty,
}) {
  clearScreen();

  final bestText = bestSteps == null ? '?' : bestSteps.toString();
  final mouseId = String.fromCharCode('A'.codeUnitAt(0) + captured);

  print('Zombie Curse Cure | dificuldade: $difficulty');
  print('melhor pontuação: $bestText passos');
  print(
    'camundongos capturados: ${capturedIds(captured)} '
    '($captured/$mouseCount)',
  );
  print('partida atual: $steps passos | camundongo atual: $mouseId');

  final horizontalWall = '+${repeatChar('-', labWidth)}+';
  print(horizontalWall);

  final zombieSet = zombies.toSet();

  for (int row = 0; row < labHeight; row++) {
    final line = List<String>.filled(labWidth, ' ');

    for (int col = 0; col < labWidth; col++) {
      if (zombieSet.contains(Position(row, col))) {
        line[col] = 'X';
      }
    }

    if (mouse.row == row) {
      line[mouse.col] = mouseId;
    }

    if (player.row == row) {
      line[player.col] = '@';
    }

    print('|${line.join()}|');
  }

  print(horizontalWall);
  print('Controles: W=cima, S=baixo, A=esquerda, D=direita, Q=sair');
}

Position movePlayer(Position player, String command) {
  int dr = 0;
  int dc = 0;

  switch (command) {
    case 'w':
      dr = -1;
      break;
    case 's':
      dr = 1;
      break;
    case 'a':
      dc = -1;
      break;
    case 'd':
      dc = 1;
      break;
    default:
      return player;
  }

  final newRow = player.row + dr;
  final newCol = player.col + dc;

  if (newRow >= 0 && newRow < labHeight && newCol >= 0 && newCol < labWidth) {
    return Position(newRow, newCol);
  }

  return player;
}

bool moveZombies({
  required List<Position> zombies,
  required Position player,
  required Position mouse,
  required int movesPerTurn,
}) {
  const directions = <Position>[
    Position(-1, 0),
    Position(1, 0),
    Position(0, -1),
    Position(0, 1),
  ];

  for (int move = 0; move < movesPerTurn; move++) {
    for (int i = 0; i < zombies.length; i++) {
      final current = zombies[i];
      final direction = directions[random.nextInt(directions.length)];

      var candidate = Position(
        current.row + direction.row,
        current.col + direction.col,
      );

      final outside = candidate.row < 0 ||
          candidate.row >= labHeight ||
          candidate.col < 0 ||
          candidate.col >= labWidth;

      if (outside) {
        candidate = current;
      }

      final occupiedByOtherZombies = zombies.toSet()..remove(current);

      // Evita sobreposição entre zumbis e evita esconder o camundongo.
      if (occupiedByOtherZombies.contains(candidate) || candidate == mouse) {
        candidate = current;
      }

      zombies[i] = candidate;

      if (candidate == player) {
        return true;
      }
    }
  }

  return false;
}

Difficulty chooseDifficulty() {
  while (true) {
    clearScreen();
    print('=== Zombie Curse Cure ===');
    print('1 - Normal: cada zumbi anda 1 vez por turno');
    print('2 - Difícil: cada zumbi anda 2 vezes por turno');
    stdout.write('Escolha a dificuldade: ');

    final option = stdin.readLineSync()?.trim() ?? '';

    if (option == '1') {
      return const Difficulty('Normal', 1);
    }
    if (option == '2') {
      return const Difficulty('Difícil', 2);
    }

    stdout.write('Opção inválida. Pressione ENTER para tentar novamente...');
    stdin.readLineSync();
  }
}

Map<String, Object?> playMatch(int? bestSteps) {
  final difficulty = chooseDifficulty();

  var player = Position(labHeight - 1, labWidth ~/ 2);
  final zombies = createZombies({player});
  var mouse = randomFreePosition({player, ...zombies});

  var captured = 0;
  var steps = 0;

  // Desativa temporariamente o modo de linha e o eco do terminal. Assim, cada
  // tecla pressionada fica disponível imediatamente, sem precisar de ENTER.
  stdin.lineMode = false;
  stdin.echoMode = false;

  try {
    while (true) {
      drawGame(
        player: player,
        zombies: zombies,
        mouse: mouse,
        captured: captured,
        steps: steps,
        bestSteps: bestSteps,
        difficulty: difficulty.name,
      );

      stdout.write('Seu movimento: ');
      final command = String.fromCharCode(stdin.readByteSync()).toLowerCase();

      if (command == 'q') {
        return {'result': 'quit', 'steps': steps, 'bestSteps': bestSteps};
      }

      if (!{'w', 'a', 's', 'd'}.contains(command)) {
        continue;
      }

      final newPlayer = movePlayer(player, command);
      if (newPlayer == player) {
        // Bater na parede não conta como passo dado.
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
          difficulty: difficulty.name,
        );
        print('\nDERROTA! Você foi capturado por um zumbi.');
        return {'result': 'loss', 'steps': steps, 'bestSteps': bestSteps};
      }

      if (player == mouse) {
        captured++;

        if (captured == mouseCount) {
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
            difficulty: difficulty.name,
          );
          print(
            '\nVITÓRIA! Você recuperou todos os 10 camundongos e salvou a pesquisa!',
          );
          return {'result': 'win', 'steps': steps, 'bestSteps': bestSteps};
        }

        mouse = randomFreePosition({player, ...zombies});
      }

      final caught = moveZombies(
        zombies: zombies,
        player: player,
        mouse: mouse,
        movesPerTurn: difficulty.zombieMovesPerTurn,
      );

      if (caught) {
        drawGame(
          player: player,
          zombies: zombies,
          mouse: mouse,
          captured: captured,
          steps: steps,
          bestSteps: bestSteps,
          difficulty: difficulty.name,
        );
        print('\nDERROTA! Um zumbi alcançou você.');
        return {'result': 'loss', 'steps': steps, 'bestSteps': bestSteps};
      }
    }
  } finally {
    // Restaura o terminal para que os menus voltem a usar ENTER normalmente.
    stdin.lineMode = true;
    stdin.echoMode = true;
  }
}

void main() {
  int? bestSteps;

  while (true) {
    final match = playMatch(bestSteps);
    bestSteps = match['bestSteps'] as int?;

    if (match['result'] == 'quit') {
      print('Jogo encerrado.');
      break;
    }

    stdout.write('\nDeseja jogar novamente? (S/N): ');
    final answer = stdin.readLineSync()?.trim().toLowerCase() ?? '';

    if (answer != 's') {
      print('Obrigado por jogar Zombie Curse Cure!');
      break;
    }
  }
} 
