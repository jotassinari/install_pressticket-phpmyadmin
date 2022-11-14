#!/bin/bash
clear
echo "Desenvolvido por Josevã Tassinari - www.netecia.com.br"

echo "RODAR COM O SU DEPLOY - Se NÃO, cancele agora!!"
echo ""

echo "LISTA DE INSTALAÇÕES:"
echo
ls  /home/deploy
echo
pm2 list
echo
#echo "Preencha o nome da instalação que deseja manipular"
#printf "ola enferemeira"
read -p "Informe a instalação a ser manipulada: " inst
echo $inst
echo

x=1
while [ $x -le 1 ]
do
   

   #opcões do menu
   echo "O que deseja fazer?"
   echo "1 - Iniciar o sistema"
   echo "2 - Parar o sistema"
   echo "3 - Rebuild do backend"
   echo "4 - Rebuild do frontend"
   echo "5 - Update do git"
   echo "6 - Trocar a instalação a ser manipulada"
   echo "7 - SAIR"
   
   echo
   read opt
   case $opt  in

     1) echo "iniciando o $inst"
       cd /home/deploy/$inst/backend 
       pm2 start dist/server.js --name $inst-backend
       cd /home/deploy/$inst/frontend
       pm2 start server.js --name $inst-frontend
     ;;
     2) echo "parando o $inst"
       cd /home/deploy/$inst/backend 
       pm2 stop dist/server.js --name $inst-backend
       cd /home/deploy/$inst/frontend
       pm2 stop server.js --name $inst-frontend
     ;;
	   3) echo "Rebuild do $inst-backend"
       cd /home/deploy/$inst/backend
       pm2 stop dist/server.js --name $inst-backend
       rm -rf /home/deploy/$inst/backend/dist
       npm run build
       pm2 start dist/server.js --name $inst-backend
	  ;;
	  4) echo "Rebuild do $int-frontend"
      cd /home/deploy/$inst/frontend
	    pm2 stop server.js --name $inst-frontend
	    npm run build 
	    pm2 start server.js --name $inst-frontend
	  ;;
	  5) /whaticket/install_pressticket-phpmyadmin/./install_instancia
	  ;;
	   
	  6)clear
	   echo "LISTA DE INSTALAÇÕES:"
       echo 
	   ls /home/deploy
	   echo
       pm2 list 
	   read -p "Informe a instalação a ser manipulada: " inst
	  ;;
	  7) x=$(( $x + 1 ));;


   esac

#cho "Welcome $x times"
#  x=$(( $x + 1 ))
done





#operadores aritmeticos

#-eq : (equal), igual.
#-lt : (less than), menor que.
#-gt : (greather than), maior que.
#-le : (less or equal), menor ou igual.
#-ge : (greater or equal), maior ou igual.
#-ne : (not equal) diferente.
