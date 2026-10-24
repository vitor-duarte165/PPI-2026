const idade = 25;

if (idade >= 18) {
    console.log('Pode entrar');
} else {
    console.log('Nao pode entrar');
}

console.log(`Voce tem ${idade} anos`);

if (idade < 16) {
    console.log('Não vota');
} else if (idade < 18 || idade > 65) {
    console.log('Voto opcional');
} else {
    console.log('Voto obrigatorio');
}