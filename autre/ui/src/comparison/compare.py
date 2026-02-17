def compare_databases(db1, db2):
    identical = 0
    corrupted = []
    missing = []
    extra = []

    for file, hash1 in db1.items():
        if file in db2:
            if db2[file] == hash1:
                identical += 1
            else:
                corrupted.append(file)
        else:
            missing.append(file)

    for file in db2:
        if file not in db1:
            extra.append(file)

    return {
        "identical": identical,
        "corrupted": corrupted,
        "missing": missing,
        "extra": extra
    }
