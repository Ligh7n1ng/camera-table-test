#!/bin/bash

IPList="$1"
#LOffice="libreoffice --calc"
LOffice="libreoffice7.1 --calc"
ReportMail="$2"

CloudPath="gdrive:Камеры"

rclone copy "$CloudPath/$IPList.xlsx" "." -P

$LOffice --infilter="xlsx:Calc MS Excel 2007 XML"  --convert-to "csv:Text - txt - csv (StarCalc):44,34,UTF8" "./$IPList.xlsx"

CurDate=$(date +%F)
CurTime=$(date +%H-%M-%S)

#Забираем число не пустых строк в файле
NumOfRec=$(grep "\S" "./$IPList.csv" | wc -l)

# Проверяем есть ли записи
if [ $NumOfRec -gt 0 ]
then
    # Узнаем количество строк с устройсваим
    NumOfRec=$(grep -vE '#ignore|^,' "./$IPList.csv" | sed 1d | wc -l)
    
    # Сохраняем времееный файл, из которого будем брать адреса для тестирования
    grep -vE '#ignore|^,' "./$IPList.csv" | sed 1d  > "./.processing.tmp"
    
    # Для каждой строки файла выполняем следующие действия
    for (( i=1; i <= $NumOfRec; i++ ))
    do
        # Забираем IP из списка
        ProcIP=$(cat "./.processing.tmp" | head -n $i | tail -n 1 | tr ',' '\n' | head -n 1)
        
        # Выводим прогресс обработки
        echo -e "Проверка доступности IP-адреса $ProcIP... ($i/$NumOfRec)"
        
        # Проверяем, пингуется ли IP
        TestIP=$(ping -c 5 -W 5 $ProcIP | grep 'received' | sed 's/, /\n/g' | grep 'received' | sed 's/ received//g')
        
        # Если да, то
        if [ $TestIP -gt 0 ]
        then
            # Вписываем адрес как рабочий
            IPCurState=$(grep $ProcIP "./.processing.tmp" | head -n 1 | awk 'BEGIN{FS=","} {print $8}')
            if [ "$IPCurState" != "Работает" ]
            then
                mkdir -p "./$CurDate"
                CurGate=$(grep $ProcIP "./.processing.tmp" | head -n 1 | awk 'BEGIN{FS=","; OFS=","} {print $2}')
                CurLoc=$(grep "#address" "./.processing.tmp" | grep "$CurGate" | head -n 1 | awk 'BEGIN{FS=","} {print $6}')
                grep $ProcIP "./.processing.tmp" | head -n 1 | awk -v loc="$CurLoc" 'BEGIN{FS=","; OFS=","} {$4=loc; $5="Работает"; print $1,$4,$7,$3,$5}' >> "./$CurDate/$CurDate-$CurTime-заработали.csv"
            fi
            NumOfStr=$(grep -n "$ProcIP" "./$IPList.csv" | tr ':' '\n' | head -n 1)
            echo "sed -i '"$NumOfStr"s/Не проверен/Работает/' ./$IPList.csv" | bash
            echo "sed -i '"$NumOfStr"s/Не работает/Работает/' ./$IPList.csv" | bash
        
        # Если нет, то
        else
            # Вписываем адрес как нерабочий
            IPCurState=$(grep $ProcIP "./.processing.tmp" | head -n 1 | awk 'BEGIN{FS=","} {print $8}')
            if [ "$IPCurState" != "Не работает" ]
            then
                mkdir -p "./$CurDate"
                CurGate=$(grep $ProcIP "./.processing.tmp" | head -n 1 | awk 'BEGIN{FS=","; OFS=","} {print $2}')
                CurLoc=$(grep "#address" "./.processing.tmp" | grep "$CurGate" | head -n 1 | awk 'BEGIN{FS=","} {print $6}')
                grep $ProcIP "./.processing.tmp" | head -n 1 | awk -v loc="$CurLoc" 'BEGIN{FS=","; OFS=","} {$4=loc; $5="Не работает"; print $1,$4,$7,$3,$5}' >> "./$CurDate/$CurDate-$CurTime-перестали-работать.csv"
            fi
            NumOfStr=$(grep -n $ProcIP "./$IPList.csv" | tr ':' '\n' | head -n 1)
            echo "sed -i '"$NumOfStr"s/Не проверен/Не работает/' ./$IPList.csv" | bash
            echo "sed -i '"$NumOfStr"s/Работает/Не работает/' ./$IPList.csv" | bash
        fi
    done
    # Удаляем старый список IP
    rm "./.processing.tmp"
    
    # Шлем почту
    NumOfCam=$(grep 'Камера' "./$CurDate/$CurDate-$CurTime-заработали.csv" | wc -l)

    if [ $NumOfRec -gt 0 ]
    then
	grep 'Камера' "./$CurDate/$CurDate-$CurTime-заработали.csv" > "./$CurDate/$CurDate-$CurTime-cameras.csv"
        $LOffice --infilter="Text CSV:44,34,UTF8"  --convert-to "xlsx:Calc MS Excel 2007 XML:UTF8" --outdir ./$CurDate ./$CurDate/$CurDate-$CurTime-cameras.csv
        rm ./$CurDate/$CurDate-$CurTime-cameras.csv
        echo -e "В прикрепленном файле список камер, заработавших с момента последней проверки.\n\n=========================================\nЭто письмо было отправлено автоматически.\nНе отвечайте на него, пожалуйста :)\n=========================================" | mutt -s "Список заработавших камер" $ReportMail -a "./$CurDate/$CurDate-$CurTime-cameras.xlsx"
    fi
       
    CSVList=$(ls ./$CurDate/ | grep .csv)

    for CSVFile in $CSVList
    do
        $LOffice --infilter="Text CSV:44,34,UTF8"  --convert-to "xlsx:Calc MS Excel 2007 XML:UTF8" --outdir ./$CurDate ./$CurDate/$CSVFile
    done
    
    rm ./"$CurDate"/*.csv
    
    $LOffice --infilter="Text CSV:44,34,UTF8"  --convert-to "xlsx:Calc MS Excel 2007 XML:UTF8" --outdir ./ ./$IPList.csv
    
    rm "./$IPList.csv"
    
    rclone copy "./$IPList.xlsx" ""$CloudPath"/" -P
    rclone mkdir "$CloudPath/$CurDate" -P
    rclone copy "./$CurDate" "$CloudPath/$CurDate/" -P
    rm -r "./$CurDate"
    rm "./$IPList.xlsx"
    echo "Все готово!"
else
    echo "File is empty. Nothing to do."
fi

exit
