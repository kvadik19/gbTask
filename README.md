# gbTask
### `reader.pl` Обработка лог-файла
Используется MySQL. Рабочие таблицы разворачиваются (и, при необходимости модификации в дальнейшем) с помощью скрипта `script/db_update.pl`, которому на вход подается название директории либо sql-файла. Первоначальная конфигурация таблиц описана в `sql/00-init.sql`.

#### Директория `config`
+ `test.conf` содержит логин к MySQL, название файла журнала веб-приложения, количество добавляемых записей в таблицы при импорте лог-файла, и все, что потребуется.
+ `nginx.sample.config` - минимальная конфигурация nginx для веб-приложения.
### <http://gb.onpoz.ru> Веб-приложение для просмотра обработанного лога
`nginx` проксирует запросы на порты, открытые веб-приложением (для http и https используются различные порты). Использована библиотека Mojolicious с бэк-сервером hypnotoad.
#### Директория `htdocs`
Содержит файлы, передаваемые клиенту as-is - javascript, css, изображения, robots.txt 
#### Директория `templates`
Там лежат templates
#### Директория `script`
Содержит скрипты для запуска бэксервера test, на который nginx проксирует запросы к веб-приложению, скрипт для периодической очистки лог-файлов веб-приложения и скрипт для установки бэксервера в автозагрузку ubuntu/debian серверов (для других релизов нужды не было). Запуск и перезапуск бэксервера: `script/testd`. Остановка сервера - `script/testd stop`.
#### Директория `lib` (Mojolicious)
`Test/Response.pm` - модуль, выполняющий обработку всех запросов.

Запросы выборки данных обрабатываются через AJAX на адрес `/quest`. Инициация запроса происходит по событиям **blur** и **paste** поля ввода. Объем получаемых данных регулируется количеством записей, заданным `msg_count` в файле `config/test.conf`. Также предусмотрено использование HTTP-параметра **`q`**. Задаваемое количество записей является количеством полученных сообщений ( с флагом **`<=`**), поскольку к каждой такой записи относится плавающее количество записей с иными флагами. То есть, количество записей - это количество групп связанных сообщений.

Рабочая HTML-страница описана в шаблоне `templates/loader.html.ep`. Javascript, ее обрабатывающий размещен в этом же шаблоне. `htdocs/js/support.js` содержит функции для работы с AJAX. JQuery не применен принципиально.
