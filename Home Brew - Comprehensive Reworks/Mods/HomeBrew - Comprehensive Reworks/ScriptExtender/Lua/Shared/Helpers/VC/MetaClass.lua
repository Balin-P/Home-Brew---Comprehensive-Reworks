---@class MetaClass
---@field private _ClassName string
_MetaClass = {
    _ClassName = "VolitionCabinetMetaClass",
}

---@private
_MetaClass.__index = _MetaClass

---@generic T
---@param class T
---@param object table|nil
---@return T
function _MetaClass.New(class, object)
    object = object or {}
    setmetatable(object, class)
    class.__index = class

    if class.Init then
        object:Init()
    end

    return object
end

function _MetaClass:Init()
end

---@class _Class
---@field Classes table<string, table>
_Class = {
    Classes = {},
}

---@param object string|table
---@return table|nil
function _Class:GetClass(object)
    local className
    if type(object) == "table" then
        className = object._ClassName
    elseif type(object) == "string" then
        className = object
    end

    return self.Classes[className]
end

---@param object table
---@return string|nil
function _Class:GetClassName(object)
    return object._ClassName
end

---@generic T
---@param class `T`
---@param parentClass? string|table
---@param initial? table
---@return T
function _Class:Create(class, parentClass, initial)
    local newClass = _Class.Classes[class]
    if newClass == nil then
        newClass = initial or {}
        newClass._ClassName = class
        local metaclass = parentClass ~= nil and self:GetClass(parentClass) or _MetaClass
        setmetatable(newClass, metaclass)
        newClass.__index = newClass
        _Class.Classes[class] = newClass
    end

    return newClass
end
