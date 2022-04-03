s=string.sub;t=tonumber
return function(n)
    local o, d = {"st", "nd", "rd"}, s(n, -1)
    if t(d) > 0 and t(d) <= 3 and s(n,-2) ~= 11 and s(n,-2) ~= 12 and s(n,-2) ~= 13 then
        return n .. o[t(d)]
    else
        return n .. "th"
    end
end