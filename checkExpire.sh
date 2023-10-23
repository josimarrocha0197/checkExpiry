#!/bin/bash

logFile=/var/log/asterisk/expire.log
expireReference=40

#function checkLogSize(){
#	logSize=$(du -hsm ${logFile})
#	if [ ${logSize} -gt 50 ]
#	then
#		echo "" > ${logFile}
#		printf "$(date) - Log resetado por exceder o tamanho maximo (50MB)\n\n" >> ${logFile}
#	fi	
#}

mapfile -t pjsipRegistrations < <(docker exec astproxy asterisk -rx 'pjsip show registrations' | grep exp | grep Registered)

printf "$(date) - Quantidade de extensoes: ${#pjsipRegistrations[@]}\n" >> ${logFile}

if pgrep -x "heplify" > /dev/null
then
	printf "$(date) - Processo heplify esta em execucao\n\n" >> ${logFile}
else
	printf "$(date) - Processo heplify NAO esta em execucao\n" >> ${logFile}
	printf "$(date) - Executando processo...\n\n" >> ${logFile}
	sudo bash /root/scripts/heplify-start.sh
fi

for peer in "${pjsipRegistrations[@]}"
do
	extension=$(echo -e ${peer} | awk '{ print $2 }')
	expireValue=$(echo -e ${peer} | awk '{ print $5 }' | awk -F 's' '{ print $1 }')
	if [[ ${expireValue} -gt ${expireReference} ]]
	then
		printf "$(date) - ATENCAO: A extensao ${extension} esta com valor de expire acima do esperado ${expireReference}\n" >> ${logFile}
		printf "$(date) - Valor: ${expireValue}\n" >> ${logFile}
		printf "$(date) - Executando comando: docker exec -it astproxy asterisk -rx 'pjsip send unregister ${extension}'\n" >> ${logFile}
		docker exec astproxy asterisk -rx "pjsip send unregister ${extension}" > /dev/null
		sleep 2
		printf "$(date) - Executando comando: docker exec -it astproxy asterisk -rx 'pjsip send register ${extension}'\n\n" >> ${logFile}
		docker exec astproxy asterisk -rx "pjsip send register ${extension}" > /dev/null
	else
		printf "$(date) - A extensao ${extension} NAO esta com o valor de expire acima do esperado (40)\n" >> ${logFile}
		printf "$(date) - Valor: ${expireValue}\n\n" >> ${logFile}
	fi
done
