# ----------------------------------------------------------------------------
# Mostra a programação da TV, diária ou semanal, com escolha de emissora.
#
# Opções:
#  canais - lista os canais com seus códigos para consulta.
#
#  <código canal> - Programação do canal escolhido.
#  Obs.: Seguido de "semana" ou "s": toda programação das próximas semanas.
#        Se for seguido de uma data, mostra a programação da data informada.
#
#  cod <número> - mostra um resumo do programa.
#   Obs: número obtido pelas listagens da programação do canal consultado.
#
# Programação corrente:
#  doc ou documentario, esportes ou futebol, filmes, infantil, variedades
#  series ou seriados, aberta, todos ou agora (padrão).
#
# Uso: zztv [<código canal> [s | <DATA>]]  ou  zztv [cod <número> | canais]
# Ex.: zztv CUL          # Programação da TV Cultura
#      zztv fox 31/5     # Programação da Fox na data, se disponível
#      zztv cod 3235238  # Detalhes do programa identificado pelo código
#
# Autor: Aurelio Marinho Jargas, www.aurelio.net
# Desde: 2002-02-19
# Versão: 13
# Licença: GPL
# Requisitos: zzcolunar zzdatafmt zzjuntalinhas zzsqueeze zztrim zzunescape zzxml
# Tags: internet, consulta
# ----------------------------------------------------------------------------
zztv ()
{
	zzzz -h tv "$1" && return

	local DATA=$(date +%d\\/%m)
	local URL="http://meuguia.tv"
	local cache=$(zztool cache tv)
	local codigo desc linhas

	# 0 = lista canal especifico
	# 1 = lista programas de vários canais no horário
	# 2 = Detalhes do programa através do código
	local flag=0

	if ! test -s "$cache" || head -n 1 "$cache" | grep -q -v 'programacao'
	then
		# Links das categorias
		zztool source "$URL" |
		sed -n '/categoria/{s/" .*//;s/.*"//;p;}' > "$cache"

		# Lista de canais
		fgrep '/programacao/' "$cache" |
		while read linhas
		do
			zztool source "${URL}${linhas}"
		done |
		sed -n '
			/<a title="/{s/.*href="//;s/".*//;s|.*/||;p;}
			/<h2>/{s/^[^>]*>//;s/<.*//;s/\(TCM - \| \(EP\)\?TV\| Channel\)//;s/Esporte Interativo /EI /;p;}
		' |
		awk '{printf $0 " "; getline; print}' |
		sort |
		zzunescape --html >> "$cache"
	fi

	if test -n "$2"
	then
		DATA=$(zzdatafmt -f 'DD\/MM' "$2" 2>/dev/null || echo "$DATA")
	fi

	if test -n "$1" && grep -i "^$1" $cache >/dev/null 2>/dev/null
	then
		codigo=$(grep -i "^$1" $cache | sed "s/ .*//")
		desc=$(grep -i "^$1" $cache | sed "s/^[A-Z0-9]\{3\} *//")

		zztool eco $desc
		zztool source "${URL}/programacao/canal/$codigo" |
		zztrim |
		sed -n '
			s/> *$/&|/
			/subheader/{/<!--/d;s/<.\?li[^>]*>|\?//g;p;}
			/<a title=/{s|.*/||;s/-.*/|/;p}
			/lileft/p
			/<h2>/p
		' |
		zzxml --untag |
		if test 'semana' != "$2" -a 's' != "$2"
		then
			sed -n "/, ${DATA}$/,/[^|]$/p"
		else
			cat -
		fi |
		awk '
			/[0-9]$/{print "";print}
			/\|/{ printf $0;for (i=1;i<3;i++){getline; printf $0};print "" }' |
		sed '${/[^|]$/d}' |
		zztrim |
		zzunescape --html |
		awk -F '|' 'NF<=1;NF>1{printf "%-5s %-50s cod: %s\n", $2, $3,$1}'

		return
	fi

	case "$1" in
	canais) fgrep -v '/programacao/' "$cache" | zzcolunar 4;;
	aberta)                        URL="${URL}/programacao/categoria/Aberta"; flag=1; desc="Aberta";;
	doc | documentario)            URL="${URL}/programacao/categoria/Documentarios"; flag=1; desc="Documentários";;
	esporte | esportes | futebol)  URL="${URL}/programacao/categoria/Esportes"; flag=1; desc="Esportes";;
	filmes)                        URL="${URL}/programacao/categoria/Filmes"; flag=1; desc="Filmes";;
	infantil)                      URL="${URL}/programacao/categoria/Infantil"; flag=1; desc="Infantil";;
	noticias)                      URL="${URL}/programacao/categoria/Noticias"; flag=1; desc="Notícias";;
	series | seriados)             URL="${URL}/programacao/categoria/Series"; flag=1; desc="Séries";;
	variedades)                    URL="${URL}/programacao/categoria/Variedades"; flag=1; desc="Variedades";;
	cod)                           URL="${URL}/programacao/programa/$2"; flag=2;;
	todos | agora | *)             flag=1; desc="Agora";;
	esac

	if test $flag -eq 1
	then
		zztool eco $desc
		if test "$desc" = "Agora"
		then
			fgrep '/programacao/' "$cache" |
			while read linhas
			do
				zztool source "${URL}${linhas}"
			done
		else
			zztool source "$URL"
		fi |
		sed -n '
			/<a title="/{s/.*title="//;s|".*/|\t|;s/".*//;p;}
			/<h2>/{s/^[^>]*>//;s/<.*//;s/\(TCM - \| \(EP\)\?TV\| Channel\)//;s/Esporte Interativo /EI /;p;}
			/progressbar/{s/.*\([0-2][0-9]:[0-5][0-9]\).*/\1/p}
		' |
		awk -F '[\t]' '{printf "%s|%s|", $1, $2;getline;printf $0 "|";getline; print}' |
		zzunescape --html |
		awk -F '|' '{printf "%5s %-45s %s - %s\n",$4,$1, $2, $3}' |
		sort -n
	elif test 'cod' = "$1"
	then
		zztool eco "Código: $2"
		zztool source "$URL" |
		sed -n '/<h1 class/p;/body2/,/div>/p;/var str/p' |
		zzjuntalinhas -i '<p' -f 'p>' -d ' ' |
		zzjuntalinhas -i '<script' -f 'script>' -d ' ' |
		sed '
			/var str/{s/.*="//;s/".*//;}
			/<!--/d
			s_</a>_ | _g
			s/<br *\/>/\
/' |
		zzxml --untag |
		sed 's/ | $//' |
		zztrim |
		zzsqueeze |
		zzunescape --html
	fi
}
