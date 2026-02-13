-- scripts/utils/logger.lua

--- @module Logger
-- Простий модуль для форматованого виводу повідомлень у консоль.
-- Допомагає відстежувати етапи генерації та помилки.
local Logger = {}

Logger.enabled = true -- Глобальний вимикач логів

--- Виводить інформаційне повідомлення з міткою часу.
-- @param context (string) Назва модуля або функції, звідки йде виклик (напр. "Gen", "Map").
-- @param message (string) Текст повідомлення.
function Logger.info(context, message)
    if not Logger.enabled then return end
    print(string.format("[INFO] [%s] %s: %s", os.date("%H:%M:%S"), context, message))
end

--- Виводить повідомлення про помилку.
-- @param context (string) Назва модуля.
-- @param message (string) Текст помилки.
function Logger.error(context, message)
    print(string.format("[ERROR] [%s] %s: %s", os.date("%H:%M:%S"), context, message))
end

--- Виводить дані таблиці (для дебагу).
-- @param context (string) Назва модуля.
-- @param tbl (table) Таблиця для виводу.
function Logger.dump(context, tbl)
    if not Logger.enabled then return end
    local importJson = require("json")
    print(string.format("[DUMP] [%s] %s: %s", os.date("%H:%M:%S"), context, importJson.prettify(tbl)))
end

return Logger