function remove_annotations(tag, timestamp, record)
    if record["outer"] == nil then
        return 0, 0, 0
    end
    if record["outer"]["nested1"] == nil then
        return 0, 0, 0
    end
    record["outer"]["nested1"] = nil
    return 1, timestamp, record
end
