-- Finds another resource's folder for tests that load its files (kora_lib's
-- compat provider, kora_inventory's config). Works for both layouts: resources
-- side by side (a repo checkout) and the server's category folders, where
-- kora_utils is in [kora]/ and kora_lib / kora_inventory are in [pre]/.
-- `root` is kora_utils' own folder, ending in '/'.
return function(root, name)
    local candidates = {
        root .. '../' .. name .. '/',
        root .. '../../[pre]/' .. name .. '/',
        root .. '../../[kora]/' .. name .. '/',
    }
    for _, dir in ipairs(candidates) do
        local file = io.open(dir .. 'fxmanifest.lua', 'r')
        if file then
            file:close()
            return dir
        end
    end
    error(('test could not find resource %q next to kora_utils or in [pre]/'):format(name), 2)
end
