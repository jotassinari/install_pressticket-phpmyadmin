#!/bin/bash

date
echo "Iniciando o bkp"

diasem=`date +%w`

calc=$(($diasem + 1))

#echo $calc
case $calc  in

1) dia="Dom";;
2) dia="Seg";;
3) dia="Ter";;
4) dia="Qua";;
5) dia="Qui";;
6) dia="Sex";;
7) dia="Sab";;

esac

###############################################################################################
#tratando dos logs. Por padrao, uso o nome do script e altero a extensao p log
EMPRESA="whaticket-vps1" #ESTE NOME PRECISA SER COLOCADO NO CRONTAB Ex: /scripts/bkp.gilles2.log <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
LOG="/whaticket/backup/bkp.$EMPRESA.log" #caminho do log deste arquivo

cat $LOG >> $LOG.full #envia tudo que exite no arquivo de log, para o arquilo log.full
date > $LOG #limpa do arquivo de log e coloca a data no topo

#esta variavel serve para definir se o sistema enviara, ou nao, os LOGs por email.
#caso algum comando seja executado com erro, ela recebera algo diferente de "0" e o email será enviado
#a cada comando dado (que deva ser validado) deve-se repetir esta linha -- $ENVIODELOG=$(($ENVIODELOG+$?))
#export foi usado, para que esta varialvel se torne global. Assim, caso este script chame outro script, o outro
#também podera gravar nesta variavel e enviar o log.
#caso queira receber logs diarios, com ou sem erros. E so fazer a variavel $ENVIODELOG=1
ENVIODELOG=0
CONTROLE=0 #variavel servira somente para avaliar se o ultimo comando, foi executado com exito.
#função que avalia se o comando teve erro e informa no log. Caso errado, dispara o e-mail.
#Não será usada, no caso de tomada de ação, se verdado ou se falso.
ASSUNTO2="LOG SEMANAL"

function tem_erro(){
    CONTROLE=$?
    if [ $CONTROLE -eq 0 ]; then
        echo "OK"
    else
        echo "ERRO"
        ENVIODELOG=$(($ENVIODELOG+$CONTROLE))
        ASSUNTO2="ERRO DE BACKUP"
    fi
}

echo "backup da empresa: $EMPRESA"
echo
echo "Este log é um: $ASSUNTO2"
echo
#///////////////////////////////////////////////////////////////////////////////////////////////

#////////////// Bloco de backup do banco de dados//////////

function bkp_wt(){
    instalacao=$1 #variavel implicita como parametro em funções no shellscript > exemplo de instalação milblocos-3002
    senhaBanco=$2

    #docker exec [mysql_container_name] /usr/bin/mysqldump -u [mysql_username] --password=[mysql_password] [database_name] > [destination_path]
    /bin/docker exec mysql-$instalacao /usr/bin/mysqldump -u root --password=$senhaBanco $instalacao | /bin/gzip > /whaticket/backup/arquivos/$dia.$instalacao.sql.gz
    tem_erro
    
    #bkp dos arquivos de midia (anexos)
    #backup direfencial -  - mantendo 2 copias do full por tempo de vida, exclusões, tempo de vida e com 1 copia FULL anual
    DIAANOBKP=400 #como não existe dia 400, ele ira ignorar o backup anual
    TEMPOBKP=180 #fazer bacakup de arquivos com no maximo quantos dias de modificados
    DIABKPFULL=7 #sendo 1 igual a domingo - dia da semana para a copia full
    ORIGEM=/home/deploy/$1/backend/public
    DESTINO=/whaticket/backup/arquivos
    NOMEARQUIVO="$1.arquivos"
    EXCLUSAO="/whaticket/excluir.txt" #criar este arquivo com as exceções, mesmo que o arquivo esteja vazio
    #NÃO alterar daqui p baixo

    DATA=`date +%d%m%y` #recebe a data no formato ddmmaa
    #primeiro if verifica se hoje é o dia no bkp anual full   
    DIAANOHJ=`date +%j` #recebe que dia do ano é hoje
    if [ $DIAANOHJ == $DIAANOBKP ]; then
        echo "backup full anual"
        date
    /bin/tar -P -czf $DESTINO/bkp_anual.$DATA.$NOMEARQUIVO.full.tar.gz $ORIGEM --exclude-from $EXCLUSAO
    #daqui p baixo, so roda se não for o backup anual.
    else
        VERSAO=1
        DIAMES=`date +%d`
        DIAMES=${DIAMES#0} #removendo o zero a esquerda de DIAMES
        DIV=$((DIAMES%2))
        echo "Fazendo o backup de $NOMEARQUIVO"
        if [ $DIV -eq 0 ]; then #isso aqui garante duas versoes. 1 para dias par e uma p dias impar
        VERSAO=2
        fi
        if [ $calc -eq $DIABKPFULL ]; then
        echo "bkp full - Fazendo backup dos arquivos alterados a $TEMPOBKP dias"
        #  /bin/tar -P -czf $DESTINO/$VERSAO.$dia.$NOMEARQUIVO.full.tar.gz $ORIGEM --exclude-from $EXCLUSAO
        find $ORIGEM -mtime -$TEMPOBKP -type f -print | /bin/tar -zcf $DESTINO/$VERSAO.$dia.$NOMEARQUIVO.full.tar.gz --exclude-from $EXCLUSAO -T -
        else
        echo "bkp diferencial"
        MTIME=$(($calc - $DIABKPFULL))
        if [ 0 -gt $MTIME ]; then
            Y=$(($MTIME + 7)) #era p MTIME receber ele mesmo, mas deu erro e usei o Y como recurso.
            MTIME=$Y
        fi
        echo "Fazendo backup dos arquivos alterados a $MTIME dias"
        find $ORIGEM -mtime -$MTIME -type f -print | /bin/tar -zcf $DESTINO/$dia.$NOMEARQUIVO.dif.tar.gz --exclude-from $EXCLUSAO -T -	
        fi
    fi
    echo "fim do backup $NOMEARQUIVO"
    date
    echo
}
#///////////////////////////////////////////////////////////////////////////////////////////////////////

################################################################################
#Chamando a função para fazer backup de cada cliente
bkp_wt "netecia-3000" "65067753@Jg"
#bkp_wt "abs-3001" "65067753@Jg"

################################################
echo "listando os arquivos de backup"
cd /whaticket/backup/arquivos
ls -lhFta
echo "listando o espaço dos discos"
df -h
echo 
#///////////////////////////////////////////////



####################################  Envio para a netecia via ssh ############################### >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#via rsync com ssh - somente arquivos novos e com numero de tentativas de envio 
#diretorio a ser backpeado
DIRBKP=/whaticket/backup/arquivos
#usuario do cliente no servidor de backup
USUARIO=whaticketvps1
#endereço do servidor de backup (caminho pleno) - 
#OBS.: não posso gravar na raiz do dataset do cliente no freenas - isso gera erro de setdate
ENDERECO=suporte.netecia.com.br:/mnt/pool_bkp_11Tb/netecia/whaticket-clientes
#tempo de vida (em dias) dos arquivos a serem copiados
VIDA=1
#porta do servidor ssh - Para porta padrao 22, apagar "-e 'ssh -p 27'" na linha sshpass ou alterar o 27 p qualquer porta
#numero de tentativas de envio
TENT=3
#intervalo entre tentativas - em segundos - 3600 = 1 hora
INTERVALO=3600
#daqui p baixo, não alterar nada>>>>>>>>>>>>>>>>
date
echo "subindo os arquivos para o FREENAS NET E CIA"
#o nome que der para o diretorio tmp EX.: bkptmp, será criado na raiz de backup do cliente
DIRTMP=$DIRBKP/bkptmp/
#entra no diretorio a ser copiado
cd $DIRBKP
#cria nele uma subpasta bkptmp
mkdir bkptmp
#pesquisa arquivos com menos de 1 dia de vida e move p o sub-diretorio bkptmp
find $DIRBKP -mtime -$VIDA -exec mv {} $DIRTMP \;
echo "sobe via ssh os arquivos de bkptmp"

for ((i=1; i<=$TENT; i++)); do
    sshpass -p '159951@Jg' /bin/rsync -Cavzp -e 'ssh -p 27' $DIRTMP $USUARIO@$ENDERECO
    CONT=$?
    if [ $CONT -eq 0 ]; then
        echo "OK"
        i=4
    else
        echo "ERRO ao enviar arquivos - $i tentativa"
        date
        if [ $i -eq $TENT ]; then
            echo "ERRO de envio - Depois de $TENT tentativas, ainda não foi possivel o envio. Despachando o LOG p email"
            ENVIODELOG=$(($ENVIODELOG+$CONT))
            ASSUNTO2="ERRO DE BACKUP"
        else
            sleep $INTERVALO  	
        fi
    fi  
done
#move os arquivos de volta para a pasta original
mv $DIRTMP* $DIRBKP
date
echo "backup dos arquivos p o freenas Net e Cia, concluido."
#//////////////////////////////////////////////////////////////////////////////////////////////////////////

#enviando o Log semanal na segunda
if [ "$dia" == "Ter" ]; then
    echo "forcando um erro, somente para receber o log uma vez por semana"
    ENVIODELOG=$(($ENVIODELOG+1))
    ASSUNTO2="LOG SEMANAL"   
fi

############################################################################################
#enviando o log por email
echo "//////////////////////////////////////////////////////////////////////////////////////////"
EMAIL_FROM="bkp_erro_servidor@netecia.com.br"  # usuario de email que se autentica no servidor SMTP
EMAIL_TO="suporte@netecia.com.br" # usuario que receberá os emails
#desabilitei a linha abaixo, para coloca-la no inicio deste scritp
#LOG="/netecia/allapel.vm.log" #arquivo de log que quero que envie como anexo

#Servidor SMTP e porta utilizada
SERVIDOR_SMTP="mail.suporte1.net.br:26" #endereço no servidor SMTP, observar no exemplo o yahoo utiliza a porta 587
SENHA=cKAgW9@yHyFe    #informe aqui a senha de autenticação no servidor SMTP

ASSUNTO="Whaticket - $EMPRESA - "
#verificando se houveram erros e se será preciso enviao o arquivo de log p o email
if [ $ENVIODELOG -eq 0 ]; then
    echo 'O arquivo não possui erro e não será despachado o arquivo de LOG por e-mail'
	echo
	echo
else
    echo 'O arquivo possui erro e será despachado o arquivo de LOG por e-mail'
	echo
	echo
	echo
    /usr/bin/sendEmail -f $EMAIL_FROM -t $EMAIL_TO -u "$ASSUNTO $ASSUNTO2" -m "Segue anexo o log do bkp, contendo erros!!" -a $LOG -s $SERVIDOR_SMTP -xu $EMAIL_FROM -xp $SENHA
fi
#////////////////////////////////////////////////////////////////////////////////////////////#
