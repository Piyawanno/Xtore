from xtore.BaseType cimport i32, f32

cdef class Homomorphic:
    cdef object ccLWE
    cdef object cc
    cdef object keys
    cdef object privateKeyFHEW

    cdef createCKKS(self, i32 multDepth, i32 scaleModSize, i32 firstModSize, i32 ringDim, i32 batchSize)
    cdef createFHEW(self, i32 logQ_ccLWE, i32 slots)
    cdef object encrypt(self, object ptxt)
    cdef object diff(self, object c1, object c2)
    cdef object getSign(self, object cDiff)
    cdef f32 decrypt(self, object ctxt)