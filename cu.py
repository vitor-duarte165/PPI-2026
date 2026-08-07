#!/usr/bin/env python3
"""Zombie Curse Cure - versão em Python.

Jogo de sobrevivência em terminal desenvolvido para a PPI de Programação I.
Controles: W, A, S, D para mover e Q para abandonar a partida.
Compatível com Windows e Linux, sem bibliotecas externas.
"""

from __future__ import annotations

import os
import random
import sys
from dataclasses import dataclass
from typing import Final

if os.name == "nt":
    import msvcrt
else:
    import termios
    import tty

HEIGHT: Final = 20
WIDTH: Final = 50
TOTAL_MICE: Final = 10
MOUSE_SYMBOLS: Final = "ABCDEFGHIJ"
DIRECTIONS: Final = ((-1, 0), (1, 0), (0, -1), (0, 1))


@dataclass(frozen=True)
class Position:
    row: int
    col: int

    def moved(self, dr: int, dc: int) -> "Position":
        return Position(self.row + dr, self.col + dc)


@dataclass(frozen=True)
class Difficulty:
    name: str
    zombie_count: int
    move_every: int
    move_phases: int


DIFFICULTIES: Final = {
    "1": Difficulty("Fácil", 12, 2, 1),
    "2": Difficulty("Normal", 20, 1, 1),
    "3": Difficulty("Difícil", 25, 1, 2),
}


def clear_screen() -> None:
    print("\033[2J\033[H", end="")


def hide_cursor() -> None:
    print("\033[?25l", end="", flush=True)


def show_cursor() -> None:
    print("\033[?25h", end="", flush=True)


def read_key() -> str:
    """Lê uma tecla sem exigir Enter, tanto no Windows quanto no Linux."""
    if os.name == "nt":
        key = msvcrt.getwch()
        if key in ("\x00", "\xe0"):
            msvcrt.getwch()  # descarta a segunda parte de teclas especiais
            return ""
        return key.lower()

    file_descriptor = sys.stdin.fileno()
    old_settings = termios.tcgetattr(file_descriptor)
    try:
        tty.setcbreak(file_descriptor)
        return sys.stdin.read(1).lower()
    finally:
        termios.tcsetattr(file_descriptor, termios.TCSADRAIN, old_settings)


def random_empty_position(occupied: set[Position]) -> Position:
    while True:
        candidate = Position(
            random.randrange(HEIGHT),
            random.randrange(WIDTH),
        )
        if candidate not in occupied:
            return candidate


def create_initial_state(difficulty: Difficulty) -> tuple[Position, list[Position], Position]:
    occupied: set[Position] = set()

    player = random_empty_position(occupied)
    occupied.add(player)

    zombies: list[Position] = []
    for _ in range(difficulty.zombie_count):
        zombie = random_empty_position(occupied)
        zombies.append(zombie)
        occupied.add(zombie)

    mouse = random_empty_position(occupied)
    return player, zombies, mouse


def draw_game(
    player: Position,
    zombies: list[Position],
    mouse: Position,
    captured: int,
    steps: int,
    best_steps: int | None,
    difficulty: Difficulty,
    message: str = "",
) -> None:
    grid = [[" " for _ in range(WIDTH)] for _ in range(HEIGHT)]

    for zombie in zombies:
        grid[zombie.row][zombie.col] = "X"

    if captured < TOTAL_MICE:
        grid[mouse.row][mouse.col] = MOUSE_SYMBOLS[captured]
    grid[player.row][player.col] = "@"

    best_text = "?" if best_steps is None else str(best_steps)
    captured_symbols = MOUSE_SYMBOLS[:captured] or "nenhum"

    output = [
        f"ZOMBIE CURSE CURE - dificuldade: {difficulty.name}",
        f"Melhor pontuação: {best_text} passos",
        f"Camundongos capturados: {captured}/10 ({captured_symbols})",
        f"Partida atual: {steps} passos",
        "Controles: W A S D | Q sair",
        "+" + "-" * WIDTH + "+",
    ]

    output.extend("|" + "".join(row) + "|" for row in grid)
    output.append("+" + "-" * WIDTH + "+")
    if message:
        output.append(message)

    clear_screen()
    print("\n".join(output), flush=True)


def move_player(player: Position, key: str) -> Position:
    movement = {
        "w": (-1, 0),
        "s": (1, 0),
        "a": (0, -1),
        "d": (0, 1),
    }.get(key)

    if movement is None:
        return player

    candidate = player.moved(*movement)
    if 0 <= candidate.row < HEIGHT and 0 <= candidate.col < WIDTH:
        return candidate
    return player


def move_zombies(
    zombies: list[Position],
    player: Position,
    mouse: Position,
) -> list[Position]:
    updated: list[Position] = []

    for index, zombie in enumerate(zombies):
        dr, dc = random.choice(DIRECTIONS)
        candidate = zombie.moved(dr, dc)

        blocked_positions = set(updated)
        blocked_positions.update(zombies[index + 1 :])
        blocked = (
            not (0 <= candidate.row < HEIGHT and 0 <= candidate.col < WIDTH)
            or candidate in blocked_positions
            or candidate == mouse
        )

        updated.append(zombie if blocked else candidate)

    return updated


def choose_difficulty() -> Difficulty:
    while True:
        clear_screen()
        print("ZOMBIE CURSE CURE\n")
        print("1 - Fácil   (12 zumbis; movem a cada 2 passos)")
        print("2 - Normal  (20 zumbis; movem a cada passo)")
        print("3 - Difícil (25 zumbis; movem duas vezes por passo)")
        choice = input("\nEscolha a dificuldade [1-3]: ").strip()
        if choice in DIFFICULTIES:
            return DIFFICULTIES[choice]
        input("Opção inválida. Pressione Enter para tentar novamente.")


def play_game(best_steps: int | None) -> tuple[str, int, int | None]:
    difficulty = choose_difficulty()
    player, zombies, mouse = create_initial_state(difficulty)
    captured = 0
    steps = 0

    hide_cursor()
    try:
        while True:
            draw_game(player, zombies, mouse, captured, steps, best_steps, difficulty)
            key = read_key()

            if key == "q":
                return "abandoned", steps, best_steps
            if key not in {"w", "a", "s", "d"}:
                continue

            new_player = move_player(player, key)
            if new_player == player:
                continue

            player = new_player
            steps += 1

            if player in zombies:
                draw_game(
                    player,
                    zombies,
                    mouse,
                    captured,
                    steps,
                    best_steps,
                    difficulty,
                    "Um zumbi capturou o cientista!",
                )
                return "loss", steps, best_steps

            if player == mouse:
                captured += 1
                if captured == TOTAL_MICE:
                    if best_steps is None or steps < best_steps:
                        best_steps = steps
                    draw_game(
                        player,
                        zombies,
                        mouse,
                        captured,
                        steps,
                        best_steps,
                        difficulty,
                        "Todos os camundongos foram recuperados!",
                    )
                    return "win", steps, best_steps

                occupied = set(zombies)
                occupied.add(player)
                mouse = random_empty_position(occupied)

            if steps % difficulty.move_every == 0:
                for _ in range(difficulty.move_phases):
                    zombies = move_zombies(zombies, player, mouse)
                    if player in zombies:
                        draw_game(
                            player,
                            zombies,
                            mouse,
                            captured,
                            steps,
                            best_steps,
                            difficulty,
                            "Um zumbi capturou o cientista!",
                        )
                        return "loss", steps, best_steps
    finally:
        show_cursor()


def ask_replay() -> bool:
    while True:
        answer = input("\nDeseja jogar novamente? [S/N]: ").strip().lower()
        if answer in {"s", "sim"}:
            return True
        if answer in {"n", "nao", "não"}:
            return False
        print("Digite S para sim ou N para não.")


def main() -> None:
    if os.name == "nt":
        os.system("")  # habilita sequências ANSI em terminais modernos do Windows

    best_steps: int | None = None

    try:
        while True:
            result, steps, best_steps = play_game(best_steps)
            result_text = {
                "win": f"Vitória em {steps} passos!",
                "loss": f"Derrota após {steps} passos.",
                "abandoned": f"Partida encerrada após {steps} passos.",
            }[result]
            print(f"\n{result_text}")

            if not ask_replay():
                break
    except KeyboardInterrupt:
        print("\nJogo encerrado.")
    finally:
        show_cursor()

    print("Obrigado por jogar Zombie Curse Cure!")


if __name__ == "__main__":
    main()