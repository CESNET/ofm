from .transaction import Transaction


class IdleGenerator():
    """
    Idle generator ensures interlacing idle and data transactions in Drivers.

    Idle generators can adopt various behaivour such a "no idles" (full throughput on bus),
    "random idles", "rate limiter", etc.

    This base IdleGenerator generates no idles.

    Driver uses the idle generator by calling pair of .get and .put methods.
    The get method returns a number of idle items, which should be inserted on the bus.
    The put method awaits real number of idle items, which were present on the bus.

    Some idle generators need to know more about the bus parameters and should be parametrized
    with proper configure call.
    """
    def __init__(self):
        # some generators need to be fully configured before the put/get method can be called
        self._cfg_complete = False

    def configure(self, **kwargs):
        pass

    def get(self, transaction: Transaction, *args, **kwargs) -> int:
        """
        return count of items (single IdleTransaction) that should be inserted on bus before next DataTransaction.

        Note that driver doesn't have to follow the returned value.
        Also the handshaked bus can insert dst_rdy=0 states, which doesn't allow to transmit DataTransaction.
        The Generator can handle mismatching items count in put method.

        kwargs can contains optional specifying data:
            'first': int        # first index of item in transaction for partial send
            'last':  int        # last index of item in transaction for partial send
        """
        return 0

    def put(self, transaction: Transaction, *args, **kwargs) -> None:
        """
        Driver calls this function whenever a transaction or its part was sent.

        The IdleGenerator can check for integrity.
        Differences from the planned idles can be logged or an Exception can be raised.

        kwargs can contains optional specifying data:
            'first': int        # first index of item in transaction for partial send
            'last':  int        # last index of item in transaction for partial send
            'items': int        # count of items on bus
            'start': bool       # start of transaction was sent
            'end':   bool       # end of transaction was sent (implies transaction was completly sent)
        """
