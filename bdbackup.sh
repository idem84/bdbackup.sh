#!/bin/bash

echo "Начало резервного копирования базы данных!"
echo " "

#Главный пользователь MYSQL базы данных, по-умолчанию root
DB_USER="root"
#Пароль
DB_PASS="пароль"
#Хост
DB_HOST="localhost"
 
# Полный путь к модулям (программам) на сервере. Измените если скрипту не удаеться определить путь автоматически. Например /usr/bin/mysqldump в CentOS
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
CHOWN="$(which chown)"
CHMOD="$(which chmod)"
GZIP="$(which gzip)"
 
# Путь по которому будет создаваться папка с бэкапами
DEST="/tmp/backups"
 
# Путь к папке в которой будут создаваться файлы с бэкапами
MBD="$DEST/mysql"
 
# Хост
HOST="$(hostname)"
 
# Получаем дату в формате: dd-mm-yyyy_[hours-minutes-seconds]
NOW="$(date +"%d-%m-%Y_%H-%M")"
echo "Дата: $NOW"


FILE=""
DBS=""
#Удалять файлы старше 30 дней
FILES_OLDER_THAN=30
 
# Список баз данных для которых НЕ нужно делать бэкапы
DB_SKIP="information_schema performance_schema mysql phpmyadmin"
 
[ ! -d $MBD ] && mkdir -p $MBD || :
 
 
# Получение полного списка всех доступных баз данных на сервере
DBS="$($MYSQL -u $DB_USER -h $DB_HOST -p$DB_PASS -Bse 'show databases')"
echo " "
echo "Список всех доступных баз данных на сервере:"
echo "$DBS"
echo " "
echo "Список баз данных для которых бэкап не делается:"
echo "$DB_SKIP"
echo " "

for DB in $DBS
do
  skipdb=-1
  if [ "$DB_SKIP" != "" ];
  then
    for i in $DB_SKIP
    do
      [ "$DB" == "$i" ] && skipdb=1 || :
    done
  fi
   
  if [ "$skipdb" == "-1" ]; 
  then
    #Создание своей папки для каждой базы данных
    DB_DIR=$MBD/$DB
    if [ ! -d "$DB_DIR" ]; then
        mkdir -p $DB_DIR
    fi
    FILE=$DB_DIR/mysqldump[$DB]_$NOW.gz

    # Только root пользователь имеет доступ к файлам!
    $CHOWN 0.0 -R $DEST
    $CHMOD 0600 $DEST

    # Начало резервного копирования выбранных баз данных через mysqldump и сжатие файлов.
    # --ignore-table=$DB.huge_table Пропишите ниже, если требуется пропустить определенную таблицу в определенной базе при бэкапе
    $MYSQLDUMP --skip-lock-tables -u $DB_USER -h $DB_HOST -p$DB_PASS  $DB | $GZIP -9 > $FILE
  fi
done

# Удалять файлы старше чем $FILES_OLDER_THAN
find $MBD -type f -mtime +$FILES_OLDER_THAN -exec rm {} \;

echo "Бэкап баз данных завершен!"
echo " "
echo "Синхронизация папок с удаленным"

lftp -e 'mirror --only-newer --reverse --no-empty-dirs --log /var/log/mirror.log --parallel=10 /tmp/backups/mysql /site/mysql; bye;' -u user,password ip address
