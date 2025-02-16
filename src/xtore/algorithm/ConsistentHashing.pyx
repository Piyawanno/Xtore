from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from hashlib import md5

cdef class Node:
    cdef public str name
    cdef public int hash_value

    def __init__(self, str name):
        self.name = name
        self.hash_value = self._hash(name)

    cdef int _hash(self, str key):
        return int(md5(key.encode('utf-8')).hexdigest(), 16) % (2**32)

cdef class ConsistentHashing:
    cdef public int num_replicas
    cdef public dict ring
    cdef public list sorted_keys

    def __init__(self, int num_replicas):
        self.num_replicas = num_replicas
        self.ring = {}
        self.sorted_keys = []

    def add_node(self, Node node):
        for i in range(self.num_replicas):
            replica_key = f"{node.name}:{i}"
            hash_value = node._hash(replica_key)
            self.ring[hash_value] = node
            self.sorted_keys.append(hash_value)
        self.sorted_keys.sort()

    def remove_node(self, Node node):
        for i in range(self.num_replicas):
            replica_key = f"{node.name}:{i}"
            hash_value = node._hash(replica_key)
            del self.ring[hash_value]
            self.sorted_keys.remove(hash_value)

    def get_node(self, str key):
        if not self.ring:
            return None
        hash_value = Node._hash(Node, key)
        idx = self._find_index(hash_value)
        return self.ring[self.sorted_keys[idx]]

    cdef int _find_index(self, int hash_value):
        low, high = 0, len(self.sorted_keys) - 1
        while low <= high:
            mid = (low + high) // 2
            if self.sorted_keys[mid] < hash_value:
                low = mid + 1
            else:
                high = mid - 1
        return low % len(self.sorted_keys)