def concat(values):
    ret = 0
    for val, width in reversed(values):
        ret <<= width
        ret |= val & (2**width - 1)
    return ret


class SerializableHeader(object):
    items = []

    def __init__(self):
        for i in self.items:
            setattr(self, i[0], 0)

    def serialize(self):
        names, widths = list(zip(*self.items)) if self.items else ([], [])
        return concat(list(zip([getattr(self, name) for name in names], widths)))

    @classmethod
    def __len__(cls):
        return sum([x[1] for x in cls.items])

    @classmethod
    def deserialize(cls, val: int):
        ret = cls()
        for i in cls.items:
            setattr(ret, i[0], val & 2 ** i[1] - 1)
            val >>= i[1]
        return ret
