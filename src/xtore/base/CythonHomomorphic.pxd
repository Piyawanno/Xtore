from libcpp.vector cimport vector

cdef extern from "xtorecpp/HomomorphicEncryption.hpp" namespace "Xtore":

    cdef cppclass Ciphertext:
        pass
    cdef cppclass Plaintext:
        pass
    cdef cppclass DCRTPoly:
        pass
    cdef cppclass CryptoContext:
        pass
        
    cdef cppclass HomomorphicEncryption:
        HomomorphicEncryption()
        void initializeCKKS(int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize)
        void setupSchemeSwitching(int slots, int logQ_ccLWE)
        Ciphertext encrypt(const vector[double]& plain) except +
        Plaintext decrypt(Ciphertext ciphertext) except +
        vector[double] compare(int slots, Ciphertext cipher1, Ciphertext cipher2) except +
        Ciphertext sumCiphertext(int slots, Ciphertext ciphertext) except +
        Ciphertext maskCiphertext(int slots, Ciphertext ciphertext, Ciphertext mask) except +
        void testFunctionHomomorphic(const vector[double]& plain) except +

cdef class CythonHomomorphic:
    cdef HomomorphicEncryption* homomorphic
    cdef initializeCKKS(self, int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize)
    cdef setupSchemeSwitching(self, int slots, int logQ_ccLWE)
    cdef Ciphertext encrypt(self, vector[double] plaintext)
    cdef Plaintext decrypt(self, Ciphertext ciphertext)
    cdef vector[double] compare(self, int slots, Ciphertext ciphertext1, Ciphertext ciphertext2)
    cdef Ciphertext sumCiphertext(self, int slots, Ciphertext ciphertext)
    cdef Ciphertext maskCiphertext(self, int slots, Ciphertext ciphertext, Ciphertext mask)
    cdef testFunctionHomorphic(self, vector[double] plaintext)