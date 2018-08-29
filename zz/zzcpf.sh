# ----------------------------------------------------------------------------
# Cria, valida, formata ou retorna o(s) estado(s) de um número de CPF.
# Obs.: O CPF informado pode estar formatado (pontos e hífen) ou não.
# Uso: zzcpf [-f|-F|-e|-q] [cpf]
# Ex.: zzcpf 123.456.789-09      # valida o CPF informado
#      zzcpf 12345678909         # com ou sem pontuação
#      zzcpf                     # gera um CPF válido (aleatório)
#      zzcpf -f 12345678909      # formata, adicionando pontuação
#      zzcpf -F 12345678909      # desformata, tirando pontuação
#      zzcpf -e 12345678909      # estado(s) de um CPF Válido
#      zzcpf -q 12345678909      # apenas código de retorno, sem mensagens
#
# Autor: Thobias Salazar Trevisan, www.thobias.org
# Desde: 2004-12-23
# Versão: 4
# Licença: GPL
# Requisitos: zzaleatorio zzcut
# Tags: cálculo, consulta, manipulação
# ----------------------------------------------------------------------------
zzcpf ()
{
	zzzz -h cpf "$1" && return

	local i n somatoria digito1 digito2 cpf base op estados auxiliar quieto

	# Remove pontuação do CPF informado, deixando apenas números
	cpf=$(echo "$*" | tr -d -c 0123456789)

	#Retorna estado(s) ao qual o CPF pertence
	if test '-e' = "$1"
	then
		# Se o CPF estiver vazio, define com zero
		: ${cpf:=0}

		# Só continua se o CPF for válido
		auxiliar=$(zzcpf $cpf 2>&1)
		if test "$auxiliar" != 'CPF válido'
		then
			zztool erro "$auxiliar"
			return 1
		fi

		# Uso da função zzcut para captura do 9o digito
		op=$(echo "$cpf" | zzcut -c 9)

		#Atribui estado(s) ao qual o CPF pertence
		case $op in
			0) estados="Rio Grande do Sul";;
			1) estados="Distrito Federal, Goiás, Mato Grosso, Mato Grosso do Sul ou Tocantins";;
			2) estados="Amazonas, Pará, Roraima, Amapá, Acre ou Rondônia";;
			3) estados="Ceará, Maranhão ou Piauí";;
			4) estados="Paraíba, Pernambuco, Alagoas ou Rio Grande do Norte";;
			5) estados="Bahia ou Sergipe";;
			6) estados="Minas Gerais";;
			7) estados="Rio de Janeiro ou Espírito Santo";;
			8) estados="São Paulo";;
			9) estados="Paraná ou Santa Catarina";;
		esac

		echo "$estados"
		return 0
	fi

	# CPF válido formatado
	if test '-f' = "$1"
	then
		# Remove os zeros do início (senão é considerado um octal)
		cpf=$(echo "$cpf" | sed 's/^0*//')

		# Só continua se o CPF for válido
		auxiliar=$(zzcpf $cpf 2>&1)
		if test "$auxiliar" != 'CPF válido'
		then
			zztool erro "$auxiliar"
			return 1
		fi

		# Completa com zeros à esquerda, caso necessário
		cpf=$(printf %011d "$cpf")

		# Formata com um sed esperto
		echo $cpf | sed '
			s/./&-/9
			s/./&./6
			s/./&./3
		'

		# Tudo certo, podemos ir embora
		return 0
	fi

	# CPF válido não formatado
	if test '-F' = "$1"
	then
		# Se o CPF estiver vazio, gera um aleatoriamente sem formatação
		if test "${#cpf}" -eq 0
		then
			zzcpf | tr -d -c '0123456789\n'
			return 0
		fi

		# Remove os zeros do início (senão é considerado um octal)
		cpf=$(echo "$cpf" | sed 's/^0*//')

		# Só continua se o CPF for válido
		auxiliar=$(zzcpf $cpf 2>&1)
		if test "$auxiliar" != 'CPF válido'
		then
			zztool erro "$auxiliar"
			return 1
		fi

		printf "%011d\n" "$cpf"
		return 0
	fi

	# Devo ocultar a saída ou mensagem de erro?
	test '-q' = "$1" && quieto=1

	# Extrai os números da base do CPF:
	# Os 9 primeiros, sem os dois dígitos verificadores.
	# Esses dois dígitos serão calculados adiante.
	if test -n "$cpf"
	then

		# Completa com zeros à esquerda, caso necessário
		cpf=$(printf %011d "$cpf")

		# Faltou ou sobrou algum número...
		if test ${#cpf} -ne 11
		then
			test -n "$quieto" || zztool erro 'CPF inválido (deve ter 11 dígitos)'
			return 1
		fi

		# Apaga os dois últimos dígitos
		base="${cpf%??}"

		#Inicia um laço para comparar a base com todas as possíveis situações:
		#De 000.00..-00 até 999.99..-99
		for ((i=0;i<10;i++))
			do
			#Atribuição de variável auxiliar para comparação de cada situação
				auxiliar=$(echo "$base" | sed "s/$i/X/g")

			#Compara o valor atual da variável auxiliar com a base e, caso seja verdadeiro, retorna o erro
				if test "$auxiliar" = "XXXXXXXXX"
				then
					test -n "$quieto" || zztool erro "CPF inválido (não pode conter os 9 primeiros digitos iguais)"
					return 1
				fi
			done
		#Fim do laço de verificação de digitos repetidos
	else
		# Não foi informado nenhum CPF, vamos gerar um escolhendo
		# nove dígitos aleatoriamente para formar a base
		while test ${#cpf} -lt 9
		do
			cpf="$cpf$(zzaleatorio 8)"
		done
		base="$cpf"
	fi

	# Truque para cada dígito da base ser guardado em $1, $2, $3, ...
	set - $(echo "$base" | sed 's/./& /g')

	# Explicação do algoritmo de geração/validação do CPF:
	#
	# Os primeiros 9 dígitos são livres, você pode digitar quaisquer
	# números, não há seqüência. O que importa é que os dois últimos
	# dígitos, chamados verificadores, estejam corretos.
	#
	# Estes dígitos são calculados em cima dos 9 primeiros, seguindo
	# a seguinte fórmula:
	#
	# 1) Aplica a multiplicação de cada dígito na máscara de números
	#    que é de 10 a 2 para o primeiro dígito e de 11 a 3 para o segundo.
	# 2) Depois tira o módulo de 11 do somatório dos resultados.
	# 3) Diminui isso de 11 e se der 10 ou mais vira zero.
	# 4) Pronto, achou o primeiro dígito verificador.
	#
	# Máscara   : 10    9    8    7    6    5    4    3    2
	# CPF       :  2    2    5    4    3    7    1    0    1
	# Multiplica: 20 + 18 + 40 + 28 + 18 + 35 +  4 +  0 +  2 = Somatória
	#
	# Para o segundo é praticamente igual, porém muda a máscara (11 - 3)
	# e ao somatório é adicionado o dígito 1 multiplicado por 2.

	### Cálculo do dígito verificador 1
	# Passo 1
	somatoria=0
	for i in 10 9 8 7 6 5 4 3 2 # máscara
	do
		# Cada um dos dígitos da base ($n) é multiplicado pelo
		# seu número correspondente da máscara ($i) e adicionado
		# na somatória.
		n="$1"
		somatoria=$((somatoria + (i * n)))
		shift
	done
	# Passo 2
	digito1=$((11 - (somatoria % 11)))
	# Passo 3
	test $digito1 -ge 10 && digito1=0

	### Cálculo do dígito verificador 2
	# Tudo igual ao anterior, primeiro setando $1, $2, $3, etc e
	# depois fazendo os cálculos já explicados.
	#
	set - $(echo "$base" | sed 's/./& /g')
	# Passo 1
	somatoria=0
	for i in 11 10 9 8 7 6 5 4 3
	do
		n="$1"
		somatoria=$((somatoria + (i * n)))
		shift
	done
	# Passo 1 e meio (o dobro do verificador 1 entra na somatória)
	somatoria=$((somatoria + digito1 * 2))
	# Passo 2
	digito2=$((11 - (somatoria % 11)))
	# Passo 3
	test $digito2 -ge 10 && digito2=0

	# Mostra ou valida
	if test ${#cpf} -eq 9
	then
		# Esse CPF foi gerado aleatoriamente pela função.
		# Apenas adiciona os dígitos verificadores e mostra na tela.
		echo "$cpf$digito1$digito2" |
			sed 's/\(...\)\(...\)\(...\)/\1.\2.\3-/' # nnn.nnn.nnn-nn
	else
		# Esse CPF foi informado pelo usuário.
		# Compara os verificadores informados com os calculados.
		if test "${cpf#?????????}" = "$digito1$digito2"
		then
			test -n "$quieto" || echo 'CPF válido'
		else
			# Boa ação do dia: mostrar quais os verificadores corretos
			test -n "$quieto" || zztool erro "CPF inválido (deveria terminar em $digito1$digito2)"
			return 1
		fi
	fi
}
