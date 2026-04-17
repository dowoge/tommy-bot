local Format = {}

function Format.Pad(String, Padding)
    Padding = Padding or 20
    String = tostring(String)
    return String .. string.rep(" ", math.max(0, Padding - #String))
end

return Format
