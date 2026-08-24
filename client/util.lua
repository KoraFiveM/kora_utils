-- Small shared helpers used by more than one feature module. Kept tiny and
-- deterministic (qblib's convention) -- anything general enough to live in
-- qblib proper (QB.*) should go there instead; this is only for glue specific
-- to this resource.

Small = Small or {}

---Normalise a weapon/model identifier to its integer hash. Accepts a string
---name ("WEAPON_PISTOL", "police") or an already-hashed number and returns the
---joaat hash either way, so config can be written in readable names while hot
---comparisons stay integer-vs-integer.
---@param value string|integer
---@return integer
function Small.hash(value)
    if type(value) == "number" then return value end
    return joaat(value)
end

---Build a hash-keyed lookup set from a config list of names/hashes, for O(1)
---"is this blacklisted?" tests instead of scanning the array every frame. Nil
---or empty input yields an empty set (feature effectively off).
---@param list (string|integer)[]?
---@return table<integer, true> set
function Small.hashSet(list)
    local set = {}
    if not list then return set end
    for i = 1, #list do
        set[Small.hash(list[i])] = true
    end
    return set
end
