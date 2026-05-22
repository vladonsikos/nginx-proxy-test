# Тестовый стенд: nginx proxy chain и X-Forwarded-For

## Что это

Тестовый стенд для проверки корректной обработки заголовка X-Forwarded-For в цепочке из нескольких nginx-прокси.

## Запуск

```bash
docker-compose up -d
```

Проверить статус:
```bash
docker-compose ps
```

## Архитектура

```
Клиент → nginx1 (172.25.0.10) → nginx2 (172.25.0.20) → nginx3 (172.25.0.30) → Приложение
        ↘ nginx1 → nginx3 → Приложение
        ↘ nginx1 → Приложение
```

## Как работает защита от подделки

nginx1 (точка входа) сбрасывает любой X-Forwarded-For от клиента и ставит реальный IP:

```nginx
proxy_set_header X-Forwarded-For "";
proxy_set_header X-Forwarded-For $remote_addr;
```

nginx2 и nginx3 добавляют свой IP к цепочке:
```nginx
proxy_set_header X-Forwarded-For "${http_x_forwarded_for}, $remote_addr";
```

## Протокол тестирования

### 1. Проверка nginx1
```bash
curl http://localhost:8081/health
# Ожидаемый: nginx1 OK
```

### 2. Запрос через один nginx (nginx1 → приложение)
```bash
curl http://localhost:8081/direct/
```
Ожидаемый результат:
```json
{
  "client_ip": "172.25.0.10",
  "x_forwarded_for": "172.25.0.1",
  "x_real_ip": "172.25.0.1"
}
```

### 3. Запрос через цепочку (nginx1 → nginx2 → nginx3 → приложение)
```bash
curl http://localhost:8081/chain/
```
Ожидаемый результат:
```json
{
  "client_ip": "172.25.0.30",
  "x_forwarded_for": "172.25.0.1, 172.25.0.10, 172.25.0.20",
  "x_real_ip": "172.25.0.1"
}
```

### 4. Запрос через короткую цепочку (nginx1 → nginx3 → приложение)
```bash
curl http://localhost:8081/short-chain/
```

### 5. Проверка защиты от подделки
```bash
curl -H "X-Forwarded-For: 1.2.3.4, FAKE_IP" http://localhost:8081/chain/
```
Поддельные IP не должны попасть в ответ.

## Остановка
```bash
docker-compose down
```

## Время выполнения

Около 1.5 часов.

