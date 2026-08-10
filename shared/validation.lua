STValidation = {}

local RESERVED_PLATE_WORDS = {
    'POLICE',
    'SHERIFF',
    'EMS',
    'FIRE',
    'GOV',
    'GOVERNMENT',
    'STATE',
    'SA',
    'ADMIN'
}

local function normalize(value)
    return tostring(value or ''):upper():gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end

function STValidation.IsStandardPlate(plate)
    plate = normalize(plate)
    return plate:match('^[A-Z][A-Z][A-Z] %d%d%d$') ~= nil
end

function STValidation.IsCustomPlate(plate)
    plate = normalize(plate)

    if plate == '' or #plate > (Config.Plate.CustomMaxLength or 8) then
        return false
    end

    if not plate:match('^[A-Z0-9 ]+$') then
        return false
    end

    if plate:match('%s%s') or plate:match('^%s') or plate:match('%s$') then
        return false
    end

    for _, word in ipairs(RESERVED_PLATE_WORDS) do
        if plate:gsub('%s+', '') == word then
            return false
        end
    end

    return true
end

function STValidation.NormalizePlate(plate)
    return normalize(plate)
end

function STValidation.IsValidPlate(plate, allowCustom)
    if STValidation.IsStandardPlate(plate) then
        return true
    end

    return allowCustom == true and STValidation.IsCustomPlate(plate)
end

function STValidation.IsIdentifier(value)
    return type(value) == 'string' and #value > 0 and #value <= 100
end

function STValidation.IsPositiveNumber(value)
    return type(value) == 'number' and value >= 0
end
