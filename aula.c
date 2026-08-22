#include <stdio.h>

int main() {
    printf("os pares sao: ");
    for (int i = 0; i < 100; i++)
    {
        if (i % 2 == 0)
        {
            printf("%d ", i);
        }
    }
    printf("\nos pares sao: ");
    int i = 0;
    while (i < 100)
    {
        if (i % 2 == 0)
        {
            printf("%d ", i);
        }
        i++;
    }
    return 0;
}
    